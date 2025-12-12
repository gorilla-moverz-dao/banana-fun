"use node";

import { Account, Aptos, AptosConfig, Ed25519PrivateKey, Network } from "@aptos-labs/ts-sdk";
import { createSurfClient } from "@thalalabs/surf";
import { ABI as launchpadABI } from "../src/abi/nft_launchpad";
import { NETWORKS } from "../src/lib/networks";

const MOVE_NETWORK = NETWORKS.TESTNET;
const LAUNCHPAD_MODULE_ADDRESS = "0x400b0f8d7c011756381fb473b432d46eed94f7cc47db3ef93b76ccd76a72ed8e";

export function createAptosClient() {
	const config = new AptosConfig({
		network: Network.CUSTOM,
		fullnode: MOVE_NETWORK.rpcUrl,
		indexer: MOVE_NETWORK.indexerUrl,
		faucet: MOVE_NETWORK.faucetUrl,
	});

	const aptos = new Aptos(config);
	const launchpadClient = createSurfClient(aptos).useABI(launchpadABI, LAUNCHPAD_MODULE_ADDRESS);

	const privateKeyHex = process.env.APTOS_PRIVATE_KEY;
	if (!privateKeyHex) {
		throw new Error("Missing APTOS_PRIVATE_KEY environment variable");
	}

	const privateKey = new Ed25519PrivateKey(privateKeyHex);
	const account = Account.fromPrivateKey({ privateKey });

	return { aptos, launchpadClient, account };
}
