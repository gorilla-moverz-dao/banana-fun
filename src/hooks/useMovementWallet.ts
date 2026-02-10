import type { MovementSDK, TransactionPayload, TransactionResult } from "@movement-labs/miniapp-sdk";
import { isInMovementApp, useMovementSDK } from "@movement-labs/miniapp-sdk";
import { useWallet } from "@aptos-labs/wallet-adapter-react";

export interface MovementWalletState {
	/** Whether the app is running inside the Movement wallet */
	isInMiniApp: boolean;
	/** Connected wallet address */
	address: string | undefined;
	/** Whether a wallet is connected */
	connected: boolean;
	/** Whether the SDK/wallet is still loading */
	isLoading: boolean;
	/** The Movement SDK instance (null when not in mini app) */
	sdk: MovementSDK | null;
	/** Send a transaction via the Movement SDK (only available in mini app mode) */
	sendTransaction: ((payload: TransactionPayload) => Promise<TransactionResult | null>) | undefined;
	/** The wallet adapter's network chainId (standalone mode only) */
	networkChainId: number | undefined;
}

/**
 * Unified wallet hook that abstracts over Movement Mini App SDK and
 * the Aptos wallet adapter. When running inside the Movement wallet,
 * SDK methods are used. Otherwise, the standard wallet adapter is used.
 */
export function useMovementWallet(): MovementWalletState {
	const miniApp = isInMovementApp();
	const sdkState = useMovementSDK();
	const walletState = useWallet();

	if (miniApp) {
		return {
			isInMiniApp: true,
			address: sdkState.address ?? undefined,
			connected: sdkState.isConnected,
			isLoading: sdkState.isLoading,
			sdk: sdkState.sdk,
			sendTransaction: sdkState.sendTransaction,
			networkChainId: undefined,
		};
	}

	return {
		isInMiniApp: false,
		address: walletState.account?.address?.toString(),
		connected: walletState.connected,
		isLoading: false,
		sdk: null,
		sendTransaction: undefined,
		networkChainId: walletState.network?.chainId,
	};
}
