import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { internalMutation, internalQuery, query } from "./_generated/server";

/**
 * Get all collections filtered by sale completion status
 */
export const getMintingCollections = query({
	args: {
		saleCompleted: v.optional(v.boolean()),
	},
	handler: async (ctx, args) => {
		const saleCompleted = args.saleCompleted ?? false; // Default to false (active sales)

		const collections = await ctx.db
			.query("collections")
			.withIndex("by_state", (q) => q.eq("saleCompleted", saleCompleted).eq("mintEnabled", true))
			.collect();

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
 * Get all collections grouped by status (ongoing, successful, failed)
 */
export const getCollectionsGrouped = query({
	args: {},
	handler: async (ctx) => {
		const allCollections = await ctx.db
			.query("collections")
			.withIndex("by_mint_enabled", (q) => q.eq("mintEnabled", true))
			.collect();
		const now = Math.floor(Date.now() / 1000);

		const ongoing: Doc<"collections">[] = [];
		const successful: Doc<"collections">[] = [];
		const failed: Doc<"collections">[] = [];

		for (const collection of allCollections) {
			if (collection.saleCompleted) {
				// Sale completed = successful (max supply reached)
				successful.push(collection);
			} else if (now < collection.saleDeadline) {
				// Deadline not passed yet = ongoing
				ongoing.push(collection);
			} else {
				// Deadline passed but not completed = failed
				failed.push(collection);
			}
		}

		// Sort each group by createdAt descending
		ongoing.sort((a, b) => b.createdAt - a.createdAt);
		successful.sort((a, b) => b.createdAt - a.createdAt);
		failed.sort((a, b) => b.createdAt - a.createdAt);

		const transform = (c: Doc<"collections">) => ({
			...c,
			collection_id: c.collectionId,
			collection_name: c.collectionName,
			current_supply: c.currentSupply,
			max_supply: c.maxSupply,
			sale_deadline: c.saleDeadline,
		});

		return {
			ongoing: ongoing.map(transform),
			successful: successful.map(transform),
			failed: failed.map(transform),
		};
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

		return { ...collection, mintStages: stages };
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
 * Internal query to get a collection by its blockchain address
 */
export const getCollectionByAddress = internalQuery({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		return await ctx.db
			.query("collections")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionId))
			.first();
	},
});

/**
 * Internal mutation to create a new collection from blockchain data
 */
export const createCollectionFromBlockchain = internalMutation({
	args: {
		collectionData: v.object({
			collectionId: v.string(),
			collectionName: v.string(),
			description: v.string(),
			uri: v.string(),
			placeholderUri: v.string(),
			creatorAddress: v.string(),
			royaltyAddress: v.string(),
			royaltyPercentage: v.optional(v.number()),
			maxSupply: v.number(),
			currentSupply: v.number(),
			ownerCount: v.number(),
			mintEnabled: v.boolean(),
			saleDeadline: v.number(),
			saleCompleted: v.boolean(),
			totalFundsCollected: v.optional(v.number()),
			devWalletAddress: v.string(),
			faSymbol: v.string(),
			faName: v.string(),
			faIconUri: v.string(),
			faProjectUri: v.string(),
			vestingCliff: v.number(),
			vestingDuration: v.number(),
			creatorVestingWalletAddress: v.string(),
			creatorVestingCliff: v.number(),
			creatorVestingDuration: v.number(),
			// Refund tracking (for failed launches)
			refundNftsBurned: v.optional(v.number()),
			refundTotalAmount: v.optional(v.number()),
			createdAt: v.number(),
			updatedAt: v.number(),
		}),
	},
	handler: async (ctx, args) => {
		// Check if collection already exists
		const existing = await ctx.db
			.query("collections")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionData.collectionId))
			.first();

		if (existing) {
			console.log(`Collection ${args.collectionData.collectionId} already exists, skipping creation`);
			return;
		}

		await ctx.db.insert("collections", args.collectionData);
		console.log(`Created new collection ${args.collectionData.collectionId} in database`);
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
			devWalletAddress: v.optional(v.string()),
			vestingCliff: v.optional(v.number()),
			vestingDuration: v.optional(v.number()),
			creatorVestingWalletAddress: v.optional(v.string()),
			creatorVestingCliff: v.optional(v.number()),
			creatorVestingDuration: v.optional(v.number()),
			faSymbol: v.optional(v.string()),
			faName: v.optional(v.string()),
			faIconUri: v.optional(v.string()),
			faProjectUri: v.optional(v.string()),
			// FA info (populated after sale completion)
			faMetadataAddress: v.optional(v.string()),
			faTotalMinted: v.optional(v.number()),
			faLpAmount: v.optional(v.number()),
			faVestingAmount: v.optional(v.number()),
			faDevWalletAmount: v.optional(v.number()),
			faCreatorVestingAmount: v.optional(v.number()),
			// Actual vesting info from vesting contract (after sale completion)
			vestingStartTime: v.optional(v.number()),
			vestingTotalPool: v.optional(v.number()),
			vestingAmountPerNft: v.optional(v.number()),
			creatorVestingStartTime: v.optional(v.number()),
			creatorVestingTotalPool: v.optional(v.number()),
			// Refund tracking (for failed launches)
			refundNftsBurned: v.optional(v.number()),
			refundTotalAmount: v.optional(v.number()),
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
		totalFundsCollected: v.optional(v.number()),
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
			existing.saleCompleted !== args.saleCompleted ||
			(args.totalFundsCollected !== undefined && existing.totalFundsCollected !== args.totalFundsCollected);

		if (!hasChanged) {
			return { updated: false };
		}

		const patch: {
			currentSupply: number;
			ownerCount: number;
			saleCompleted: boolean;
			totalFundsCollected?: number;
		} = {
			currentSupply: args.currentSupply,
			ownerCount: args.ownerCount,
			saleCompleted: args.saleCompleted,
		};

		if (args.totalFundsCollected !== undefined) {
			patch.totalFundsCollected = args.totalFundsCollected;
		}

		await ctx.db.patch("collections", args.collectionId, patch);

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
