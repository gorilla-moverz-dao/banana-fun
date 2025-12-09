import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { ExternalLinkIcon } from "lucide-react";
import { useState } from "react";
import { AssetDetailDialog } from "@/components/AssetDetailDialog";
import { GlassCard } from "@/components/GlassCard";
import { MintResultDialog } from "@/components/MintResultDialog";
import { MintStageCard } from "@/components/MintStageCard";
import { NFTThumbnail } from "@/components/NFTThumbnail";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
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
	const stages = collectionData?.stages || [];
	const isFetchedStages = collectionData !== undefined;

	const { data: mintBalance, isFetched: isFetchedMintBalance } = useMintBalance(collectionIdTyped, stages);
	const { data: nfts, isFetched: isFetchedNFTs } = useCollectionNFTs({
		onlyOwned: true,
		collectionIds: [collectionIdTyped],
	});

	const isFetched = collectionData !== undefined && isFetchedStages && isFetchedMintBalance;
	if (!isFetched) return <div>Loading...</div>;
	if (!collectionData) return <div>Collection not found</div>;

	const minted = collectionData.current_supply;
	const total = collectionData.max_supply;
	const percent = Math.round((minted / total) * 100);

	const handleNFTClick = (nft: NFT) => {
		setSelectedNFT(nft);
		setShowAssetDetailDialog(true);
	};

	return (
		<div className="flex flex-col gap-8">
			<div className="flex flex-col md:flex-row gap-8 items-start">
				{/* Left column: image and basic info */}
				<div className="w-full md:w-1/3 flex-shrink-0 md:sticky md:top-16 md:self-start">
					<GlassCard className="w-full">
						<CardHeader>
							<div className="w-full aspect-square rounded-lg bg-background overflow-hidden border mb-2 flex items-center justify-center group">
								<img
									src={collectionData.uri}
									alt={collectionData.collection_name}
									className="object-cover w-full h-full transition-transform duration-300 ease-in-out group-hover:scale-105"
								/>
							</div>
							<CardTitle className="truncate text-lg">{collectionData.collection_name}</CardTitle>
							<CardDescription className="mb-1">{collectionData.description}</CardDescription>
						</CardHeader>
						<CardContent>
							<div className="text-sm break-all">
								<p className="font-semibold text-muted-foreground">Collection Address:</p>{" "}
								<a
									href={MOVE_NETWORK.explorerUrl.replace("{0}", `object/${collectionData.collection_id}`)}
									target="_blank"
									rel="noopener noreferrer"
								>
									<div className="flex items-center gap-1">
										{toShortAddress(collectionData.collection_id)} <ExternalLinkIcon className="w-4 h-4" />
									</div>
								</a>
							</div>
						</CardContent>
					</GlassCard>
				</div>
				{/* Right column: progress, stages, mint actions */}
				<div className="flex-1 w-full space-y-6">
					<GlassCard className="w-full">
						<CardContent>
							<div className="flex items-center gap-4 mb-2">
								<span className="font-semibold text-lg">
									{minted} / {total}
								</span>
								<span className="text-sm text-muted-foreground">
									(Collected {oaptToApt(collectionData.total_funds_collected || 0).toLocaleString()} MOVE)
								</span>
								<span className="ml-auto text-sm">{percent}%</span>
							</div>
							<Progress value={percent} className="h-3 mb-4 bg-muted/30" />
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
								<div className="text-2xl font-bold">{collectionData.ownerCount.toLocaleString() || 0}</div>
							</CardContent>
						</GlassCard>
					</div>

					<GlassCard className="w-full">
						<CardContent>
							<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
								{/* Left Column: Icon and Symbol */}
								<div className="flex items-start gap-4">
									<div className="w-16 h-16 rounded-lg overflow-hidden border border-white/20 flex-shrink-0">
										<img
											src={collectionData.fa_icon_uri}
											alt={collectionData.fa_name || "FA Icon"}
											className="w-full h-full object-cover"
											onError={(e) => {
												e.currentTarget.src = "/images/favicon-1.png";
											}}
										/>
									</div>
									<div className="flex-1 space-y-2">
										<div>
											<div className="text-sm font-semibold text-muted-foreground mb-1">Symbol</div>
											<div className="text-lg font-bold">{collectionData.fa_symbol}</div>
										</div>
										<div>
											<div className="text-sm font-semibold text-muted-foreground mb-1">Name</div>
											<div className="text-base">{collectionData.fa_name}</div>
										</div>
									</div>
								</div>

								{/* Right Column: Sale Deadline and Project */}
								<div className="space-y-4">
									<div>
										<div className="text-sm font-semibold text-muted-foreground mb-1">Sale Deadline</div>
										<div className="text-base">{new Date(collectionData.sale_deadline || 0).toLocaleString()}</div>
									</div>
									<div>
										<div className="text-sm font-semibold text-muted-foreground mb-1">Project</div>
										<a
											href={collectionData.fa_project_uri}
											target="_blank"
											rel="noopener noreferrer"
											className="text-base text-primary hover:underline flex items-center gap-1"
										>
											{collectionData.fa_project_uri}
											<ExternalLinkIcon className="w-4 h-4" />
										</a>
									</div>
								</div>
							</div>
						</CardContent>
					</GlassCard>

					<div className="space-y-2">
						{stages.map((stage) => (
							<MintStageCard
								key={stage.name}
								stage={stage}
								collectionId={collectionIdTyped}
								mintBalance={mintBalance}
								onMintSuccess={(tokenIds) => {
									setRecentlyMintedTokenIds(tokenIds);
									setShowMintDialog(true);
								}}
							/>
						))}
					</div>

					{/* My NFTs Section */}
					{connected &&
						isFetchedNFTs &&
						nfts?.current_token_ownerships_v2 &&
						nfts.current_token_ownerships_v2.length > 0 && (
							<GlassCard className="w-full">
								<CardHeader>
									<CardTitle>My NFTs</CardTitle>
									<CardDescription>NFTs from this collection in your wallet</CardDescription>
								</CardHeader>
								<CardContent>
									<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
										{nfts.current_token_ownerships_v2.map((nft) => (
											<NFTThumbnail
												key={nft.token_data_id}
												nft={nft}
												collectionData={collectionData}
												onClick={() => handleNFTClick(nft)}
											/>
										))}
									</div>
								</CardContent>
							</GlassCard>
						)}
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
