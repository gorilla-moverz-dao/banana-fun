import { NETWORKS } from "./lib/networks";

const NETWORK = import.meta.env !== undefined ? import.meta.env?.VITE_NETWORK || "TESTNET" : "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS = "0x87af4d7e941f0a3850caa7fa7ff9e3f986dc096f1b899006c071f60851f57263";
export const COLLECTION_ID = "";
export const SINGLE_COLLECTION_MODE = COLLECTION_ID.length > 0;
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
