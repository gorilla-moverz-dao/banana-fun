import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { Coins, ExternalLinkIcon, Flame, Images, Rocket } from "lucide-react";
import { useState } from "react";
import { AssetDetailDialog } from "@/components/AssetDetailDialog";
import { ChatCard } from "@/components/ChatCard";
import { Countdown } from "@/components/Countdown";
import { CreatorVestingCard } from "@/components/CreatorVestingCard";
import { GlassCard } from "@/components/GlassCard";
import { type LiveMint, LiveMintsCard } from "@/components/LiveMintsCard";
import { MintResultDialog } from "@/components/MintResultDialog";
import { MintStageCard } from "@/components/MintStageCard";
import { MyNFTsCard } from "@/components/MyNFTsCard";
import { NFTBrowserCard } from "@/components/NFTBrowserCard";
import { RefundNFTsCard } from "@/components/RefundNFTsCard";
import { RefundStatsCard } from "@/components/RefundStatsCard";
import { TokenInfoCard } from "@/components/TokenInfoCard";
import { Badge } from "@/components/ui/badge";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { VestingCard } from "@/components/VestingCard";
import { MOVE_NETWORK } from "@/constants";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { type CollectionSearch, searchDefaults } from "@/hooks/useCollectionSearch";
import { useMintBalance } from "@/hooks/useMintBalance";
import { oaptToApt, toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/collections/$collectionId")({
	component: RouteComponent,
	validateSearch: (search: Record<string, unknown>): CollectionSearch => ({
		search: typeof search.search === "string" ? search.search : searchDefaults.search,
		sort:
			search.sort === "newest" || search.sort === "oldest" || search.sort === "name"
				? search.sort
				: searchDefaults.sort,
		view: search.view === "grid" || search.view === "list" ? search.view : searchDefaults.view,
		page: typeof search.page === "number" ? search.page : searchDefaults.page,
		filter:
			search.filter === "all" || search.filter === "owned" || search.filter === "available"
				? search.filter
				: searchDefaults.filter,
	}),
});

function RouteComponent() {
	const { collectionId } = Route.useParams();
	const { connected, address } = useClients();
	const [showMintDialog, setShowMintDialog] = useState(false);
	const [recentlyMintedTokenIds, setRecentlyMintedTokenIds] = useState<Array<string>>([]);
	const [showAssetDetailDialog, setShowAssetDetailDialog] = useState(false);
	const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null);

	const collectionIdTyped = collectionId as `0x${string}`;

	// Fetch collection details
	const collectionData = useQuery(api.collections.getCollection, {
		collectionId: collectionIdTyped,
	});

	const collectionLoading = collectionData === undefined;

	// Use stages from Convex
	const stages = collectionData?.mintStages || [];

	const { data: mintBalance, refetch: refetchMintBalance } = useMintBalance(collectionIdTyped, stages);

	// Fetch user's NFTs in this collection
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

	const handleLiveMintClick = (mint: LiveMint) => {
		const nftLike: NFT = {
			token_data_id: mint.nftTokenId || mint._id,
			current_token_data: {
				collection_id: collectionIdTyped,
				token_name: mint.name,
				description: mint.description,
				token_uri: mint.uri,
				token_properties: {},
			},
		};
		setSelectedNFT(nftLike);
		setShowAssetDetailDialog(true);
	};

	// Check if vesting info is available
	const hasHolderVesting = collectionData?.vestingCliff !== undefined && collectionData?.vestingDuration !== undefined;
	const hasTeamVesting =
		collectionData?.creatorVestingCliff !== undefined && collectionData?.creatorVestingDuration !== undefined;

	// Check sale status
	const now = Math.floor(Date.now() / 1000);
	const isOngoing = collectionData && !collectionData.saleCompleted && now <= collectionData.saleDeadline;
	const isFailedLaunch = collectionData && !collectionData.saleCompleted && now > collectionData.saleDeadline;
	const isSuccessful = collectionData?.saleCompleted;

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

	const minted = collectionData.currentSupply;
	const total = collectionData.maxSupply;
	const percent = Math.round((minted / total) * 100);

	// Ongoing sale view - show minting interface
	if (isOngoing) {
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
								<LiveMintsCard collectionId={collectionIdTyped} onMintClick={handleLiveMintClick} />

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
								{connected && isFetchedMyNFTs && (
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

	// Completed or Failed sale view - show vesting/refund interface
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
								{isSuccessful && <Badge className="bg-green-500/80">Completed</Badge>}
								{isFailedLaunch && <Badge variant="destructive">Failed - Refunds Available</Badge>}
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
				<TabsContent value="token" className="mt-6 space-y-6">
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
							{/* Chat + Vesting panels side by side */}
							{(hasHolderVesting || hasTeamVesting) && (
								<div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
									{/* Chat on the left */}
									<ChatCard collectionId={collectionId} />

									{/* Vesting Cards on the right */}
									<div className="space-y-6">
										{hasHolderVesting && <VestingCard type="holder" collectionData={collectionData} />}
										{hasTeamVesting && <VestingCard type="team" collectionData={collectionData} />}
									</div>
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
