import { NETWORKS } from "./lib/networks";

// biome-ignore lint/complexity/useLiteralKeys: import for convex
// biome-ignore lint/suspicious/noExplicitAny: import for convex
const env = (import.meta as any)["env"] !== undefined ? (import.meta as any)["env"] : ({} as Record<string, string>);
const NETWORK = env.VITE_NETWORK || "TESTNET";

export const LAUNCHPAD_MODULE_ADDRESS =
	env.VITE_LAUNCHPAD_MODULE_ADDRESS || "0x9c4f549f56f903e59eacd92bc7531b2190b7ebf99b951999fd65d6895efd0bfc";
export const MOVE_NETWORK = NETWORKS[NETWORK as keyof typeof NETWORKS];
