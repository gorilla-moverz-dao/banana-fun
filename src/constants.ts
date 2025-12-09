import { NETWORKS } from "./lib/networks";

const NETWORK = import.meta?.env?.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS = "0x598db4c36c6aceb951c79fca46b0b8e72ee07165135b23e56f43cbf4826a05a6";
export const COLLECTION_ID = "";
export const SINGLE_COLLECTION_MODE = COLLECTION_ID.length > 0;
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
