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
import type { Collection } from "@/fragments/collection";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { useMintBalance } from "@/hooks/useMintBalance";
import { useMintStages } from "@/hooks/useMintStages";
import { toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/mint/$collectionId")({
	component: RouteComponent,
});

function RouteComponent() {
	const [showMintDialog, setShowMintDialog] = useState(false);
	const [recentlyMintedTokenIds, setRecentlyMintedTokenIds] = useState<Array<string>>([]);
	const [showAssetDetailDialog, setShowAssetDetailDialog] = useState(false);
	const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null);
	const { connected, address } = useClients();
	const { collectionId } = Route.useParams();

	const collectionIdTyped = collectionId as `0x${string}`;

	// Get collection data from Convex
	const convexCollectionData = useQuery(api.collections.getCollection, {
		collectionId: collectionIdTyped,
	});

	// Mint stages and balance still need on-chain calls for user-specific reduction calculations
	const { data: stages = [], isFetched: isFetchedStages } = useMintStages(
		address?.toString() as `0x${string}`,
		collectionIdTyped,
	);
	const { data: mintBalance, isFetched: isFetchedMintBalance } = useMintBalance(collectionIdTyped);
	const { data: nfts, isFetched: isFetchedNFTs } = useCollectionNFTs({
		onlyOwned: true,
		collectionIds: [collectionIdTyped],
	});

	const isFetched = convexCollectionData !== undefined && isFetchedStages && isFetchedMintBalance;
	if (!isFetched) return <div>Loading...</div>;
	if (!convexCollectionData) return <div>Collection not found</div>;

	// Transform Convex data to match expected format
	const collectionData = {
		collection: convexCollectionData.collection as Collection,
		ownerCount: convexCollectionData.ownerCount,
	};

	const minted = collectionData.collection.current_supply;
	const total = collectionData.collection.max_supply;
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
									src={collectionData.collection.uri}
									alt={collectionData.collection.collection_name}
									className="object-cover w-full h-full transition-transform duration-300 ease-in-out group-hover:scale-105"
								/>
							</div>
							<CardTitle className="truncate text-lg">{collectionData.collection.collection_name}</CardTitle>
							<CardDescription className="mb-1">{collectionData.collection.description}</CardDescription>
						</CardHeader>
						<CardContent>
							<div className="text-sm break-all">
								<p className="font-semibold text-muted-foreground">Collection Address:</p>{" "}
								<a
									href={MOVE_NETWORK.explorerUrl.replace("{0}", `object/${collectionData.collection.collection_id}`)}
									target="_blank"
									rel="noopener noreferrer"
								>
									<div className="flex items-center gap-1">
										{toShortAddress(collectionData.collection.collection_id)} <ExternalLinkIcon className="w-4 h-4" />
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
												collectionData={collectionData.collection}
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
					collectionData={collectionData.collection}
				/>
			)}

			{/* Asset Detail Dialog */}
			<AssetDetailDialog
				open={showAssetDetailDialog}
				onOpenChange={setShowAssetDetailDialog}
				nft={selectedNFT}
				collectionData={collectionData.collection}
			/>
		</div>
	);
}
