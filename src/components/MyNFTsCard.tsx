import type { Doc } from "convex/_generated/dataModel";
import { GlassCard } from "@/components/GlassCard";
import { NFTThumbnail } from "@/components/NFTThumbnail";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { NFT } from "@/fragments/nft";

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
	if (!nfts || nfts.length === 0) {
		return null;
	}

	return (
		<GlassCard className="w-full">
			<CardHeader>
				<CardTitle>My NFTs</CardTitle>
				<CardDescription>NFTs from this collection in your wallet</CardDescription>
			</CardHeader>
			<CardContent>
				<div className={`grid ${gridCols} gap-4`}>
					{nfts.map((nft) => (
						<NFTThumbnail
							key={nft.token_data_id}
							nft={nft}
							collectionData={collectionData}
							onClick={onNFTClick ? () => onNFTClick(nft) : undefined}
						/>
					))}
				</div>
			</CardContent>
		</GlassCard>
	);
}
