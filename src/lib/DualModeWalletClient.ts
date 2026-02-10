/**
 * A wallet client that transparently routes transactions to either the
 * Movement Mini App SDK or the Aptos wallet adapter, using the same
 * Surf-style typed `useABI()` interface.
 *
 * This mirrors @thalalabs/surf's WalletClient but adds dual-mode support.
 * Components interact with this client identically to a regular Surf
 * wallet client — the routing is invisible to callers.
 */
import type { useWallet } from "@aptos-labs/wallet-adapter-react";
import type { TransactionPayload, TransactionResult } from "@movement-labs/miniapp-sdk";
import { createEntryPayload, type EntryPayload } from "@thalalabs/surf";

/**
 * Minimal ABI shape matching @thalalabs/surf's ABIRoot.
 * Defined locally because ABIRoot isn't part of Surf's public API.
 */
interface ABIRoot {
	address: string;
	name: string;
	friends: readonly string[];
	exposed_functions: readonly {
		name: string;
		visibility: "friend" | "public" | "private";
		is_entry: boolean;
		is_view: boolean;
		generic_type_params: readonly { constraints: readonly string[] }[];
		params: readonly string[];
		return: readonly string[];
	}[];
	structs: readonly {
		name: string;
		is_native: boolean;
		abilities: readonly string[];
		generic_type_params: readonly { constraints: readonly string[] }[];
		fields: readonly { name: string; type: string }[];
	}[];
}

// Re-use the wallet adapter's return type so we stay compatible
type Wallet = ReturnType<typeof useWallet>;

// SDK submit function signature (from useMovementWallet)
type SdkSubmitFn = (payload: TransactionPayload) => Promise<TransactionResult | null>;

/**
 * Dual-mode wallet client.
 *
 * Construct with *either* an SDK submit function (mini-app mode) or a
 * standard wallet adapter reference (standalone mode). The `useABI()`
 * proxy works identically in both cases.
 */
export class DualModeWalletClient {
	private wallet: Wallet | null;
	private sdkSubmit: SdkSubmitFn | null;

	constructor(wallet: Wallet | null, sdkSubmit: SdkSubmitFn | null) {
		this.wallet = wallet;
		this.sdkSubmit = sdkSubmit;
	}

	/**
	 * Submit a pre-built entry-function payload.
	 *
	 * Routes to the Movement SDK when `sdkSubmit` is available, otherwise
	 * falls back to the wallet adapter's `signAndSubmitTransaction`.
	 */
	public async submitTransaction(payload: EntryPayload): Promise<{ hash: string }> {
		if (this.sdkSubmit) {
			// ---- Movement Mini App SDK path ----
			const result = await this.sdkSubmit({
				function: payload.function,
				arguments: payload.functionArguments as unknown[],
				type_arguments: payload.typeArguments,
			});
			if (!result) {
				throw new Error("Transaction was not submitted");
			}
			return result;
		}

		if (this.wallet) {
			// ---- Standard wallet adapter path (identical to Surf's WalletClient) ----
			return await this.wallet.signAndSubmitTransaction({
				sender: this.wallet.account?.address ?? "",
				data: {
					function: payload.function,
					typeArguments: payload.typeArguments,
					// biome-ignore lint/suspicious/noExplicitAny: Surf uses the same cast internally
					functionArguments: payload.functionArguments.map((arg: any) => {
						if (Array.isArray(arg)) {
							// biome-ignore lint/suspicious/noExplicitAny: passthrough
							return arg.map((item: any) => item);
						}
						if (typeof arg === "object") {
							throw new Error(`a value of struct type: ${arg} is not supported`);
						}
						return arg;
					}),
				},
			});
		}

		throw new Error("No transaction method available");
	}

	/**
	 * Create a typed proxy for the given ABI — same interface as
	 * Surf's `WalletClient.useABI()`.
	 *
	 * Each entry function in the ABI becomes a method on the returned
	 * object.  Arguments and type-arguments are validated and encoded
	 * by Surf's `createEntryPayload`.
	 */
	// biome-ignore lint/suspicious/noExplicitAny: proxy returns dynamically typed methods matching ABIWalletClient<T>
	public useABI<T extends ABIRoot>(abi: T): any {
		// biome-ignore lint/suspicious/noExplicitAny: proxy returns dynamically typed methods
		return new Proxy({} as any, {
			get: (_, prop) => {
				const functionName = prop.toString();
				// biome-ignore lint/suspicious/noExplicitAny: generic entry-function args
				return (...args: any[]) => {
					const payload = createEntryPayload(abi, {
						function: functionName,
						typeArguments: args[0].type_arguments,
						functionArguments: args[0].arguments,
					});
					return this.submitTransaction(payload);
				};
			},
		});
	}
}
