import type { CommittedTransactionResponse } from "@aptos-labs/ts-sdk";
import type { TransactionPayload } from "@movement-labs/miniapp-sdk";
import { useState } from "react";
import { toast } from "sonner";
import { aptos, waitForIndexerVersion } from "@/lib/aptos";
import { useMovementWallet } from "@/hooks/useMovementWallet";

export const useTransaction = ({
	showError = true,
	waitForIndexer = true,
}: {
	showError?: boolean;
	waitForIndexer?: boolean;
} = {}) => {
	const { isInMiniApp, sendTransaction: sdkSendTransaction } = useMovementWallet();
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
	 * Execute a transaction with automatic dual-mode support.
	 *
	 * When running inside the Movement wallet the SDK payload is submitted
	 * via `sdk.sendTransaction()`. In standalone mode the `fallback` factory
	 * is called to obtain a transaction promise from the Surf wallet client.
	 *
	 * Both paths wait for the full CommittedTransactionResponse (with events)
	 * and for the indexer to catch up.
	 *
	 * @param sdkPayload  - Transaction payload for the Movement Mini App SDK.
	 * @param fallback    - Factory that returns a Surf wallet-client promise
	 *                      (used in standalone mode; may return undefined when
	 *                      the client is not available).
	 */
	const executeTransaction = async <T extends { hash: string }>(
		sdkPayload: TransactionPayload,
		fallback?: () => Promise<T> | undefined,
	) => {
		setTransactionInProgress(true);
		setError(null);

		try {
			let tx: { hash: string };

			if (isInMiniApp && sdkSendTransaction) {
				// ---- Movement Mini App SDK mode ----
				const sdkResult = await sdkSendTransaction(sdkPayload);
				if (!sdkResult) {
					throw new Error("Transaction was not submitted");
				}
				tx = sdkResult;
			} else if (fallback) {
				// ---- Standalone wallet adapter mode ----
				const promise = fallback();
				if (!promise) {
					throw new Error("Wallet client not available");
				}
				tx = await promise;
			} else {
				throw new Error("No transaction method available");
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
