import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { internalMutation, internalQuery, query } from "./_generated/server";

/**
 * Get all collections filtered by sale completion status
 */
export const getMintingCollections = query({
	args: {
		saleCompleted: v.optional(v.boolean()),
		requireMintEnabled: v.optional(v.boolean()),
	},
	handler: async (ctx, args) => {
		const saleCompleted = args.saleCompleted ?? false; // Default to false (active sales)
		const requireMintEnabled = args.requireMintEnabled ?? true; // Default to true (only mint-enabled)

		let collections: Doc<"collections">[];

		if (requireMintEnabled) {
			collections = await ctx.db
				.query("collections")
				.withIndex("by_state", (q) => q.eq("saleCompleted", saleCompleted).eq("mintEnabled", true))
				.collect();
		} else {
			collections = await ctx.db
				.query("collections")
				.filter((q) => q.eq(q.field("saleCompleted"), saleCompleted))
				.collect();
		}

		// Sort by createdAt descending (newest first)
		collections.sort((a, b) => b.createdAt - a.createdAt);

		// Transform to match the expected format from the old GraphQL query
		return collections.map(({ collectionId, collectionName, currentSupply, maxSupply, uri, description }) => ({
			collection_id: collectionId,
			collection_name: collectionName,
			current_supply: currentSupply,
			max_supply: maxSupply,
			uri: uri || "",
			description: description || "",
		}));
	},
});

/**
 * Get a single collection by ID with full details
 */
export const getCollection = query({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		const collection = await ctx.db
			.query("collections")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionId))
			.first();

		if (!collection) {
			return null;
		}

		// Fetch mint stages from separate table
		const mintStages = await ctx.db
			.query("mintStages")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionId))
			.collect();

		// Transform mint stages to match the expected format
		const stages = mintStages.map((stage) => ({
			name: stage.name,
			mint_fee: stage.mintFee.toString(),
			mint_fee_with_reduction: stage.mintFee.toString(), // Will be calculated with reduction NFTs on client
			start_time: stage.startTime.toString(),
			end_time: stage.endTime.toString(),
			stage_type: stage.stageType,
		}));

		// Transform to match the expected format from useCollectionData
		return {
			creator_address: collection.creatorAddress,
			collection_id: collection.collectionId,
			collection_name: collection.collectionName,
			current_supply: collection.currentSupply,
			max_supply: collection.maxSupply,
			total_funds_collected: collection.totalFundsCollected,
			sale_completed: collection.saleCompleted,
			sale_deadline: collection.saleDeadline,
			mint_enabled: collection.mintEnabled,
			fa_symbol: collection.faSymbol,
			fa_name: collection.faName,
			fa_icon_uri: collection.faIconUri,
			fa_project_uri: collection.faProjectUri,
			fa_total_minted: collection.faTotalMinted,
			fa_lp_amount: collection.faLpAmount,
			fa_vesting_amount: collection.faVestingAmount,
			fa_dev_wallet_amount: collection.faDevWalletAmount,
			fa_creator_vesting_amount: collection.faCreatorVestingAmount,
			vesting_cliff: collection.vestingCliff,
			vesting_duration: collection.vestingDuration,
			creator_vesting_wallet_address: collection.creatorVestingWalletAddress,
			creator_vesting_cliff: collection.creatorVestingCliff,
			creator_vesting_duration: collection.creatorVestingDuration,
			uri: collection.uri || collection.placeholderUri || "",
			description: collection.description || "",
			ownerCount: collection.ownerCount ?? 0,
			stages,
		};
	},
});

/**
 * Internal query to get all collections that need syncing
 */
export const getCollectionsToSync = internalQuery({
	args: {},
	handler: async (ctx) => {
		return await ctx.db.query("collections").collect();
	},
});

/**
 * Internal mutation to update collection data from blockchain (infrequent updates)
 * Supply data (currentSupply, ownerCount, saleCompleted) is handled by updateCollectionSupply
 */
export const updateCollectionFromBlockchain = internalMutation({
	args: {
		collectionId: v.id("collections"),
		updates: v.object({
			totalFundsCollected: v.optional(v.number()),
			saleDeadline: v.number(),
			mintEnabled: v.optional(v.boolean()),
			updatedAt: v.number(),
		}),
	},
	handler: async (ctx, args) => {
		const existing = await ctx.db.get("collections", args.collectionId);
		if (!existing) {
			console.error(`Collection ${args.collectionId} not found in database`);
			return;
		}

		await ctx.db.patch("collections", args.collectionId, args.updates);
	},
});

/**
 * Internal mutation to update supply and sale status (frequent updates)
 * Only updates if data has actually changed to avoid unnecessary writes
 */
export const updateCollectionSupply = internalMutation({
	args: {
		collectionId: v.id("collections"),
		currentSupply: v.number(),
		ownerCount: v.number(),
		saleCompleted: v.boolean(),
	},
	handler: async (ctx, args) => {
		const existing = await ctx.db.get("collections", args.collectionId);
		if (!existing) {
			console.error(`Collection ${args.collectionId} not found in database`);
			return { updated: false };
		}

		// Check if any data has changed
		const hasChanged =
			existing.currentSupply !== args.currentSupply ||
			existing.ownerCount !== args.ownerCount ||
			existing.saleCompleted !== args.saleCompleted;

		if (!hasChanged) {
			return { updated: false };
		}

		await ctx.db.patch("collections", args.collectionId, {
			currentSupply: args.currentSupply,
			ownerCount: args.ownerCount,
			saleCompleted: args.saleCompleted,
		});

		return { updated: true };
	},
});

/**
 * Upsert mint stages for a collection
 * This replaces all existing stages for the collection
 */
export const upsertMintStages = internalMutation({
	args: {
		collectionId: v.string(),
		stages: v.array(
			v.object({
				name: v.string(),
				mintFee: v.number(),
				startTime: v.number(),
				endTime: v.number(),
				stageType: v.number(),
			}),
		),
	},
	handler: async (ctx, args) => {
		// Get existing stages for this collection
		const existingStages = await ctx.db
			.query("mintStages")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionId))
			.collect();

		// Delete existing stages
		for (const stage of existingStages) {
			await ctx.db.delete("mintStages", stage._id);
		}

		// Insert new stages
		const now = Date.now();
		for (const stage of args.stages) {
			await ctx.db.insert("mintStages", {
				collectionId: args.collectionId,
				name: stage.name,
				mintFee: stage.mintFee,
				startTime: stage.startTime,
				endTime: stage.endTime,
				stageType: stage.stageType,
				updatedAt: now,
			});
		}

		console.log(`Upserted ${args.stages.length} mint stages for collection ${args.collectionId}`);
	},
});
