import type { CommittedTransactionResponse } from "@aptos-labs/ts-sdk";
import { useState } from "react";
import { toast } from "sonner";
import { aptos, waitForIndexerVersion } from "@/lib/aptos";

export const useTransaction = ({
	showError = true,
	waitForIndexer = true,
}: {
	showError?: boolean;
	waitForIndexer?: boolean;
} = {}) => {
	const [transactionInProgress, setTransactionInProgress] = useState(false);
	const [error, setError] = useState<Error | null>(null);

	/**
	 * Wait for the transaction to be committed on-chain and optionally wait
	 * for the indexer to catch up. Returns the full CommittedTransactionResponse
	 * (which includes events).
	 */
	const waitAndFinalize = async (hash: string): Promise<CommittedTransactionResponse> => {
		const result = await aptos.waitForTransaction({ transactionHash: hash });

		if (waitForIndexer) {
			console.log("Waiting for indexer version:", result.version);
			try {
				await waitForIndexerVersion(result.version, { maxWaitTimeMs: 30000, pollIntervalMs: 1000 });
			} catch (error) {
				console.warn("Failed to wait for indexer version, proceeding with query:", error);
			}
		}

		return result;
	};

	/**
	 * Execute a transaction via the dual-mode wallet client.
	 *
	 * Accepts a factory function that returns a transaction promise from a
	 * Surf-style ABI client (e.g. `() => launchpadClient?.mint_nft({...})`).
	 * The factory may return `undefined` when the client is not yet available.
	 *
	 * The `DualModeWalletClient` transparently routes to the Movement SDK
	 * or the wallet adapter — callers don't need to know which mode is active.
	 */
	const executeTransaction = async <T extends { hash: string }>(transaction: () => Promise<T> | undefined) => {
		setTransactionInProgress(true);
		setError(null);

		try {
			const promise = transaction();
			if (!promise) {
				throw new Error("Wallet client not available");
			}
			const tx = await promise;
			console.error("TX:", tx);

			if (!tx.hash) {
				throw new Error("Transaction hash is required");
			}

			const result = await waitAndFinalize(tx.hash);

			return { tx, result };
		} catch (err) {
			const error = err as Error;
			if (showError) {
				toast.error(error.message || String(error));
			}
			setError(error);
			throw error;
		} finally {
			setTransactionInProgress(false);
		}
	};

	return { transactionInProgress, error, executeTransaction };
};
