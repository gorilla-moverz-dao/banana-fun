import type { CommittedTransactionResponse } from "@aptos-labs/ts-sdk";
import { useState } from "react";
import { toast } from "sonner";
import { aptos } from "@/lib/aptos";

export const useTransaction = ({ showError = true }: { showError?: boolean } = {}) => {
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

			return {
				tx,
				result,
			};
		} catch (err: any) {
			if (showError) {
				toast.error(err?.message || String(err));
			}
			setError(err);
			throw err;
		} finally {
			setTransactionInProgress(false);
		}
	};

	return { transactionInProgress, error, executeTransaction };
};
