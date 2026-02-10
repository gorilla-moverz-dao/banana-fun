import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { ABI as coinABI } from "@/abi/coin";
import { ABI as launchpadABI } from "@/abi/nft_launchpad";
import { ABI as vestingABI } from "@/abi/vesting";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";
import { useMovementWallet } from "@/hooks/useMovementWallet";
import { DualModeWalletClient } from "@/lib/DualModeWalletClient";

export function useClients() {
	const { isInMiniApp, address, connected, sendTransaction: sdkSendTransaction, networkChainId } = useMovementWallet();
	const wallet = useWallet();

	// Create a dual-mode client that transparently routes to either
	// the Movement SDK or the wallet adapter.
	const client =
		isInMiniApp && sdkSendTransaction
			? new DualModeWalletClient(null, sdkSendTransaction)
			: wallet.connected
				? new DualModeWalletClient(wallet, null)
				: undefined;

	// Typed ABI clients — work identically in both modes.
	// NOTE: useABI is NOT a React hook; it is a method that returns a Proxy.
	const coinClient = client?.useABI(coinABI);
	const launchpadClient = client?.useABI({ ...launchpadABI, address: LAUNCHPAD_MODULE_ADDRESS });
	const vestingClient = client?.useABI({ ...vestingABI, address: LAUNCHPAD_MODULE_ADDRESS });

	// In mini app mode the SDK manages the network — assume correct.
	// In standalone mode compare chainId with the wallet adapter.
	const correctNetwork = isInMiniApp ? true : networkChainId === MOVE_NETWORK.chainId;

	return {
		account: address ? { address } : undefined,
		connected,
		address,
		coinClient,
		launchpadClient,
		vestingClient,
		correctNetwork,
	};
}
