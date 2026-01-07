import type { Aptos } from "@aptos-labs/ts-sdk";

/**
 * Wait for the indexer to process up to a specific ledger version.
 * This is useful after submitting a transaction to ensure the indexer has caught up
 * before querying for data that depends on that transaction.
 *
 * @param aptos - The Aptos client instance
 * @param minLedgerVersion - The minimum ledger version to wait for (as string or bigint)
 * @param options - Optional configuration
 * @param options.maxWaitTimeMs - Maximum time to wait in milliseconds (default: 30000)
 * @param options.pollIntervalMs - How often to check the indexer version (default: 1000)
 * @returns Promise that resolves when the indexer has reached the specified version
 */
export const waitForIndexerVersion = async (
	aptos: Aptos,
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

