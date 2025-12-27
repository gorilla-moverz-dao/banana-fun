"use node";

import { Account, Aptos, AptosConfig, Ed25519PrivateKey, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { ABI as launchpadABI } from "../src/abi/nft_launchpad";
import { ABI as vestingABI } from "../src/abi/vesting";
import { NETWORKS } from "../src/lib/networks";

const MOVE_NETWORK = NETWORKS.TESTNET;
const LAUNCHPAD_MODULE_ADDRESS = "0x9c4f549f56f903e59eacd92bc7531b2190b7ebf99b951999fd65d6895efd0bfc";

export function createAptosClient() {
	const config = new AptosConfig({
		network: Network.CUSTOM,
		fullnode: MOVE_NETWORK.rpcUrl,
		indexer: MOVE_NETWORK.indexerUrl,
		faucet: MOVE_NETWORK.faucetUrl,
	});

	const aptos = new Aptos(config);
	const launchpadClient = createSurfClient(aptos).useABI(launchpadABI, LAUNCHPAD_MODULE_ADDRESS);
	const vestingClient = createSurfClient(aptos).useABI(vestingABI, LAUNCHPAD_MODULE_ADDRESS);

	const privateKeyHex = process.env.APTOS_PRIVATE_KEY;
	if (!privateKeyHex) {
		throw new Error("Missing APTOS_PRIVATE_KEY environment variable");
	}

	const privateKey = new Ed25519PrivateKey(privateKeyHex);
	const account = Account.fromPrivateKey({ privateKey });

	return { aptos, launchpadClient, vestingClient, account };
}
