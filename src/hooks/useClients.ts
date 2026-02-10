/** biome-ignore-all lint/correctness/useHookAtTopLevel: useABI is not a React hook */
import { useWalletClient } from "@thalalabs/surf/hooks";
import { ABI as coinABI } from "@/abi/coin";
import { ABI as launchpadABI } from "@/abi/nft_launchpad";
import { ABI as vestingABI } from "@/abi/vesting";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";
import { useMovementWallet } from "@/hooks/useMovementWallet";

export function useClients() {
	const { isInMiniApp, address, connected, sdk, sendTransaction, networkChainId } = useMovementWallet();

	// Surf wallet clients are only used in standalone (non-mini-app) mode.
	// client?.useABI is NOT a React hook – it is a method on the Surf WalletClient.
	const { client } = useWalletClient();
	const coinClient = isInMiniApp ? undefined : client?.useABI(coinABI);
	const launchpadClient = isInMiniApp
		? undefined
		: client?.useABI({ ...launchpadABI, address: LAUNCHPAD_MODULE_ADDRESS });
	const vestingClient = isInMiniApp ? undefined : client?.useABI({ ...vestingABI, address: LAUNCHPAD_MODULE_ADDRESS });

	// In mini app mode, the SDK manages the network — assume correct.
	// In standalone mode, compare chainId with the wallet adapter.
	const correctNetwork = isInMiniApp ? true : networkChainId === MOVE_NETWORK.chainId;

	return {
		isInMiniApp,
		sdk,
		sendTransaction,
		account: address ? { address } : undefined,
		connected,
		network: undefined,
		address,
		coinClient,
		launchpadClient,
		vestingClient,
		correctNetwork,
	};
}
