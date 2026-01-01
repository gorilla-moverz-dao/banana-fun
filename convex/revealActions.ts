"use node";

import { v } from "convex/values";
import { internal } from "./_generated/api";
import { action, internalAction } from "./_generated/server";
import { createAptosClient } from "./aptos";
import { revealItemValidator } from "./reveal";

/**
 * Public action to upload reveal data for a collection
 * Handles batching for large datasets (10k+ items)
 * Automatically enables minting when reveal item count matches maxSupply
 */
export const uploadRevealData = action({
	args: {
		collectionId: v.string(),
		items: v.array(revealItemValidator),
	},
	handler: async (ctx, args): Promise<{ inserted: number; mintEnabled: boolean }> => {
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

		// We might not have initially synced the collection, so we need to sync it
		await ctx.runAction(internal.collectionSyncActions.syncCollectionDataAction, {});

		// Check if we should enable minting (reveal item count matches maxSupply)
		const [revealItemCount, collection] = await Promise.all([
			ctx.runQuery(internal.reveal.countRevealItems, { collectionId: args.collectionId }),
			ctx.runQuery(internal.collections.getCollectionByAddress, { collectionId: args.collectionId }),
		]);

		let mintEnabled = false;
		if (collection && revealItemCount === collection.maxSupply) {
			const { enabled } = await ctx.runAction(internal.collectionSyncActions.enableMintOnBlockchain, {
				collectionId: args.collectionId,
			});
			mintEnabled = enabled;
			console.log(
				`Reveal items (${revealItemCount}) match maxSupply (${collection.maxSupply}), mint enabled: ${mintEnabled}`,
			);
		} else if (collection) {
			console.log(
				`Reveal items (${revealItemCount}) do not match maxSupply (${collection.maxSupply}), mint not enabled`,
			);
		}

		return { inserted: totalInserted, mintEnabled };
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
		const { aptos, launchpadClient, account } = createAptosClient();

		try {
			// Convert traits to prop_names and prop_values arrays
			const propNames = item.traits.map((t: { trait_type: string; value: string }) => t.trait_type);
			const propValues = item.traits.map((t: { trait_type: string; value: string }) => t.value);

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

			// Fetch owner address from indexer
			let ownerAddress: string | undefined;
			try {
				const indexerResult = await aptos.queryIndexer({
					query: {
						query: `
							query GetNFTOwner($token_data_id: String!) {
								current_token_ownerships_v2(
									where: { token_data_id: { _eq: $token_data_id }, amount: { _gt: 0 } }
									limit: 1
								) {
									owner_address
								}
							}
						`,
						variables: {
							token_data_id: args.nftTokenId,
						},
					},
				});

				const data = indexerResult as {
					current_token_ownerships_v2: Array<{ owner_address: string }>;
				};

				ownerAddress = data.current_token_ownerships_v2[0]?.owner_address;
			} catch (error) {
				console.warn(`Could not fetch owner for NFT ${args.nftTokenId}:`, error);
			}

			// Mark the item as revealed with owner address
			await ctx.runMutation(internal.reveal.markRevealed, {
				itemId: item._id,
				nftTokenId: args.nftTokenId,
				ownerAddress,
			});

			console.log(`Revealed NFT ${args.nftTokenId} with item ${item.name}, owner: ${ownerAddress}`);
			return { success: true, revealedItem: { name: item.name, uri: item.uri } };
		} catch (error) {
			console.error(`Failed to reveal NFT ${args.nftTokenId}:`, error);
			return { success: false };
		}
	},
});
