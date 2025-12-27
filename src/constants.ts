import { NETWORKS } from "./lib/networks";

const NETWORK = import.meta.env !== undefined ? import.meta.env?.VITE_NETWORK || "TESTNET" : "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS = "0x9c4f549f56f903e59eacd92bc7531b2190b7ebf99b951999fd65d6895efd0bfc";
export const COLLECTION_ID = "";
export const SINGLE_COLLECTION_MODE = COLLECTION_ID.length > 0;
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
