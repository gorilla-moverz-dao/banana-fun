import { NETWORKS } from "./lib/networks";

const NETWORK = import.meta.env?.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS = "0xb94fa3d05e668dee703ddb5bc43a92ebe1e88ba0fd9823b3cb7f679ce5f7e227";
export const COLLECTION_ID = "";
export const SINGLE_COLLECTION_MODE = COLLECTION_ID.length > 0;
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
