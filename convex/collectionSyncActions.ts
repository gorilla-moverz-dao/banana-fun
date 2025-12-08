"use node";

import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { internal } from "./_generated/api";
import { internalAction } from "./_generated/server";
import { ABI as launchpadABI } from "../src/abi/nft_launchpad";

// Constants - should match src/constants.ts
const LAUNCHPAD_MODULE_ADDRESS = "0x598db4c36c6aceb951c79fca46b0b8e72ee07165135b23e56f43cbf4826a05a6";

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

export const syncCollectionDataAction = internalAction({
	args: {},
	handler: async (ctx) => {
		console.log("Syncing collection data from blockchain");
		const { aptos, launchpadClient } = createAptosClient();

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

				const [saleCompleted] = await launchpadClient.view.is_sale_completed({
					typeArguments: [],
					functionArguments: [collectionObject],
				});

				const [saleDeadline] = await launchpadClient.view.get_sale_deadline({
					typeArguments: [],
					functionArguments: [collectionObject],
				});

				// Query indexer for current supply
				const indexerResult = await aptos.queryIndexer({
					query: {
						query: `
							query GetCollection($collection_id: String!) {
								current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {
									current_supply
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
				};

				const currentSupply =
					collectionData.current_collections_v2[0]?.current_supply ?? collection.currentSupply;

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

				// Update collection in database
				// Always include mintStages (even if empty) to ensure it's updated
				const updateData = {
					currentSupply: Number(currentSupply),
					totalFundsCollected: Number(collectedFunds),
					saleCompleted: saleCompleted,
					saleDeadline: Number(saleDeadline),
					mintEnabled: isActive,
					mintStages: mintStages, // Always include, even if empty array
					updatedAt: Date.now(),
				};

				await ctx.runMutation(internal.collections.updateCollectionFromBlockchain, {
					collectionId: collection._id,
					updates: updateData,
				});

				console.log(
					`Synced collection ${collectionId}: ${currentSupply} minted, ${mintStages.length} stages`,
				);
			} catch (error) {
				console.error(`Error syncing collection ${collection.collectionId}:`, error);
				// Continue with other collections even if one fails
			}
		}

		return null;
	},
});
