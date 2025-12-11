import { NETWORKS } from "./lib/networks";

const NETWORK = import.meta?.env?.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS = "0x400b0f8d7c011756381fb473b432d46eed94f7cc47db3ef93b76ccd76a72ed8e";
export const COLLECTION_ID = "";
export const SINGLE_COLLECTION_MODE = COLLECTION_ID.length > 0;
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
