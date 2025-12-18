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

	const executeTransaction = async <T extends { hash: string }>(transaction: Promise<T>) => {
		setTransactionInProgress(true);
		setError(null);
		let tx: T;
		let result: CommittedTransactionResponse;
		try {
			tx = await transaction;
			result = await aptos.waitForTransaction({ transactionHash: tx.hash });

			// We wait for the indexer to catch up to the version of the transaction
			if (waitForIndexer) {
				console.log("Waiting for indexer version:", result.version);
				try {
					await waitForIndexerVersion(result.version, { maxWaitTimeMs: 30000, pollIntervalMs: 1000 });
				} catch (error) {
					console.warn("Failed to wait for indexer version, proceeding with query:", error);
				}
			}

			return {
				tx,
				result,
			};
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
