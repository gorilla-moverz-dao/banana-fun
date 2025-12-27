import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { Coins, ExternalLinkIcon, Flame, Images } from "lucide-react";
import { useState } from "react";
import { AssetDetailDialog } from "@/components/AssetDetailDialog";
import { CreatorVestingCard } from "@/components/CreatorVestingCard";
import { GlassCard } from "@/components/GlassCard";
import { MyNFTsCard } from "@/components/MyNFTsCard";
import { NFTBrowserCard } from "@/components/NFTBrowserCard";
import { RefundNFTsCard } from "@/components/RefundNFTsCard";
import { RefundStatsCard } from "@/components/RefundStatsCard";
import { TokenInfoCard } from "@/components/TokenInfoCard";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { VestingCard } from "@/components/VestingCard";
import { MOVE_NETWORK } from "@/constants";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/collections/$collectionId")({
	component: RouteComponent,
});

function RouteComponent() {
	const { collectionId } = Route.useParams();
	const { connected, address } = useClients();
	const [showAssetDetailDialog, setShowAssetDetailDialog] = useState(false);
	const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null);

	// Fetch collection details
	const collectionData = useQuery(api.collections.getCollection, {
		collectionId: collectionId as `0x${string}`,
	});

	const collectionLoading = collectionData === undefined;

	// Fetch user's NFTs in this collection (for My NFTs section)
	const {
		data: myNftsData,
		isFetched: isFetchedMyNFTs,
		refetch: refetchMyNFTs,
	} = useCollectionNFTs({
		onlyOwned: true,
		collectionIds: [collectionId],
	});

	const myNfts = myNftsData?.current_token_ownerships_v2 || [];

	const handleNFTClick = (nft: NFT) => {
		setSelectedNFT(nft);
		setShowAssetDetailDialog(true);
	};

	// Check if vesting info is available
	const hasHolderVesting = collectionData?.vestingCliff !== undefined && collectionData?.vestingDuration !== undefined;
	const hasTeamVesting =
		collectionData?.creatorVestingCliff !== undefined && collectionData?.creatorVestingDuration !== undefined;

	// Check if this is a failed launch (deadline passed but not completed)
	const now = Math.floor(Date.now() / 1000);
	const isFailedLaunch = collectionData && !collectionData.saleCompleted && now > collectionData.saleDeadline;

	// Check if current user is the creator vesting beneficiary
	const isCreatorVestingBeneficiary =
		collectionData?.saleCompleted &&
		address &&
		collectionData.creatorVestingWalletAddress?.toLowerCase() === address.toLowerCase();

	if (collectionLoading) {
		return (
			<div className="flex items-center justify-center min-h-[400px]">
				<div className="text-lg">Loading collection...</div>
			</div>
		);
	}

	if (!collectionData) {
		return (
			<div className="flex items-center justify-center min-h-[400px]">
				<div className="text-lg text-destructive">Collection not found</div>
			</div>
		);
	}

	return (
		<div className="space-y-6">
			{/* Collection Header + Token Info - Two Columns */}
			<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
				{/* Collection Header */}
				<GlassCard className="p-3">
					<div className="flex items-start gap-6 sm:flex-row flex-col">
						<div className="w-24 h-24 flex-shrink-0 rounded-lg overflow-hidden border border-white/20">
							<img
								src={collectionData.uri}
								alt={collectionData.collectionName}
								className="w-full h-full object-cover"
								onError={(e) => {
									e.currentTarget.src = "/images/favicon-1.png";
								}}
							/>
						</div>
						<div className="flex-1 space-y-3">
							<div>
								<h1 className="text-2xl font-bold text-shadow-lg">{collectionData.collectionName}</h1>
								<p className="text-muted-foreground mt-1 text-sm">{collectionData.description}</p>
							</div>
							<div className="flex flex-wrap gap-2">
								<Badge variant="secondary">
									{collectionData.currentSupply} / {collectionData.maxSupply || "∞"} minted
								</Badge>
								<a
									href={MOVE_NETWORK.explorerUrl.replace("{0}", `object/${collectionData.collectionId}`)}
									target="_blank"
									rel="noopener noreferrer"
								>
									<Badge variant="outline">
										<div className="flex items-center gap-1 p-1">
											Collection: {toShortAddress(collectionData.collectionId)} <ExternalLinkIcon className="w-4 h-4" />
										</div>
									</Badge>
								</a>
							</div>
						</div>
					</div>
				</GlassCard>

				{/* Token Info Card */}
				<TokenInfoCard collectionData={collectionData} />
			</div>

			{/* Tabs */}
			<Tabs defaultValue="token" className="w-full">
				<TabsList className="grid w-full grid-cols-2 bg-black/20 backdrop-blur-sm">
					<TabsTrigger value="token" className="flex items-center gap-2 data-[state=active]:bg-yellow-500/80">
						{isFailedLaunch ? <Flame className="w-4 h-4" /> : <Coins className="w-4 h-4" />}
						{isFailedLaunch ? "Refund" : "Vesting"}
					</TabsTrigger>
					<TabsTrigger value="collection" className="flex items-center gap-2 data-[state=active]:bg-yellow-500/80">
						<Images className="w-4 h-4" />
						Collection
					</TabsTrigger>
				</TabsList>

				{/* Vesting Tab */}
				<TabsContent value="token" className="space-y-6 mt-6">
					{/* For failed launches: Show refund stats instead of vesting cards */}
					{isFailedLaunch ? (
						<>
							{/* Refund Stats Card */}
							<RefundStatsCard collectionData={collectionData} />

							{/* User's NFTs for refund */}
							{connected && isFetchedMyNFTs && myNfts.length > 0 && (
								<RefundNFTsCard
									nfts={myNfts}
									collectionData={collectionData}
									onRefundSuccess={() => {
										refetchMyNFTs();
									}}
								/>
							)}
						</>
					) : (
						<>
							{/* Vesting Cards - Side by side on larger screens */}
							{(hasHolderVesting || hasTeamVesting) && (
								<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
									{hasHolderVesting && <VestingCard type="holder" collectionData={collectionData} />}
									{hasTeamVesting && <VestingCard type="team" collectionData={collectionData} />}
								</div>
							)}

							{/* Creator Vesting Card - Show when user is the dev wallet and sale is completed */}
							{isCreatorVestingBeneficiary && <CreatorVestingCard collectionData={collectionData} />}

							{/* My NFTs Card - Show claim card for successful sales */}
							{connected && isFetchedMyNFTs && myNfts.length > 0 && (
								<MyNFTsCard
									nfts={myNfts}
									collectionData={collectionData}
									onNFTClick={handleNFTClick}
									gridCols="grid-cols-2 md:grid-cols-4 lg:grid-cols-6"
								/>
							)}
						</>
					)}
				</TabsContent>

				{/* Collection Browser Tab */}
				<TabsContent value="collection" className="space-y-4 mt-6">
					<NFTBrowserCard collectionId={collectionId} collectionData={collectionData} onNFTClick={handleNFTClick} />
				</TabsContent>
			</Tabs>

			{/* Asset Detail Dialog */}
			<AssetDetailDialog
				open={showAssetDetailDialog}
				onOpenChange={setShowAssetDetailDialog}
				nft={selectedNFT}
				collectionData={collectionData}
			/>
		</div>
	);
}
