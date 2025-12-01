import type {
	AdapterNotDetectedWallet,
	AdapterWallet,
	NetworkInfo,
	WalletSortingOptions,
} from "@aptos-labs/wallet-adapter-react";
import {
	groupAndSortWallets,
	isInstallRequired,
	truncateAddress,
	useWallet,
	WalletItem,
} from "@aptos-labs/wallet-adapter-react";
import type { Dispatch, SetStateAction } from "react";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { MOVE_NETWORK } from "@/constants";

interface WalletSelectorProps extends WalletSortingOptions {
	isModalOpen?: boolean;
	setModalOpen?: Dispatch<SetStateAction<boolean>>;
}

export function WalletSelector({ isModalOpen, setModalOpen, ...walletSortingOptions }: WalletSelectorProps) {
	const [walletSelectorModalOpen, setWalletSelectorModalOpen] = useState(false);
	useEffect(() => {
		// If the component is being used as a controlled component,
		// sync the external and internal modal state.
		if (isModalOpen !== undefined) {
			setWalletSelectorModalOpen(isModalOpen);
		}
	}, [isModalOpen]);

	const { account, connected, disconnect, wallets = [], network, wallet } = useWallet();

	const { availableWallets } = groupAndSortWallets(wallets, walletSortingOptions);
	const installableWallets = [] as Array<AdapterWallet>;

	const onWalletButtonClick = () => {
		if (connected) {
			disconnect();
		} else {
			setWalletSelectorModalOpen(true);
		}
	};

	const handleWrongNetworkClick = () => {
		toast.error(`Please switch to ${MOVE_NETWORK.name} in your wallet`);
		wallet?.features["aptos:changeNetwork"]?.changeNetwork({
			...MOVE_NETWORK,
			name: "custom",
		} as NetworkInfo);
	};

	const closeModal = () => {
		setWalletSelectorModalOpen(false);
		if (setModalOpen) {
			setModalOpen(false);
		}
	};

	const buttonText = account?.ansName || truncateAddress(account?.address.toString() ?? "") || "Unknown";

	if (network && MOVE_NETWORK.chainId !== network.chainId) {
		return (
			<Button variant="destructive" className="wallet-button" onClick={handleWrongNetworkClick}>
				Switch to {MOVE_NETWORK.name}
			</Button>
		);
	}

	return (
		<>
			<Button variant="default" className="wallet-button" onClick={onWalletButtonClick}>
				{connected ? buttonText : "Connect Wallet"}
			</Button>

			<Dialog open={walletSelectorModalOpen} onOpenChange={setWalletSelectorModalOpen}>
				<DialogContent className="max-w-sm">
					<DialogHeader>
						<DialogTitle>{connected ? buttonText : "Connect Wallet"}</DialogTitle>
					</DialogHeader>

					{!connected && (
						<>
							<div className="flex flex-col gap-3">
								{availableWallets.length === 0 && (
									<div className="text-center text-base-content/80">No compatible wallets found</div>
								)}
								{availableWallets.map((availableWallet) => (
									<WalletRow key={availableWallet.name} wallet={availableWallet} onConnect={closeModal} />
								))}
							</div>

							{!!installableWallets.length && (
								<div className="collapse collapse-arrow">
									<input type="checkbox" />
									<div className="collapse-title">More Wallets</div>
									<div className="collapse-content">
										<div className="flex flex-col gap-3">
											{installableWallets.map((installableWallet) => (
												<WalletRow key={installableWallet.name} wallet={installableWallet} onConnect={closeModal} />
											))}
										</div>
									</div>
								</div>
							)}
						</>
					)}
				</DialogContent>
			</Dialog>
		</>
	);
}

// Using any here because the wallet adapter types are not properly exported
interface WalletRowProps {
	wallet: AdapterWallet | AdapterNotDetectedWallet;
	onConnect?: () => void;
}

function WalletRow({ wallet, onConnect }: WalletRowProps) {
	return (
		<WalletItem wallet={wallet} onConnect={onConnect} asChild>
			<div className="flex items-center justify-between p-2 rounded-lg wallet-menu-wrapper">
				<div className="flex items-center gap-2 wallet-name-wrapper">
					<WalletItem.Icon className="wallet-selector-icon w-10 h-10" />
					<WalletItem.Name asChild>
						<span className="wallet-selector-text">{wallet.name}</span>
					</WalletItem.Name>
				</div>
				{isInstallRequired(wallet) ? (
					<WalletItem.InstallLink className="btn btn-sm btn-outline wallet-connect-install" />
				) : (
					<WalletItem.ConnectButton asChild>
						<Button variant="outline" size="sm" className="wallet-connect-button">
							Connect
						</Button>
					</WalletItem.ConnectButton>
				)}
			</div>
		</WalletItem>
	);
}
