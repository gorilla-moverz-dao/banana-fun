"use node";

import { Account, Aptos, AptosConfig, Ed25519PrivateKey, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { ABI as launchpadABI } from "../src/abi/nft_launchpad";
import { ABI as vestingABI } from "../src/abi/vesting";
import { NETWORKS } from "../src/lib/networks";

const MOVE_NETWORK = NETWORKS.TESTNET;
const LAUNCHPAD_MODULE_ADDRESS = "0x87af4d7e941f0a3850caa7fa7ff9e3f986dc096f1b899006c071f60851f57263";

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
