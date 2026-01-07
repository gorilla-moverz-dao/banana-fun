import { NETWORKS } from "./lib/networks";

// biome-ignore lint/complexity/useLiteralKeys: import for convex
// biome-ignore lint/suspicious/noExplicitAny: import for convex
const env = (import.meta as any)["env"] !== undefined ? (import.meta as any)["env"] : ({} as Record<string, string>);
const NETWORK = env.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS =
	env.VITE_LAUNCHPAD_MODULE_ADDRESS || "0x7efbe436d50826128f8f3e9feb195c7b6a79ae581ced9002b6feeaf52d8e0efa";
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
