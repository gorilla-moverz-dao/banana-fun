/** biome-ignore-all lint/correctness/useHookAtTopLevel: It's not a hook */
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { ABI as launchpadABI } from "@/abi/nft_launchpad";
import { ABI as nftReductionManagerABI } from "@/abi/nft_reduction_manager";
import { ABI as vestingABI } from "@/abi/vesting";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";
import { waitForIndexerVersion as waitForIndexerVersionBase } from "./aptos-utils";

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
 * Convenience wrapper that uses the module-level aptos client.
 *
 * @param minLedgerVersion - The minimum ledger version to wait for (as string or bigint)
 * @param options - Optional configuration
 * @returns Promise that resolves when the indexer has reached the specified version
 */
export const waitForIndexerVersion = (
	minLedgerVersion: string | bigint,
	options?: { maxWaitTimeMs?: number; pollIntervalMs?: number },
): Promise<void> => waitForIndexerVersionBase(aptos, minLedgerVersion, options);
