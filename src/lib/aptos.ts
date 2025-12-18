/** biome-ignore-all lint/correctness/useHookAtTopLevel: It's not a hook */
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { ABI as launchpadABI } from "@/abi/nft_launchpad";
import { ABI as nftReductionManagerABI } from "@/abi/nft_reduction_manager";
import { ABI as vestingABI } from "@/abi/vesting";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";

// Network configuration
const config = new AptosConfig({
	network: Network.CUSTOM,
	fullnode: MOVE_NETWORK.rpcUrl,
	indexer: MOVE_NETWORK.indexerUrl,
	faucet: MOVE_NETWORK.faucetUrl,
});

// Initialize client
export const aptos = new Aptos(config);
export const launchpadClient = createSurfClient(aptos).useABI(launchpadABI, LAUNCHPAD_MODULE_ADDRESS);
export const vestingClient = createSurfClient(aptos).useABI(vestingABI, LAUNCHPAD_MODULE_ADDRESS);
export const nftReductionManagerClient = createSurfClient(aptos).useABI(
	nftReductionManagerABI,
	LAUNCHPAD_MODULE_ADDRESS,
);

// Helper function to get account balance
export const getAccountBalance = async (address: string) => {
	const resources = await aptos.getAccountAPTAmount({
		accountAddress: address,
	});
	return resources ? BigInt(resources.toString()) : BigInt(0);
};

/**
 * Wait for the indexer to process up to a specific ledger version.
 * This is useful after submitting a transaction to ensure the indexer has caught up
 * before querying for data that depends on that transaction.
 *
 * @param minLedgerVersion - The minimum ledger version to wait for (as string or bigint)
 * @param options - Optional configuration
 * @param options.maxWaitTimeMs - Maximum time to wait in milliseconds (default: 30000)
 * @param options.pollIntervalMs - How often to check the indexer version (default: 1000)
 * @returns Promise that resolves when the indexer has reached the specified version
 */
export const waitForIndexerVersion = async (
	minLedgerVersion: string | bigint,
	options: { maxWaitTimeMs?: number; pollIntervalMs?: number } = {},
): Promise<void> => {
	const { maxWaitTimeMs = 30000, pollIntervalMs = 1000 } = options;
	const targetVersion = BigInt(minLedgerVersion);
	const startTime = Date.now();

	while (Date.now() - startTime < maxWaitTimeMs) {
		try {
			const lastSuccessVersion = await aptos.getIndexerLastSuccessVersion();
			if (lastSuccessVersion >= targetVersion) {
				return;
			}
			// Wait before polling again
			await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
		} catch {
			// If there's an error getting the version, wait and retry
			await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
		}
	}

	throw new Error(
		`Timeout waiting for indexer to reach version ${minLedgerVersion}. Indexer may be slow or unavailable.`,
	);
};
