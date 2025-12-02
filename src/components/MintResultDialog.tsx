import { NFTThumbnail } from "./NFTThumbnail";
import type { Collection } from "@/fragments/collection";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";

interface MintResultDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  recentlyMintedTokenIds: Array<string>;
  collectionData: Collection;
}

export function MintResultDialog({ open, onOpenChange, recentlyMintedTokenIds, collectionData }: MintResultDialogProps) {
  const { data: nfts, isLoading: isLoadingNFTs } = useCollectionNFTs({
    onlyOwned: false,
    collectionIds: [collectionData.collection_id],
    tokenIds: recentlyMintedTokenIds,
  });

  return (
    <Dialog open={open && !isLoadingNFTs} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>🎉 Mint Successful!</DialogTitle>
          <DialogDescription>You have successfully minted {recentlyMintedTokenIds.length} NFT(s) from the collection.</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          {nfts?.current_token_ownerships_v2 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 gap-4">
              {nfts.current_token_ownerships_v2
                .filter((nft) => recentlyMintedTokenIds.includes(nft.token_data_id))
                .map((nft) => (
                  <NFTThumbnail key={nft.token_data_id} nft={nft} collectionData={collectionData} />
                ))}
            </div>
          ) : (
            <div className="text-center py-8 text-muted-foreground">No NFTs found for the recently minted token IDs</div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
