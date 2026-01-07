import { NETWORKS } from "./lib/networks";

// biome-ignore lint/complexity/useLiteralKeys: import for convex
// biome-ignore lint/suspicious/noExplicitAny: import for convex
const env = (import.meta as any)["env"] !== undefined ? (import.meta as any)["env"] : ({} as Record<string, string>);
const NETWORK = env.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS =
	env.VITE_LAUNCHPAD_MODULE_ADDRESS || "0xd1a5066497af131a89e982bf6eec6c60be9fa18296367e5ccd95b72b55b23dfa";
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
