import { internalMutation, internalQuery, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Get all collections that have minting enabled
 */
export const getMintingCollections = query({
	args: {},
	handler: async (ctx) => {
		const collections = await ctx.db
			.query("collections")
			.withIndex("by_mint_enabled", (q) => q.eq("mintEnabled", true))
			.collect();

		// Sort by createdAt descending (newest first)
		collections.sort((a, b) => b.createdAt - a.createdAt);

		// Transform to match the expected format from the old GraphQL query
		return collections.map((collection) => ({
			collection_id: collection.collectionId,
			collection_name: collection.collectionName,
			current_supply: collection.currentSupply,
			max_supply: collection.maxSupply,
			uri: collection.uri || collection.placeholderUri || "",
			description: collection.description || "",
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

		// Transform mint stages to match the expected format
		const stages = collection.mintStages?.map((stage) => ({
			name: stage.name,
			mint_fee: stage.mintFee.toString(),
			mint_fee_with_reduction: stage.mintFee.toString(), // Will be calculated with reduction NFTs on client
			start_time: stage.startTime.toString(),
			end_time: stage.endTime.toString(),
			stage_type: stage.stageType,
		})) || [];

		// Transform to match the expected format from useCollectionData
		return {
			collection: {
				creator_address: collection.creatorAddress,
				collection_id: collection.collectionId,
				collection_name: collection.collectionName,
				current_supply: collection.currentSupply,
				max_supply: collection.maxSupply,
				uri: collection.uri || collection.placeholderUri || "",
				description: collection.description || "",
			},
			ownerCount: 0, // TODO: Calculate from NFT ownership data or sync separately
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
 * Internal mutation to update collection data from blockchain
 */
export const updateCollectionFromBlockchain = internalMutation({
	args: {
		collectionId: v.id("collections"),
		updates: v.object({
			currentSupply: v.number(),
			totalFundsCollected: v.optional(v.number()),
			saleCompleted: v.optional(v.boolean()),
			saleDeadline: v.optional(v.number()),
			mintEnabled: v.optional(v.boolean()),
			mintStages: v.optional(
				v.array(
					v.object({
						name: v.string(),
						mintFee: v.number(),
						startTime: v.number(),
						endTime: v.number(),
						stageType: v.number(),
					}),
				),
			),
			updatedAt: v.number(),
		}),
	},
	handler: async (ctx, args) => {
		const existing = await ctx.db.get(args.collectionId);
		if (!existing) {
			console.error(`Collection ${args.collectionId} not found in database`);
			return;
		}

		await ctx.db.patch(args.collectionId, args.updates);
		console.log(`Updated collection ${args.collectionId} with mintStages: ${args.updates.mintStages?.length ?? 0} stages`);
	},
});
