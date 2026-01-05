import { NETWORKS } from "./lib/networks";

// biome-ignore lint/complexity/useLiteralKeys: import for convex
// biome-ignore lint/suspicious/noExplicitAny: import for convex
const env = (import.meta as any)["env"] !== undefined ? (import.meta as any)["env"] : ({} as Record<string, string>);
const NETWORK = env.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS =
	env.VITE_LAUNCHPAD_MODULE_ADDRESS || "0x6d6ae10b7105d4f38d41c19077e8c92b89dc55c4df805db0e3bc3067dd7eef81";
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
