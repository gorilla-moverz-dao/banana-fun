"use node";

import { v } from "convex/values";
import { internal } from "./_generated/api";
import { action, internalAction } from "./_generated/server";
import { createAptosClient } from "./aptos";
import { revealItemValidator } from "./reveal";

/**
 * Public action to upload reveal data for a collection
 * Handles batching for large datasets (10k+ items)
 */
export const uploadRevealData = action({
	args: {
		collectionId: v.string(),
		items: v.array(revealItemValidator),
	},
	handler: async (ctx, args) => {
		const BATCH_SIZE = 100;
		let totalInserted = 0;

		// Process items in batches
		for (let i = 0; i < args.items.length; i += BATCH_SIZE) {
			const batch = args.items.slice(i, i + BATCH_SIZE);
			const inserted = await ctx.runMutation(internal.reveal.uploadRevealDataBatch, {
				collectionId: args.collectionId,
				items: batch,
			});
			totalInserted += inserted;
		}

		console.log(`Uploaded ${totalInserted} reveal items for collection ${args.collectionId}`);
		return { inserted: totalInserted };
	},
});

/**
 * Internal action to reveal a single NFT on the blockchain
 * Picks a random unrevealed item and reveals it
 */
export const revealNft = internalAction({
	args: {
		collectionId: v.string(),
		nftTokenId: v.string(),
	},
	handler: async (ctx, args): Promise<{ success: boolean; revealedItem?: { name: string; uri: string } }> => {
		// Get a random unrevealed item
		const item = await ctx.runQuery(internal.reveal.getRandomUnrevealedItem, {
			collectionId: args.collectionId,
		});

		if (!item) {
			console.warn(`No unrevealed items found for collection ${args.collectionId}`);
			return { success: false };
		}

		// Create Aptos client and call reveal_nft
		const { launchpadClient, account } = createAptosClient();

		try {
			// Convert traits to prop_names and prop_values arrays
			const propNames = item.traits.map((t) => t.trait_type);
			const propValues = item.traits.map((t) => t.value);

			await launchpadClient.entry.reveal_nft({
				typeArguments: [],
				functionArguments: [
					args.collectionId as `0x${string}`, // collection_obj
					args.nftTokenId as `0x${string}`, // nft_obj
					item.name, // name
					item.description, // description
					item.uri, // uri
					propNames, // prop_names
					propValues, // prop_values
				],
				account,
			});

			// Mark the item as revealed
			await ctx.runMutation(internal.reveal.markRevealed, {
				itemId: item._id,
				nftTokenId: args.nftTokenId,
			});

			console.log(`Revealed NFT ${args.nftTokenId} with item ${item.name}`);
			return { success: true, revealedItem: { name: item.name, uri: item.uri } };
		} catch (error) {
			console.error(`Failed to reveal NFT ${args.nftTokenId}:`, error);
			return { success: false };
		}
	},
});
