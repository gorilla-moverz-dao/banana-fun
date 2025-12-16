import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useWalletClient } from "@thalalabs/surf/hooks";
import { ABI as coinABI } from "@/abi/coin";
import { ABI as launchpadABI } from "@/abi/nft_launchpad";
import { ABI as vestingABI } from "@/abi/vesting";
import { LAUNCHPAD_MODULE_ADDRESS, MOVE_NETWORK } from "@/constants";

export function useClients() {
	const { client } = useWalletClient();
	const { account, connected, network } = useWallet();

	const coinClient = client?.useABI(coinABI);
	const launchpadClient = client?.useABI({ ...launchpadABI, address: LAUNCHPAD_MODULE_ADDRESS });
	const vestingClient = client?.useABI({ ...vestingABI, address: LAUNCHPAD_MODULE_ADDRESS });

	const correctNetwork = network?.chainId === MOVE_NETWORK.chainId;

	return {
		account,
		connected,
		network,
		address: account?.address.toString(),
		coinClient,
		launchpadClient,
		vestingClient,
		correctNetwork,
	};
}
