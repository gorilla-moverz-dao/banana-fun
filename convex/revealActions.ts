"use node";

import { Workpool } from "@convex-dev/workpool";
import { v } from "convex/values";
import { waitForIndexerVersion } from "../src/lib/aptos-utils";
import { components, internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { action, internalAction } from "./_generated/server";
import { createAptosClient } from "./aptos";
import { revealItemValidator } from "./reveal";

// Create a workpool with maxParallelism: 1 to ensure only one reveal transaction
// runs at a time. This prevents "Transaction already in mempool" errors that occur
// when multiple blockchain transactions compete for the same sequence number.
const revealPool = new Workpool(components.revealWorkpool, {
	maxParallelism: 1,
	// Retry failed reveals with exponential backoff
	retryActionsByDefault: true,
	defaultRetryBehavior: {
		maxAttempts: 3,
		initialBackoffMs: 2000,
		base: 2,
	},
});

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
 * Queue a reveal for processing via workpool
 * The workpool ensures only one reveal runs at a time (maxParallelism: 1)
 */
export const queueReveal = internalAction({
	args: {
		collectionId: v.string(),
		nftTokenId: v.string(),
	},
	handler: async (ctx, args): Promise<{ queued: boolean }> => {
		console.log(`Queueing reveal for NFT ${args.nftTokenId} via workpool`);

		// Enqueue the actual reveal action to the workpool
		await revealPool.enqueueAction(ctx, internal.revealActions.doRevealOnChain, {
			collectionId: args.collectionId,
			nftTokenId: args.nftTokenId,
		});

		return { queued: true };
	},
});

/**
 * Internal action that performs the actual reveal on the blockchain
 * This is called by the workpool, which ensures serial execution
 */
export const doRevealOnChain = internalAction({
	args: {
		collectionId: v.string(),
		nftTokenId: v.string(),
	},
	handler: async (ctx, args): Promise<{ success: boolean; name?: string; uri?: string }> => {
		console.log(`Processing reveal for NFT ${args.nftTokenId}`);

		// Get a random unrevealed item
		const item = (await ctx.runQuery(internal.reveal.getRandomUnrevealedItem, {
			collectionId: args.collectionId,
		})) as Doc<"nftRevealItems"> | null;

		if (!item) {
			console.warn(`No unrevealed items found for collection ${args.collectionId}`);
			return { success: false };
		}

		// Create Aptos client and call reveal_nft
		const { aptos, launchpadClient, account } = createAptosClient();

		// Convert traits to prop_names and prop_values arrays
		const propNames = item.traits.map((t) => t.trait_type);
		const propValues = item.traits.map((t) => t.value);

		const txResponse = await launchpadClient.entry.reveal_nft({
			typeArguments: [],
			functionArguments: [
				args.collectionId as `0x${string}`,
				args.nftTokenId as `0x${string}`,
				item.name,
				item.description,
				item.uri,
				propNames,
				propValues,
			],
			account,
		});

		// Wait for transaction to be committed
		const committedTx = await aptos.waitForTransaction({ transactionHash: txResponse.hash });

		// Wait for indexer to catch up to the transaction version
		// This ensures we can fetch the owner address reliably
		try {
			await waitForIndexerVersion(aptos, committedTx.version);
		} catch (error) {
			console.warn(`Failed to wait for indexer version, proceeding anyway:`, error);
		}

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
		return { success: true, name: item.name, uri: item.uri };
	},
});

/**
 * Reveal an NFT - queues via workpool for serial execution
 * This is the main entry point called from afterMint
 */
export const revealNft = internalAction({
	args: {
		collectionId: v.string(),
		nftTokenId: v.string(),
	},
	handler: async (ctx, args): Promise<{ success: boolean; revealedItem?: { name: string; uri: string } }> => {
		try {
			// Queue the reveal via workpool
			await ctx.runAction(internal.revealActions.queueReveal, {
				collectionId: args.collectionId,
				nftTokenId: args.nftTokenId,
			});

			// For backwards compatibility, we wait for the reveal to complete
			// Poll for completion
			const maxWaitMs = 60000;
			const pollIntervalMs = 1000;
			const startTime = Date.now();

			while (Date.now() - startTime < maxWaitMs) {
				// Check if the NFT has been revealed
				const revealedItem = (await ctx.runQuery(internal.reveal.getRevealedItemByNftTokenId, {
					nftTokenId: args.nftTokenId,
				})) as Doc<"nftRevealItems"> | null;

				if (revealedItem) {
					return {
						success: true,
						revealedItem: { name: revealedItem.name, uri: revealedItem.uri },
					};
				}

				// Wait before checking again
				await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
			}

			console.warn(`Reveal timed out waiting for NFT ${args.nftTokenId}`);
			return { success: false };
		} catch (error) {
			console.error(`Failed to reveal NFT ${args.nftTokenId}:`, error);
			return { success: false };
		}
	},
});
