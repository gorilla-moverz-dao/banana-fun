import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { ChevronLeft, ChevronRight, ExternalLinkIcon } from "lucide-react";
import { useState } from "react";
import { AssetDetailDialog } from "@/components/AssetDetailDialog";
import { CollectionFilters } from "@/components/CollectionFilters";
import { GlassCard } from "@/components/GlassCard";
import { MyNFTsCard } from "@/components/MyNFTsCard";
import { NFTThumbnail } from "@/components/NFTThumbnail";
import { TokenInfoCard } from "@/components/TokenInfoCard";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CardContent } from "@/components/ui/card";
import { VestingCard } from "@/components/VestingCard";
import { MOVE_NETWORK } from "@/constants";
import type { NFT } from "@/fragments/nft";
import { useClients } from "@/hooks/useClients";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import type { CollectionSearch } from "@/hooks/useCollectionSearch";
import { applyCollectionSearchDefaults, useCollectionSearch } from "@/hooks/useCollectionSearch";
import { toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/collections/$collectionId")({
	validateSearch: (search: Record<string, unknown>): CollectionSearch => {
		return {
			...applyCollectionSearchDefaults(search),
		};
	},
	component: RouteComponent,
});

function RouteComponent() {
	const { search, collectionId, updateSearchParams } = useCollectionSearch();
	const { connected } = useClients();
	const [showAssetDetailDialog, setShowAssetDetailDialog] = useState(false);
	const [selectedNFT, setSelectedNFT] = useState<NFT | null>(null);

	// Fetch collection details
	const collectionData = useQuery(api.collections.getCollection, {
		collectionId: collectionId as `0x${string}`,
	});

	const collectionLoading = collectionData === undefined;

	const pageSize = 100;

	// Fetch NFTs in the collection
	const { data: nftsData, isLoading: nftsLoading } = useCollectionNFTs({
		onlyOwned: search.filter === "owned",
		collectionIds: [collectionId],
		sort: search.sort,
		search: search.search,
		page: search.page,
		limit: pageSize,
	});

	// Fetch user's NFTs in this collection (for My NFTs section)
	const { data: myNftsData, isFetched: isFetchedMyNFTs } = useCollectionNFTs({
		onlyOwned: true,
		collectionIds: [collectionId],
	});

	const startIndex = (search.page - 1) * pageSize;

	// Get the NFTs directly from the server response
	const nfts = nftsData?.current_token_ownerships_v2 || [];
	const myNfts = myNftsData?.current_token_ownerships_v2 || [];

	const totalPages = collectionData ? Math.ceil((collectionData.currentSupply || 0) / pageSize) : 0;

	const handleNFTClick = (nft: NFT) => {
		setSelectedNFT(nft);
		setShowAssetDetailDialog(true);
	};

	// Check if vesting info is available
	const hasHolderVesting = collectionData?.vestingCliff !== undefined && collectionData?.vestingDuration !== undefined;
	const hasTeamVesting =
		collectionData?.creatorVestingCliff !== undefined && collectionData?.creatorVestingDuration !== undefined;

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
				<GlassCard className="p-3 backdrop-blur-3xl dark:bg-secondary/20">
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
								<h1 className="text-2xl font-bold">{collectionData.collectionName}</h1>
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

			{/* Vesting Cards - Side by side on larger screens */}
			{(hasHolderVesting || hasTeamVesting) && (
				<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
					{hasHolderVesting && <VestingCard type="holder" collectionData={collectionData} />}
					{hasTeamVesting && <VestingCard type="team" collectionData={collectionData} />}
				</div>
			)}

			{/* My NFTs Card */}
			{connected && isFetchedMyNFTs && myNfts.length > 0 && (
				<MyNFTsCard
					nfts={myNfts}
					collectionData={collectionData}
					onNFTClick={handleNFTClick}
					gridCols="grid-cols-2 md:grid-cols-4 lg:grid-cols-6"
				/>
			)}

			{/* Collection Browser Section */}
			<div className="space-y-4">
				<GlassCard className="p-3 flex flex-col gap-2 backdrop-blur-3xl dark:bg-secondary/20">
					{/* Filters */}
					<CollectionFilters />

					{/* Results Count */}
					<div className="flex items-center justify-between">
						<div className="text-sm text-muted-foreground">
							Showing {startIndex + 1}-{startIndex + nfts.length} of {collectionData.currentSupply} NFTs
							{search.search && ` matching "${search.search}"`}
						</div>
					</div>
				</GlassCard>

				{/* NFTs Grid/List */}
				{nftsLoading ? (
					<div className="flex items-center justify-center min-h-[400px]">
						<div className="text-lg">Loading NFTs...</div>
					</div>
				) : nfts.length === 0 ? (
					<GlassCard>
						<CardContent className="flex items-center justify-center min-h-[200px]">
							<div className="text-center space-y-2">
								<div className="text-lg font-medium">No NFTs found</div>
								<div className="text-sm text-muted-foreground">
									{search.search ? `No NFTs match "${search.search}"` : "This collection has no NFTs yet"}
								</div>
							</div>
						</CardContent>
					</GlassCard>
				) : (
					<>
						{search.view === "grid" ? (
							<div className="grid gap-4 grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
								{nfts.map((nft) => (
									<NFTThumbnail key={nft.token_data_id} nft={nft} collectionData={collectionData} />
								))}
							</div>
						) : (
							<div className="space-y-2">
								{nfts.map((nft) => (
									<GlassCard
										hoverEffect={true}
										key={nft.token_data_id}
										className="p-2 cursor-pointer hover:bg-white/10 transition-all duration-200 backdrop-blur-sm bg-white/5 border border-white/20 group"
									>
										<div className="flex items-center gap-4">
											<div className="w-20 h-20 rounded-lg overflow-hidden border border-white/20 transition-transform duration-300 group-hover:scale-120">
												<img
													src={nft.current_token_data?.token_uri}
													alt={nft.current_token_data?.token_name || "NFT"}
													className="w-full h-full object-cover"
													onError={(e) => {
														e.currentTarget.src = collectionData.uri;
													}}
												/>
											</div>
											<div className="flex-3">
												<h4 className="font-medium">
													{nft.current_token_data?.token_name || `Token ${nft.token_data_id}`}
												</h4>
												<p className="text-sm text-muted-foreground">{nft.current_token_data?.description}</p>
												<p className="text-xs text-muted-foreground">Token ID: {toShortAddress(nft.token_data_id)}</p>
											</div>
											<div className="flex-2 text-right">
												{Object.entries(nft.current_token_data?.token_properties || {}).map(([traitType, value]) => (
													<Badge key={traitType} variant="outline">
														{traitType}: {value as string}
													</Badge>
												))}
											</div>
										</div>
									</GlassCard>
								))}
							</div>
						)}

						{/* Pagination */}
						{totalPages > 1 && (
							<div className="flex items-center justify-center gap-2">
								<Button
									variant="outline"
									size="sm"
									disabled={search.page <= 1}
									onClick={() => {
										updateSearchParams({ page: search.page - 1 });
									}}
								>
									<ChevronLeft className="w-4 h-4" />
									Previous
								</Button>
								<div className="text-sm">
									Page {search.page} of {totalPages}
								</div>
								<Button
									variant="outline"
									size="sm"
									disabled={search.page >= totalPages}
									onClick={() => {
										updateSearchParams({ page: search.page + 1 });
									}}
								>
									Next
									<ChevronRight className="w-4 h-4" />
								</Button>
							</div>
						)}
					</>
				)}
			</div>

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
