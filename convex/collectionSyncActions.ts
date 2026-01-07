"use node";

import { v } from "convex/values";
import { normalizeHexAddress } from "../src/lib/utils";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { type ActionCtx, action, internalAction } from "./_generated/server";
import { createAptosClient } from "./aptos";

// ================================= Shared Types =================================

interface SupplyAndOwnerData {
	currentSupply: number;
	ownerCount: number;
}

interface CollectionViewData {
	total_funds_collected: string;
	sale_deadline: string;
	current_supply: string;
	sale_completed: boolean;
	mint_enabled: boolean;
	max_supply: string;
	description: string;
	uri: string;
	placeholder_uri: string;
	name: string;
	dev_wallet_addr: string;
	fa_symbol: string;
	fa_name: string;
	fa_icon_uri: string;
	fa_project_uri: string;
	vesting_cliff: string;
	vesting_duration: string;
	creator_vesting_wallet_addr: string;
	creator_vesting_cliff: string;
	creator_vesting_duration: string;
	fa_metadata_addr?: { vec: string[] };
	fa_total_minted?: { vec: string[] };
	fa_lp_amount?: { vec: string[] };
	fa_vesting_amount?: { vec: string[] };
	fa_dev_wallet_amount?: { vec: string[] };
	fa_creator_vesting_amount?: { vec: string[] };
	refund_nfts_burned: string;
	refund_total_amount: string;
}

// ================================= Helper Functions =================================

/**
 * Query indexer for current supply and owner count
 */
async function querySupplyAndOwnerCount(
	aptos: ReturnType<typeof createAptosClient>["aptos"],
	collectionId: `0x${string}`,
	fallbackSupply: number,
	fallbackOwnerCount: number,
): Promise<SupplyAndOwnerData> {
	const indexerResult = await aptos.queryIndexer({
		query: {
			query: `
				query GetCollectionSupply($collection_id: String!) {
					current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {
						current_supply
					}
					current_collection_ownership_v2_view_aggregate(where: { collection_id: { _eq: $collection_id } }) {
						aggregate {
							count(distinct: true, columns: owner_address)
						}
					}
				}
			`,
			variables: {
				collection_id: collectionId,
			},
		},
	});

	const data = indexerResult as {
		current_collections_v2: Array<{ current_supply: string }>;
		current_collection_ownership_v2_view_aggregate: {
			aggregate: { count: number } | null;
		};
	};

	return {
		currentSupply: Number(data.current_collections_v2[0]?.current_supply ?? fallbackSupply),
		ownerCount: data.current_collection_ownership_v2_view_aggregate.aggregate?.count ?? fallbackOwnerCount,
	};
}

/**
 * Get collection view data from blockchain
 */
async function getCollectionViewData(
	launchpadClient: ReturnType<typeof createAptosClient>["launchpadClient"],
	collectionId: `0x${string}`,
): Promise<CollectionViewData> {
	const [collectionViewItem] = await launchpadClient.view.get_collection_view_item({
		typeArguments: [],
		functionArguments: [collectionId],
	});
	return collectionViewItem as CollectionViewData;
}

/**
 * Helper to extract value from Move Option (serialized as { vec: T[] })
 */
function extractOption<T>(opt: { vec: T[] } | undefined): T | undefined {
	return opt?.vec?.[0];
}

/**
 * Helper function to sync a single collection's data from blockchain
 * Used for both existing and newly discovered collections
 */
async function syncCollectionData(
	ctx: ActionCtx,
	launchpadClient: ReturnType<typeof createAptosClient>["launchpadClient"],
	aptos: ReturnType<typeof createAptosClient>["aptos"],
	collectionId: `0x${string}`,
	existingCollectionId?: Id<"collections">, // Database ID if collection already exists
	isActive: boolean = true,
) {
	const viewData = await getCollectionViewData(launchpadClient, collectionId);

	// Get creator address from blockchain
	const [creatorAddress] = await launchpadClient.view.get_collection_creator_addr({
		typeArguments: [],
		functionArguments: [collectionId],
	});

	// Query indexer for royalty info and other metadata
	let royaltyAddress: string = creatorAddress.toString();
	let royaltyPercentage: number | undefined;
	let createdAt = Math.floor(Date.now() / 1000); // Default to now if not found

	try {
		const indexerResult = await aptos.queryIndexer({
			query: {
				query: `
					query GetCollectionMetadata($collection_id: String!) {
						current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {
							creator_address
							last_transaction_timestamp
						}
					}
				`,
				variables: {
					collection_id: collectionId,
				},
			},
		});

		const collectionData = indexerResult as {
			current_collections_v2: Array<{
				creator_address: string;
				last_transaction_timestamp: string;
			}>;
		};

		if (collectionData.current_collections_v2.length > 0) {
			royaltyAddress = collectionData.current_collections_v2[0].creator_address;
			// Parse timestamp (format: "2024-01-01T00:00:00Z")
			const timestamp = new Date(collectionData.current_collections_v2[0].last_transaction_timestamp);
			createdAt = Math.floor(timestamp.getTime() / 1000);
		}
	} catch (error) {
		console.warn(`Could not fetch collection metadata from indexer for ${collectionId}:`, error);
	}

	// Query mint stages from blockchain
	let mintStages: Array<{
		name: string;
		mintFee: number;
		startTime: number;
		endTime: number;
		stageType: number;
	}> = [];

	try {
		const [mintStagesInfo] = await launchpadClient.view.get_mint_stages_info({
			typeArguments: [],
			functionArguments: ["0x0", collectionId, []],
		});

		if (mintStagesInfo && Array.isArray(mintStagesInfo)) {
			mintStages = (
				mintStagesInfo as Array<{
					name: string;
					mint_fee: string;
					start_time: string;
					end_time: string;
					stage_type: number;
				}>
			).map((stage) => ({
				name: stage.name,
				mintFee: Number(stage.mint_fee),
				startTime: Number(stage.start_time),
				endTime: Number(stage.end_time),
				stageType: stage.stage_type,
			}));
		}
	} catch (stageError) {
		console.error(`Error fetching mint stages for ${collectionId}:`, stageError);
	}

	// Query indexer for current supply and owner count
	let currentSupply = Number(viewData.current_supply);
	let ownerCount = 0;

	try {
		const supplyData = await querySupplyAndOwnerCount(aptos, collectionId, currentSupply, 0);
		currentSupply = supplyData.currentSupply;
		ownerCount = supplyData.ownerCount;
	} catch (error) {
		console.warn(`Could not fetch supply data from indexer for ${collectionId}:`, error);
	}

	// Fetch vesting config from vesting contract if sale is completed
	let vestingStartTime: number | undefined;
	let vestingTotalPool: number | undefined;
	let vestingAmountPerNft: number | undefined;
	let creatorVestingStartTime: number | undefined;
	let creatorVestingTotalPool: number | undefined;

	if (viewData.sale_completed) {
		const { vestingClient } = createAptosClient();

		try {
			// Fetch NFT holder vesting config
			const holderVestingConfig = await vestingClient.view.get_vesting_config({
				functionArguments: [collectionId],
				typeArguments: [],
			});
			// Returns: (total_pool, amount_per_nft, cliff, duration, start_time)
			vestingTotalPool = Number(holderVestingConfig[0]);
			vestingAmountPerNft = Number(holderVestingConfig[1]);
			vestingStartTime = Number(holderVestingConfig[4]);
		} catch (error) {
			console.warn(`Could not fetch holder vesting config for ${collectionId}:`, error);
		}

		try {
			// Fetch creator vesting config
			const creatorVestingConfig = await vestingClient.view.get_creator_vesting_config({
				functionArguments: [collectionId],
				typeArguments: [],
			});
			// Returns: (total_pool, beneficiary, cliff, duration, start_time, claimed_amount)
			creatorVestingTotalPool = Number(creatorVestingConfig[0]);
			creatorVestingStartTime = Number(creatorVestingConfig[4]);
		} catch (error) {
			console.warn(`Could not fetch creator vesting config for ${collectionId}:`, error);
		}
	}

	if (existingCollectionId) {
		// Update existing collection
		await ctx.runMutation(internal.collections.updateCollectionFromBlockchain, {
			collectionId: existingCollectionId,
			updates: {
				totalFundsCollected: Number(viewData.total_funds_collected),
				saleDeadline: Number(viewData.sale_deadline),
				mintEnabled: isActive && viewData.mint_enabled,
				devWalletAddress: viewData.dev_wallet_addr,
				vestingCliff: Number(viewData.vesting_cliff),
				vestingDuration: Number(viewData.vesting_duration),
				creatorVestingWalletAddress: viewData.creator_vesting_wallet_addr,
				creatorVestingCliff: Number(viewData.creator_vesting_cliff),
				creatorVestingDuration: Number(viewData.creator_vesting_duration),
				faSymbol: viewData.fa_symbol,
				faName: viewData.fa_name,
				faIconUri: viewData.fa_icon_uri,
				faProjectUri: viewData.fa_project_uri,
				// FA info (populated after sale completion) - extract from Move Option
				faMetadataAddress: extractOption(viewData.fa_metadata_addr),
				faTotalMinted: extractOption(viewData.fa_total_minted)
					? Number(extractOption(viewData.fa_total_minted))
					: undefined,
				faLpAmount: extractOption(viewData.fa_lp_amount) ? Number(extractOption(viewData.fa_lp_amount)) : undefined,
				faVestingAmount: extractOption(viewData.fa_vesting_amount)
					? Number(extractOption(viewData.fa_vesting_amount))
					: undefined,
				faDevWalletAmount: extractOption(viewData.fa_dev_wallet_amount)
					? Number(extractOption(viewData.fa_dev_wallet_amount))
					: undefined,
				faCreatorVestingAmount: extractOption(viewData.fa_creator_vesting_amount)
					? Number(extractOption(viewData.fa_creator_vesting_amount))
					: undefined,
				// Actual vesting info from vesting contract (after sale completion)
				vestingStartTime,
				vestingTotalPool,
				vestingAmountPerNft,
				creatorVestingStartTime,
				creatorVestingTotalPool,
				// Refund tracking (for failed launches)
				refundNftsBurned: Number(viewData.refund_nfts_burned),
				refundTotalAmount: Number(viewData.refund_total_amount),
				updatedAt: Date.now(),
			},
		});

		// Update supply separately
		await ctx.runMutation(internal.collections.updateCollectionSupply, {
			collectionId: existingCollectionId,
			currentSupply: currentSupply,
			ownerCount: ownerCount,
			saleCompleted: viewData.sale_completed,
		});
	} else {
		// Create new collection
		await ctx.runMutation(internal.collections.createCollectionFromBlockchain, {
			collectionData: {
				collectionId: collectionId,
				collectionName: viewData.name,
				description: viewData.description,
				uri: viewData.uri,
				placeholderUri: viewData.placeholder_uri,
				creatorAddress: creatorAddress.toString(),
				royaltyAddress: royaltyAddress,
				royaltyPercentage: royaltyPercentage,
				maxSupply: Number(viewData.max_supply),
				currentSupply: currentSupply,
				ownerCount: ownerCount,
				mintEnabled: isActive && viewData.mint_enabled,
				saleDeadline: Number(viewData.sale_deadline),
				saleCompleted: viewData.sale_completed,
				totalFundsCollected: Number(viewData.total_funds_collected),
				devWalletAddress: viewData.dev_wallet_addr,
				faSymbol: viewData.fa_symbol,
				faName: viewData.fa_name,
				faIconUri: viewData.fa_icon_uri,
				faProjectUri: viewData.fa_project_uri,
				vestingCliff: Number(viewData.vesting_cliff),
				vestingDuration: Number(viewData.vesting_duration),
				creatorVestingWalletAddress: viewData.creator_vesting_wallet_addr,
				creatorVestingCliff: Number(viewData.creator_vesting_cliff),
				creatorVestingDuration: Number(viewData.creator_vesting_duration),
				// Refund tracking (for failed launches)
				refundNftsBurned: Number(viewData.refund_nfts_burned),
				refundTotalAmount: Number(viewData.refund_total_amount),
				createdAt: createdAt,
				updatedAt: Date.now(),
			},
		});
	}

	// Update mint stages in separate table (always upsert, even if empty, to clear old stages)
	await ctx.runMutation(internal.collections.upsertMintStages, {
		collectionId: collectionId,
		stages: mintStages,
	});

	console.log(
		`Synced collection ${collectionId}: ${mintStages.length} stages, funds=${viewData.total_funds_collected}`,
	);
}

/**
 * Helper function to sync supply data for a single collection
 * Returns the synced data or null if sync failed
 */
async function syncCollectionSupply(
	ctx: ActionCtx,
	aptos: ReturnType<typeof createAptosClient>["aptos"],
	launchpadClient: ReturnType<typeof createAptosClient>["launchpadClient"],
	account: ReturnType<typeof createAptosClient>["account"],
	collection: {
		_id: Id<"collections">;
		collectionId: string;
		maxSupply: number;
		currentSupply: number;
		ownerCount: number | undefined;
		saleCompleted: boolean;
		totalFundsCollected: number | undefined;
	},
): Promise<{
	currentSupply: number;
	ownerCount: number;
	saleCompleted: boolean;
	totalFundsCollected: number;
	saleJustCompleted: boolean;
} | null> {
	const collectionId = collection.collectionId as `0x${string}`;

	// Get current supply and total funds directly from blockchain (up-to-date immediately after mint)
	const viewData = await getCollectionViewData(launchpadClient, collectionId);
	const currentSupply = Number(viewData.current_supply);
	const totalFundsCollected = Number(viewData.total_funds_collected);

	// Query indexer for owner count only (some lag is acceptable for this)
	const { ownerCount } = await querySupplyAndOwnerCount(aptos, collectionId, currentSupply, collection.ownerCount ?? 0);

	// Use sale_completed from view data (already fetched)
	let saleCompleted = viewData.sale_completed;

	// If max supply reached but sale not completed, trigger completion
	if (currentSupply === collection.maxSupply && !saleCompleted) {
		console.log(`Checking and completing sale for ${collectionId}`);
		await launchpadClient.entry.check_and_complete_sale({
			typeArguments: [],
			functionArguments: [collectionId],
			account: account,
		});

		// Re-check sale status after completion attempt (need fresh query)
		const [freshSaleCompleted] = await launchpadClient.view.is_sale_completed({
			typeArguments: [],
			functionArguments: [collectionId],
		});
		saleCompleted = freshSaleCompleted;
	}

	// Check if sale just completed (was false, now true)
	const saleJustCompleted = !collection.saleCompleted && saleCompleted;

	// Check if anything changed
	const hasChanged =
		currentSupply !== collection.currentSupply ||
		ownerCount !== collection.ownerCount ||
		saleCompleted !== collection.saleCompleted ||
		totalFundsCollected !== collection.totalFundsCollected;

	if (!hasChanged) {
		return null;
	}

	// Update the database
	await ctx.runMutation(internal.collections.updateCollectionSupply, {
		collectionId: collection._id,
		currentSupply,
		ownerCount,
		saleCompleted,
		totalFundsCollected,
	});

	console.log(
		`Synced supply for ${collectionId}: ${currentSupply} minted, ${ownerCount} owners, ${totalFundsCollected} collected, saleCompleted=${saleCompleted}`,
	);

	// If sale just completed, trigger a full sync to get vesting data
	if (saleJustCompleted) {
		console.log(`Sale just completed for ${collectionId}, syncing full collection data with vesting info`);
		try {
			await syncCollectionData(ctx, launchpadClient, aptos, collectionId, collection._id, true);
		} catch (syncError) {
			console.error(`Error syncing full data for newly completed sale ${collectionId}:`, syncError);
		}
	}

	return { currentSupply, ownerCount, saleCompleted, totalFundsCollected, saleJustCompleted };
}

/**
 * Sync supply data (currentSupply, ownerCount, saleCompleted, totalFundsCollected) - runs frequently (every 30 seconds)
 * This data changes often during active mints
 */
export const syncCollectionSupplyAction = internalAction({
	args: {},
	handler: async (ctx) => {
		console.log("Syncing collection supply data from blockchain");
		const { aptos, launchpadClient, account } = createAptosClient();

		// Get all collections from database
		const collections = await ctx.runQuery(internal.collections.getCollectionsToSync);

		// Sync each collection's supply data
		for (const collection of collections) {
			try {
				await syncCollectionSupply(ctx, aptos, launchpadClient, account, {
					_id: collection._id,
					collectionId: collection.collectionId,
					maxSupply: collection.maxSupply,
					currentSupply: collection.currentSupply,
					ownerCount: collection.ownerCount,
					saleCompleted: collection.saleCompleted,
					totalFundsCollected: collection.totalFundsCollected,
				});
			} catch (error) {
				console.error(`Error syncing supply for ${collection.collectionId}:`, error);
				// Continue with other collections even if one fails
			}
		}

		return null;
	},
});

/**
 * Sync full collection data - runs less frequently (every 30 minutes)
 * This includes sale state, mint stages, and other data that changes infrequently
 * Also discovers and syncs newly created collections from the blockchain
 */
export const syncCollectionDataAction = internalAction({
	args: {},
	handler: async (ctx) => {
		console.log("Syncing full collection data from blockchain");
		const { launchpadClient, aptos } = createAptosClient();

		// Get all collections from database
		const collections = await ctx.runQuery(internal.collections.getCollectionsToSync);
		const dbCollectionIds = new Set(collections.map((c) => normalizeHexAddress(c.collectionId.toLowerCase())));

		// Get registry from blockchain to see which collections are active
		const [registry] = await launchpadClient.view.get_registry({
			functionArguments: [],
			typeArguments: [],
		});

		const activeCollectionIds = new Set(registry.map((item) => normalizeHexAddress(item.inner.toLowerCase())));

		// Sync existing collections
		for (const collection of collections) {
			try {
				// Ensure collection ID is properly formatted (with 0x prefix)
				const collectionIdRaw = collection.collectionId.startsWith("0x")
					? collection.collectionId.toLowerCase()
					: `0x${collection.collectionId.toLowerCase()}`;
				const collectionId = collectionIdRaw as `0x${string}`;

				const isActive = activeCollectionIds.has(collectionId);

				await syncCollectionData(ctx, launchpadClient, aptos, collectionId, collection._id, isActive);
			} catch (error) {
				console.error(`Error syncing collection ${collection.collectionId}:`, error);
				// Continue with other collections even if one fails
			}
		}

		// Discover and sync new collections from registry
		for (const registryItem of registry) {
			try {
				const collectionId = normalizeHexAddress(registryItem.inner.toLowerCase()) as `0x${string}`;

				// Skip if already in database
				if (dbCollectionIds.has(collectionId)) {
					continue;
				}

				console.log(`Discovering new collection: ${collectionId}`);
				await syncCollectionData(ctx, launchpadClient, aptos, collectionId, undefined, true);
			} catch (error) {
				console.error(`Error syncing new collection ${registryItem.inner}:`, error);
				// Continue with other collections even if one fails
			}
		}

		return null;
	},
});

/**
 * Internal action to enable minting on the blockchain and sync the state back
 * Called after all reveal items are uploaded and count matches maxSupply
 */
export const enableMintOnBlockchain = internalAction({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args): Promise<{ enabled: boolean }> => {
		const { launchpadClient, aptos, account } = createAptosClient();

		const collectionObject = args.collectionId as `0x${string}`;

		try {
			// Call update_mint_enabled on the blockchain
			await launchpadClient.entry.update_mint_enabled({
				typeArguments: [],
				functionArguments: [collectionObject, true],
				account,
			});

			console.log(`Enabled minting on blockchain for collection ${args.collectionId}`);

			// Get the collection from database to sync
			const collection = await ctx.runQuery(internal.collections.getCollectionByAddress, {
				collectionId: args.collectionId,
			});

			if (collection) {
				// Sync the collection data to update mintEnabled in Convex
				await syncCollectionData(ctx, launchpadClient, aptos, collectionObject, collection._id, true);
				console.log(`Synced collection ${args.collectionId} after enabling mint`);
			}

			return { enabled: true };
		} catch (error) {
			console.error(`Failed to enable minting for collection ${args.collectionId}:`, error);
			return { enabled: false };
		}
	},
});

/**
 * Public action to sync collection stats after a refund
 * Called from the client after a successful refund to update supply, owner count, and refund stats
 */
export const afterRefund = action({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args): Promise<{ synced: boolean }> => {
		const { aptos, launchpadClient } = createAptosClient();

		// Get the collection from database
		const collection = await ctx.runQuery(internal.collections.getCollectionByAddress, {
			collectionId: args.collectionId,
		});

		if (!collection) {
			console.warn(`afterRefund: Collection ${args.collectionId} not found in database`);
			return { synced: false };
		}

		const collectionId = args.collectionId as `0x${string}`;

		try {
			// Query indexer for current supply and owner count (burned NFTs reduce supply)
			const { currentSupply, ownerCount } = await querySupplyAndOwnerCount(
				aptos,
				collectionId,
				collection.currentSupply,
				collection.ownerCount ?? 0,
			);

			// Get refund stats from blockchain
			const viewData = await getCollectionViewData(launchpadClient, collectionId);

			// Update the database with refund stats
			await ctx.runMutation(internal.collections.updateCollectionRefundStats, {
				collectionId: collection._id,
				currentSupply,
				ownerCount,
				refundNftsBurned: Number(viewData.refund_nfts_burned),
				refundTotalAmount: Number(viewData.refund_total_amount),
				totalFundsCollected: Number(viewData.total_funds_collected),
			});

			console.log(
				`afterRefund: Synced ${collectionId}: supply=${currentSupply}, owners=${ownerCount}, burned=${viewData.refund_nfts_burned}, refunded=${viewData.refund_total_amount}`,
			);

			return { synced: true };
		} catch (error) {
			console.error(`afterRefund: Error syncing ${args.collectionId}:`, error);
			return { synced: false };
		}
	},
});

/**
 * Public action to sync collection supply after minting and trigger reveals
 * Called from the client after a successful mint to update supply, owner count, and reveal NFTs
 */
export const afterMint = action({
	args: {
		collectionId: v.string(),
		nftTokenIds: v.optional(v.array(v.string())), // NFT token IDs to reveal
	},
	handler: async (ctx, args): Promise<{ synced: boolean; reveals: { nftTokenId: string; success: boolean }[] }> => {
		const { aptos, launchpadClient, account } = createAptosClient();
		const reveals: { nftTokenId: string; success: boolean }[] = [];

		// Get the collection from database
		const collection = await ctx.runQuery(internal.collections.getCollectionByAddress, {
			collectionId: args.collectionId,
		});

		if (!collection) {
			console.warn(`Collection ${args.collectionId} not found in database`);
			return { synced: false, reveals };
		}

		// Sync collection supply
		let synced = false;
		try {
			await syncCollectionSupply(ctx, aptos, launchpadClient, account, {
				_id: collection._id,
				collectionId: collection.collectionId,
				maxSupply: collection.maxSupply,
				currentSupply: collection.currentSupply,
				ownerCount: collection.ownerCount,
				saleCompleted: collection.saleCompleted,
				totalFundsCollected: collection.totalFundsCollected,
			});
			synced = true;
		} catch (error) {
			console.error(`afterMint: Error syncing ${args.collectionId}:`, error);
		}

		// Reveal NFTs if token IDs provided
		if (args.nftTokenIds && args.nftTokenIds.length > 0) {
			for (const nftTokenId of args.nftTokenIds) {
				try {
					const normalizedId = normalizeHexAddress(nftTokenId);
					const result = await ctx.runAction(internal.revealActions.revealNft, {
						collectionId: args.collectionId,
						nftTokenId: normalizedId,
					});
					reveals.push({ nftTokenId: normalizedId, success: result.success });
				} catch (error) {
					console.error(`afterMint: Error revealing NFT ${nftTokenId}:`, error);
					reveals.push({ nftTokenId, success: false });
				}
			}
		}
		return { synced, reveals };
	},
});
