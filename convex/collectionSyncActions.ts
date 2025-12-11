"use node";

import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { internal } from "./_generated/api";
import { internalAction } from "./_generated/server";
import { ABI as launchpadABI } from "../src/abi/nft_launchpad";

// Constants - should match src/constants.ts
const LAUNCHPAD_MODULE_ADDRESS = "0x400b0f8d7c011756381fb473b432d46eed94f7cc47db3ef93b76ccd76a72ed8e";

// Network configuration - should match src/lib/networks.ts
const MOVE_NETWORK = {
	rpcUrl: process.env.VITE_RPC_URL || "https://testnet.movementnetwork.xyz/v1",
	indexerUrl: process.env.VITE_INDEXER_URL || "https://hasura.testnet.movementnetwork.xyz/v1/graphql",
	faucetUrl: process.env.VITE_FAUCET_URL || "https://faucet.testnet.movementnetwork.xyz",
};

function createAptosClient() {
	const config = new AptosConfig({
		network: Network.CUSTOM,
		fullnode: MOVE_NETWORK.rpcUrl,
		indexer: MOVE_NETWORK.indexerUrl,
		faucet: MOVE_NETWORK.faucetUrl,
	});

	const aptos = new Aptos(config);
	const launchpadClient = createSurfClient(aptos).useABI(launchpadABI, LAUNCHPAD_MODULE_ADDRESS);

	return { aptos, launchpadClient };
}

/**
 * Sync supply data (currentSupply, ownerCount, saleCompleted) - runs frequently (every 30 seconds)
 * This data changes often during active mints
 */
export const syncCollectionSupplyAction = internalAction({
	args: {},
	handler: async (ctx) => {
		console.log("Syncing collection supply data from indexer");
		const { aptos, launchpadClient } = createAptosClient();

		// Get all collections from database
		const collections = await ctx.runQuery(internal.collections.getCollectionsToSync);

		// Sync each collection's supply data
		for (const collection of collections) {
			try {
				// Ensure collection ID is properly formatted (with 0x prefix)
				const collectionIdRaw = collection.collectionId.startsWith("0x")
					? collection.collectionId.toLowerCase()
					: `0x${collection.collectionId.toLowerCase()}`;
				const collectionId = collectionIdRaw as `0x${string}`;

				// Query indexer for current supply and owner count
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

				const collectionData = indexerResult as {
					current_collections_v2: Array<{ current_supply: number }>;
					current_collection_ownership_v2_view_aggregate: {
						aggregate: { count: number } | null;
					};
				};

				const currentSupply =
					collectionData.current_collections_v2[0]?.current_supply ?? collection.currentSupply;
				const ownerCount =
					collectionData.current_collection_ownership_v2_view_aggregate.aggregate?.count ?? 0;

				// Query blockchain for sale completion status
				const [saleCompleted] = await launchpadClient.view.is_sale_completed({
					typeArguments: [],
					functionArguments: [collectionId],
				});

				// Update supply and sale status (mutation checks if data changed before writing)
				const result = await ctx.runMutation(internal.collections.updateCollectionSupply, {
					collectionId: collection._id,
					currentSupply: Number(currentSupply),
					ownerCount: Number(ownerCount),
					saleCompleted: saleCompleted,
				});

				if (result?.updated) {
					console.log(
						`Updated ${collectionId}: ${currentSupply} minted, ${ownerCount} owners, saleCompleted=${saleCompleted}`,
					);
				}
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
 */
export const syncCollectionDataAction = internalAction({
	args: {},
	handler: async (ctx) => {
		console.log("Syncing full collection data from blockchain");
		const { launchpadClient } = createAptosClient();

		// Get all collections from database
		const collections = await ctx.runQuery(internal.collections.getCollectionsToSync);

		// Get registry from blockchain to see which collections are active
		const [registry] = await launchpadClient.view.get_registry({
			functionArguments: [],
			typeArguments: [],
		});

		const activeCollectionIds = new Set(
			registry.map((item) => item.inner.toLowerCase()),
		);

		// Sync each collection
		for (const collection of collections) {
			try {
				// Ensure collection ID is properly formatted (with 0x prefix)
				const collectionIdRaw = collection.collectionId.startsWith("0x")
					? collection.collectionId.toLowerCase()
					: `0x${collection.collectionId.toLowerCase()}`;
				const collectionId = collectionIdRaw as `0x${string}`;
				const isActive = activeCollectionIds.has(collectionId);

				// Use collection ID directly as Object<Collection> (Aptos SDK handles the conversion)
				const collectionObject = collectionId as `0x${string}`;

				// Query blockchain for collection state
				const [collectedFunds] = await launchpadClient.view.get_collected_funds({
					typeArguments: [],
					functionArguments: [collectionObject],
				});

				const [saleDeadline] = await launchpadClient.view.get_sale_deadline({
					typeArguments: [],
					functionArguments: [collectionObject],
				});

				// Query mint stages from blockchain (using dummy address and no reduction NFTs for base data)
				let mintStages: Array<{
					name: string;
					mintFee: number;
					startTime: number;
					endTime: number;
					stageType: number;
				}> = [];

				try {
					console.log(`Fetching mint stages for collection ${collectionId}...`);
					const [mintStagesInfo] = await launchpadClient.view.get_mint_stages_info({
						typeArguments: [],
						functionArguments: ["0x0", collectionObject, []],
					});

					if (!mintStagesInfo || !Array.isArray(mintStagesInfo)) {
						console.warn(`No mint stages info returned for ${collectionId}`);
					} else {
						// Transform mint stages to match schema format
						mintStages = (mintStagesInfo as Array<{
							name: string;
							mint_fee: string;
							start_time: string;
							end_time: string;
							stage_type: number;
						}>).map((stage) => ({
							name: stage.name,
							mintFee: Number(stage.mint_fee),
							startTime: Number(stage.start_time),
							endTime: Number(stage.end_time),
							stageType: stage.stage_type,
						}));

						console.log(`Found ${mintStages.length} mint stages for collection ${collectionId}:`, mintStages.map(s => s.name));
					}
				} catch (stageError) {
					console.error(`Error fetching mint stages for ${collectionId}:`, stageError);
					// Continue without stages if the query fails
				}

				// Update collection in database (currentSupply, ownerCount, saleCompleted are updated by the supply sync action)
				await ctx.runMutation(internal.collections.updateCollectionFromBlockchain, {
					collectionId: collection._id,
					updates: {
						totalFundsCollected: Number(collectedFunds),
						saleDeadline: Number(saleDeadline),
						mintEnabled: isActive,
						updatedAt: Date.now(),
					},
				});

				// Update mint stages in separate table (always upsert, even if empty, to clear old stages)
				await ctx.runMutation(internal.collections.upsertMintStages, {
					collectionId: collectionId,
					stages: mintStages,
				});

				console.log(
					`Synced collection ${collectionId}: ${mintStages.length} stages, funds=${collectedFunds}`,
				);
			} catch (error) {
				console.error(`Error syncing collection ${collection.collectionId}:`, error);
				// Continue with other collections even if one fails
			}
		}

		return null;
	},
});
