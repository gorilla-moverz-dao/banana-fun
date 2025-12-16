import { useQuery } from "@tanstack/react-query";
import type { Doc } from "convex/_generated/dataModel";
import { toast } from "sonner";
import { GlassCard } from "@/components/GlassCard";
import { NFTThumbnail } from "@/components/NFTThumbnail";
import { Button } from "@/components/ui/button";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useTransaction } from "@/hooks/useTransaction";
import { vestingClient } from "@/lib/aptos";
import { faToDisplay } from "@/lib/utils";

interface MyNFTsCardProps {
	nfts: NFT[];
	collectionData: Doc<"collections">;
	onNFTClick?: (nft: NFT) => void;
	gridCols?: string;
}

export function MyNFTsCard({
	nfts,
	collectionData,
	onNFTClick,
	gridCols = "grid-cols-1 md:grid-cols-2 lg:grid-cols-4",
}: MyNFTsCardProps) {
	const { vestingClient: walletVestingClient, connected, correctNetwork } = useClients();
	const { transactionInProgress: claiming, executeTransaction } = useTransaction();

	const nftTokenIds = nfts.map((nft) => nft.token_data_id as `0x${string}`);

	// Fetch claimable amounts for all NFTs
	const {
		data: claimableAmounts,
		isLoading: isLoadingClaimable,
		refetch: refetchClaimable,
	} = useQuery({
		queryKey: ["claimable-amounts", collectionData.collectionId, nftTokenIds],
		queryFn: async () => {
			if (nftTokenIds.length === 0) return [];
			const result = await vestingClient.view.get_claimable_amount_batch({
				functionArguments: [collectionData.collectionId as `0x${string}`, nftTokenIds],
				typeArguments: [],
			});
			// Result comes as string array, convert to numbers
			return (result[0] as unknown as string[]).map((v) => Number(v));
		},
		enabled: nfts.length > 0,
		refetchInterval: 30000, // Refetch every 30 seconds
	});

	// Calculate total claimable
	const totalClaimable = claimableAmounts?.reduce((sum, amount) => sum + amount, 0) ?? 0;
	const hasClaimable = totalClaimable > 0;

	// Get NFTs that have claimable amounts
	const claimableNftIds = nftTokenIds.filter((_, index) => {
		const amount = claimableAmounts?.[index];
		return amount && amount > 0;
	});

	async function handleClaim(nftIds: `0x${string}`[], amount: number) {
		if (!walletVestingClient || nftIds.length === 0 || amount <= 0) {
			toast.error("Nothing to claim");
			return;
		}

		try {
			await executeTransaction(
				walletVestingClient.claim_batch({
					arguments: [collectionData.collectionId as `0x${string}`, nftIds],
					type_arguments: [],
				}),
			);
			toast.success(`Successfully claimed ${faToDisplay(amount).toLocaleString()} ${collectionData.faSymbol}!`);
			await refetchClaimable();
		} catch {
			// Error is handled by useTransaction
		}
	}

	if (!nfts || nfts.length === 0) {
		return null;
	}

	return (
		<GlassCard className="w-full">
			<CardHeader>
				<div className="flex items-center justify-between">
					<div>
						<CardTitle>My NFTs</CardTitle>
						<CardDescription>NFTs from this collection in your wallet</CardDescription>
					</div>
					{connected && correctNetwork && hasClaimable && (
						<div className="flex items-center gap-3">
							<div className="text-right">
								<div className="text-sm text-muted-foreground">Claimable</div>
								<div className="text-lg font-bold text-green-500">
									{isLoadingClaimable
										? "..."
										: `${faToDisplay(totalClaimable).toLocaleString()} ${collectionData.faSymbol}`}
								</div>
							</div>
							<Button
								onClick={() => handleClaim(claimableNftIds, totalClaimable)}
								disabled={claiming || !hasClaimable}
								className="bg-green-600 hover:bg-green-700"
							>
								{claiming ? "Claiming..." : "Claim All"}
							</Button>
						</div>
					)}
					{connected && correctNetwork && !hasClaimable && !isLoadingClaimable && (
						<div className="text-sm text-muted-foreground">No tokens to claim</div>
					)}
				</div>
			</CardHeader>
			<CardContent>
				<div className={`grid ${gridCols} gap-4`}>
					{nfts.map((nft, index) => {
						const nftClaimable = claimableAmounts?.[index] ?? 0;
						return (
							<div key={nft.token_data_id} className="relative">
								<NFTThumbnail
									nft={nft}
									collectionData={collectionData}
									onClick={onNFTClick ? () => onNFTClick(nft) : undefined}
								/>
								{nftClaimable > 0 && connected && correctNetwork && (
									<button
										type="button"
										onClick={(e) => {
											e.stopPropagation();
											handleClaim([nft.token_data_id as `0x${string}`], nftClaimable);
										}}
										disabled={claiming}
										className="absolute top-2 right-2 bg-green-600 hover:bg-green-700 text-white text-xs px-2 py-1 rounded-full font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
									>
										{faToDisplay(nftClaimable).toLocaleString()} {collectionData.faSymbol}
									</button>
								)}
							</div>
						);
					})}
				</div>
			</CardContent>
		</GlassCard>
	);
}
