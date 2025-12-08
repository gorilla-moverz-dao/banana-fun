import { query } from "./_generated/server";
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
