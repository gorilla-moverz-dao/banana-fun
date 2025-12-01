import type { AvailableWallets } from "@aptos-labs/wallet-adapter-react";
import { AptosWalletAdapterProvider } from "@aptos-labs/wallet-adapter-react";
import type { PropsWithChildren } from "react";

export const WalletProvider = ({ children }: PropsWithChildren) => {
	return (
		<AptosWalletAdapterProvider
			autoConnect={true}
			optInWallets={[
				"Nightly",
				"Razor Wallet" as AvailableWallets,
				"Leap Wallet" as AvailableWallets,
			]}
			onError={(error) => {
				console.log("error", error);
			}}
		>
			{children}
		</AptosWalletAdapterProvider>
	);
};
