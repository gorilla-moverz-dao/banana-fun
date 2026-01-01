import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { ExternalLinkIcon, Images, Rocket } from "lucide-react";
import { useState } from "react";
import { AssetDetailDialog } from "@/components/AssetDetailDialog";
import { ChatCard } from "@/components/ChatCard";
import { Countdown } from "@/components/Countdown";
import { GlassCard } from "@/components/GlassCard";
import { LiveMintsCard } from "@/components/LiveMintsCard";
import { MintResultDialog } from "@/components/MintResultDialog";
import { MintStageCard } from "@/components/MintStageCard";
import { MyNFTsCard } from "@/components/MyNFTsCard";
import { NFTBrowserCard } from "@/components/NFTBrowserCard";
import { TokenInfoCard } from "@/components/TokenInfoCard";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { VestingCard } from "@/components/VestingCard";
import { MOVE_NETWORK } from "@/constants";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { useMintBalance } from "@/hooks/useMintBalance";
import { oaptToApt, toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/mint/$collectionId")({
	component: RouteComponent,
});

function RouteComponent() {
	const [showMintDialog, setShowMintDialog] = useState(false);
	const [recentlyMintedTokenIds, setRecentlyMintedTokenIds] = useState<Array<string>>([]);
	const [showAssetDetailDialog, setShowAssetDetailDialog] = useState(false);
	const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null);
	const { connected } = useClients();
	const { collectionId } = Route.useParams();

	const collectionIdTyped = collectionId as `0x${string}`;

	// Get collection data from Convex (includes stages)
	const collectionData = useQuery(api.collections.getCollection, {
		collectionId: collectionIdTyped,
	});

	// Use stages from Convex - reduction fees are calculated on-chain when needed
	const stages = collectionData?.mintStages || [];
	const isFetchedStages = collectionData !== undefined;

	const { data: mintBalance, refetch: refetchMintBalance } = useMintBalance(collectionIdTyped, stages);
	const { data: nfts, isFetched: isFetchedNFTs } = useCollectionNFTs({
		onlyOwned: true,
		collectionIds: [collectionIdTyped],
	});

	const isFetched = collectionData !== undefined && isFetchedStages;
	if (!isFetched) return <div>Loading...</div>;
	if (!collectionData) return <div>Collection not found</div>;

	const minted = collectionData.currentSupply;
	const total = collectionData.maxSupply;
	const percent = Math.round((minted / total) * 100);

	const handleNFTClick = (nft: NFT) => {
		setSelectedNFT(nft);
		setShowAssetDetailDialog(true);
	};

	// Check if vesting info is available
	const hasHolderVesting = collectionData.vestingCliff !== undefined && collectionData.vestingDuration !== undefined;
	const hasTeamVesting =
		collectionData.creatorVestingCliff !== undefined && collectionData.creatorVestingDuration !== undefined;

	const myNfts = nfts?.current_token_ownerships_v2 || [];

	return (
		<div className="flex flex-col gap-8">
			<div className="flex flex-col md:flex-row gap-8 items-start">
				{/* Left column: image, basic info, and chat */}
				<div className="w-full md:w-1/3 flex-shrink-0 space-y-4">
					<GlassCard className="w-full">
						<CardHeader>
							<div className="w-full aspect-square rounded-lg bg-background overflow-hidden border mb-2 flex items-center justify-center group">
								<img
									src={collectionData.uri}
									alt={collectionData.collectionName}
									className="object-cover w-full h-full transition-transform duration-300 ease-in-out group-hover:scale-105"
								/>
							</div>
							<CardTitle className="truncate text-lg">{collectionData.collectionName}</CardTitle>
							<CardDescription className="mb-1">{collectionData.description}</CardDescription>
						</CardHeader>
						<CardContent>
							<div className="text-sm break-all">
								<p className="font-semibold text-muted-foreground">Collection Address:</p>{" "}
								<a
									href={MOVE_NETWORK.explorerUrl.replace("{0}", `object/${collectionData.collectionId}`)}
									target="_blank"
									rel="noopener noreferrer"
								>
									<div className="flex items-center gap-1">
										{toShortAddress(collectionData.collectionId)} <ExternalLinkIcon className="w-4 h-4" />
									</div>
								</a>
							</div>
						</CardContent>
					</GlassCard>

					{/* Chat Section */}
					<ChatCard collectionId={collectionIdTyped} />
				</div>
				{/* Right column: stats + tabs */}
				<div className="flex-1 w-full space-y-6">
					{/* Progress Card */}
					<GlassCard className="w-full">
						<CardContent>
							<div className="flex items-center gap-4 mb-2">
								<span className="font-semibold text-lg">
									{minted} / {total}
								</span>
								<span className="text-sm text-muted-foreground">
									(Collected {oaptToApt(collectionData.totalFundsCollected || 0).toLocaleString()} MOVE)
								</span>
								<span className="ml-auto text-sm">{percent}%</span>
							</div>
							<Progress value={percent} className="h-3 mb-4 bg-muted/30" />

							{collectionData.saleDeadline !== undefined && !collectionData.saleCompleted && (
								<Countdown deadline={collectionData.saleDeadline} className="text-foreground/90" />
							)}
							{collectionData.saleCompleted && (
								<div className="text-green-500 text-sm font-semibold">Sale completed</div>
							)}
						</CardContent>
					</GlassCard>

					{/* Statistics Cards */}
					<div className="grid grid-cols-1 md:grid-cols-3 gap-4">
						<GlassCard className="text-center">
							<CardContent>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Minted</div>
								<div className="text-2xl font-bold">{minted?.toLocaleString() || 0}</div>
							</CardContent>
						</GlassCard>

						<GlassCard className="text-center">
							<CardContent>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Max Supply</div>
								<div className="text-2xl font-bold">{total?.toLocaleString() || 0}</div>
							</CardContent>
						</GlassCard>

						<GlassCard className="text-center">
							<CardContent>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Unique Holders</div>
								<div className="text-2xl font-bold">{collectionData.ownerCount?.toLocaleString() || 0}</div>
							</CardContent>
						</GlassCard>
					</div>

					{/* Tabs */}
					<Tabs defaultValue="mint" className="w-full">
						<TabsList className="grid w-full grid-cols-2 bg-black/20 backdrop-blur-sm mb-6">
							<TabsTrigger value="mint" className="flex items-center gap-2 data-[state=active]:bg-yellow-500/80">
								<Rocket className="w-4 h-4" />
								Mint
							</TabsTrigger>
							<TabsTrigger value="collection" className="flex items-center gap-2 data-[state=active]:bg-yellow-500/80">
								<Images className="w-4 h-4" />
								Collection
							</TabsTrigger>
						</TabsList>

						{/* Mint Tab */}
						<TabsContent value="mint" className="space-y-6 mt-0">
							{/* Hide mint stages when sale is completed by mint out */}
							{minted < total && (
								<div className="space-y-2">
									{stages.map((stage) => (
										<MintStageCard
											key={stage.name}
											stage={stage}
											collectionId={collectionIdTyped}
											mintBalance={mintBalance}
											onMintSuccess={(tokenIds) => {
												refetchMintBalance();
												setRecentlyMintedTokenIds(tokenIds);
												setShowMintDialog(true);
											}}
										/>
									))}
								</div>
							)}

							{/* Live Mints Section */}
							<LiveMintsCard collectionId={collectionIdTyped} />

							{/* Token Info Card */}
							<TokenInfoCard collectionData={collectionData} />

							{/* Vesting Information - Two Columns */}
							{(hasHolderVesting || hasTeamVesting) && (
								<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
									{hasHolderVesting && <VestingCard type="holder" collectionData={collectionData} />}

									{hasTeamVesting && <VestingCard type="team" collectionData={collectionData} />}
								</div>
							)}

							{/* My NFTs Section */}
							{connected && isFetchedNFTs && (
								<MyNFTsCard nfts={myNfts} collectionData={collectionData} onNFTClick={handleNFTClick} />
							)}
						</TabsContent>

						{/* Collection Browser Tab */}
						<TabsContent value="collection" className="space-y-4 mt-0">
							<NFTBrowserCard
								collectionId={collectionIdTyped}
								collectionData={collectionData}
								onNFTClick={handleNFTClick}
							/>
						</TabsContent>
					</Tabs>
				</div>
			</div>

			{/* Mint Success Dialog */}
			{showMintDialog && (
				<MintResultDialog
					open={showMintDialog}
					onOpenChange={setShowMintDialog}
					recentlyMintedTokenIds={recentlyMintedTokenIds}
					collectionData={collectionData}
				/>
			)}

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
