import { useQuery } from "@tanstack/react-query";
import type { Doc } from "convex/_generated/dataModel";
import { AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { GlassCard } from "@/components/GlassCard";
import { NFTThumbnail } from "@/components/NFTThumbnail";
import { Button } from "@/components/ui/button";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useTransaction } from "@/hooks/useTransaction";
import { launchpadClient } from "@/lib/aptos";
import { oaptToApt } from "@/lib/utils";

interface RefundNFTsCardProps {
	nfts: NFT[];
	collectionData: Doc<"collections">;
	onRefundSuccess?: () => void;
}

export function RefundNFTsCard({ nfts, collectionData, onRefundSuccess }: RefundNFTsCardProps) {
	const { launchpadClient: walletLaunchpadClient, connected, correctNetwork } = useClients();
	const { transactionInProgress: refunding, executeTransaction } = useTransaction();

	const nftTokenIds = nfts.map((nft) => nft.token_data_id as `0x${string}`);

	// Fetch refund amounts for all NFTs
	const {
		data: refundAmounts,
		isLoading: isLoadingRefunds,
		refetch: refetchRefunds,
	} = useQuery({
		queryKey: ["refund-amounts", collectionData.collectionId, nftTokenIds],
		queryFn: async () => {
			if (nftTokenIds.length === 0) return [];
			const amounts: number[] = [];
			for (const tokenId of nftTokenIds) {
				try {
					const result = await launchpadClient.view.get_nft_refund_amount({
						functionArguments: [tokenId],
						typeArguments: [],
					});
					amounts.push(Number(result[0]));
				} catch {
					amounts.push(0);
				}
			}
			return amounts;
		},
		enabled: nfts.length > 0,
	});

	// Calculate total refundable
	const totalRefundable = refundAmounts?.reduce((sum, amount) => sum + amount, 0) ?? 0;
	const hasRefundable = totalRefundable > 0;

	async function handleRefund(nftTokenId: `0x${string}`, refundAmount: number) {
		if (!walletLaunchpadClient || refundAmount <= 0) {
			toast.error("Nothing to refund");
			return;
		}

		try {
			await executeTransaction(
				walletLaunchpadClient.reclaim_funds({
					arguments: [collectionData.collectionId as `0x${string}`, nftTokenId],
					type_arguments: [],
				}),
			);
			toast.success(`Successfully refunded ${oaptToApt(refundAmount).toLocaleString()} MOVE!`);
			await refetchRefunds();
			onRefundSuccess?.();
		} catch {
			// Error is handled by useTransaction
		}
	}

	if (!nfts || nfts.length === 0) {
		return null;
	}

	return (
		<GlassCard className="w-full border-red-500/30">
			<CardHeader>
				<div className="flex items-center justify-between">
					<div className="flex items-center gap-2">
						<AlertTriangle className="w-5 h-5 text-red-400" />
						<div>
							<CardTitle className="text-red-400">Failed Launch - Refund Available</CardTitle>
							<CardDescription>This launch did not reach its target. Burn your NFTs to get a refund.</CardDescription>
						</div>
					</div>
					{connected && correctNetwork && hasRefundable && (
						<div className="text-right">
							<div className="text-sm text-muted-foreground">Total Refundable</div>
							<div className="text-lg font-bold text-red-400">
								{isLoadingRefunds ? "..." : `${oaptToApt(totalRefundable).toLocaleString()} MOVE`}
							</div>
						</div>
					)}
				</div>
			</CardHeader>
			<CardContent>
				<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
					{nfts.map((nft, index) => {
						const nftRefundable = refundAmounts?.[index] ?? 0;
						return (
							<div key={nft.token_data_id} className="relative">
								<NFTThumbnail nft={nft} collectionData={collectionData} />
								{nftRefundable > 0 && connected && correctNetwork && (
									<div className="absolute inset-0 flex flex-col items-center justify-center bg-black/70 rounded-lg">
										<div className="text-white text-sm font-medium mb-2">
											{oaptToApt(nftRefundable).toLocaleString()} MOVE
										</div>
										<Button
											size="sm"
											variant="destructive"
											onClick={(e) => {
												e.stopPropagation();
												handleRefund(nft.token_data_id as `0x${string}`, nftRefundable);
											}}
											disabled={refunding}
										>
											{refunding ? "Refunding..." : "Burn & Refund"}
										</Button>
									</div>
								)}
								{nftRefundable === 0 && !isLoadingRefunds && (
									<div className="absolute inset-0 flex items-center justify-center bg-black/70 rounded-lg">
										<div className="text-muted-foreground text-sm">No refund available</div>
									</div>
								)}
							</div>
						);
					})}
				</div>
			</CardContent>
		</GlassCard>
	);
}
