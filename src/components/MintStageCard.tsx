import { useState } from "react";
import { toast } from "sonner";
import type { MintStageInfo } from "@/hooks/useMintStages";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Badge } from "@/components/ui/badge";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { NumberInput } from "@/components/ui/number-input";
import { Button } from "@/components/ui/button";
import { oaptToApt } from "@/lib/utils";
import { WalletSelector } from "@/components/WalletSelector";
import { useClients } from "@/hooks/useClients";
import { useMintBalance } from "@/hooks/useMintBalance";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { useGetAccountNativeBalance } from "@/hooks/useGetAccountNativeBalance";
import { useUserReductionNFTs } from "@/hooks/useUserReductionNFTs";
import { useTransaction } from "@/hooks/useTransaction";

interface MintStageCardProps {
  stage: MintStageInfo;
  collectionId: `0x${string}`;
  mintBalance: Array<{ stage: string; balance: number }> | undefined;
  onMintSuccess: (tokenIds: Array<string>) => void;
}

function extractTokenIds(result: any): Array<string> {
  const tokenIds: Array<string> = [];
  if (result?.events) {
    result.events.forEach((event: any) => {
      if (event?.type?.includes("BatchMintNftsEvent") && event?.data?.nft_objs) {
        event.data.nft_objs.forEach((nftObj: any) => {
          if (nftObj?.inner) {
            tokenIds.push(nftObj.inner);
          }
        });
      }
    });
  }
  return tokenIds;
}

export function MintStageCard({ stage, collectionId, mintBalance, onMintSuccess }: MintStageCardProps) {
  const { launchpadClient, connected, address, correctNetwork } = useClients();
  const { refetch: refetchMintBalance } = useMintBalance(collectionId);
  const { refetch: refetchNFTs } = useCollectionNFTs({
    onlyOwned: true,
    collectionIds: [collectionId],
  });
  const { data: nativeBalance, isLoading: isLoadingNativeBalance } = useGetAccountNativeBalance();
  const { data: reductionNFTs = [] } = useUserReductionNFTs(address?.toString() || "");

  const { transactionInProgress: minting, executeTransaction } = useTransaction();
  const [mintAmount, setMintAmount] = useState<number | undefined>(1);

  const now = new Date();
  const start = new Date(Number(stage.start_time) * 1000);
  const end = new Date(Number(stage.end_time) * 1000);
  const isActive = now >= start && now <= end;
  const isPast = now > end;

  const walletBalance = Number(mintBalance?.find((b) => b.stage === stage.name)?.balance || 0);
  const insufficientBalance =
    !isLoadingNativeBalance && (!nativeBalance || nativeBalance.balance < oaptToApt(stage.mint_fee_with_reduction));

  const handleMintAmountChange = (value: number | undefined) => {
    setMintAmount(value);
  };

  async function handleMint() {
    if (!address || !launchpadClient) {
      toast.error("Connect your wallet to mint");
      return;
    }
    if (!mintAmount || mintAmount < 1) {
      toast.error("Please enter a valid mint amount");
      return;
    }
    const amount: number = mintAmount;
    const reductionTokenIds = reductionNFTs.map((nft) => nft.token_data_id as `0x${string}`);
    const { result } = await executeTransaction(
      launchpadClient.mint_nft({
        arguments: [collectionId, amount, reductionTokenIds],
        type_arguments: [],
      }),
    );
    await refetchMintBalance();
    await refetchNFTs();
    const newTokenIds = extractTokenIds(result);
    onMintSuccess(newTokenIds);
  }

  return (
    <GlassCard
      className={`mb-4 transition-all duration-300 pt-4 pb-2 gap-0 ${isActive ? "relative z-10 bg-gradient-to-br from-yellow-400/80 via-orange-400/60 to-yellow-500/40 border-1 border-orange-400/50 shadow-lg shadow-orange-400/20 ring-1 ring-orange-400/30 [&_*]:drop-shadow-lg [&_*]:text-shadow-sm" : "z-0 bg-muted/20 hover:bg-muted/30"}`}
    >
      <CardHeader className="pb-2 flex flex-row items-center justify-between px-6">
        <CardTitle className="text-base flex-1">{stage.name}</CardTitle>
        {isActive && walletBalance > 0 && (
          <div className="flex flex-col gap-1">
            <span className="block text-right text-base text-foreground mt-1 font-semibold min-w-[120px]">
              Total: {((oaptToApt(stage.mint_fee_with_reduction) || 0) * (mintAmount ?? 0)).toLocaleString()} MOVE
            </span>
            {insufficientBalance && (
              <Badge variant="destructive" className="text-xs">
                Insufficient balance: {nativeBalance?.balance.toLocaleString()} MOVE
              </Badge>
            )}
          </div>
        )}
      </CardHeader>
      <CardContent className="flex flex-col md:flex-row md:items-center gap-2 pb-4 px-6">
        <div className="flex-1 text-xs space-y-1">
          {!isPast ? (
            <>
              <div>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <span>
                      Start: {start.toLocaleString()} <span className="text-muted-foreground">(Local Time)</span>
                    </span>
                  </TooltipTrigger>
                  <TooltipContent className="drop-shadow-lg">
                    <p>UTC: {start.toUTCString()}</p>
                  </TooltipContent>
                </Tooltip>
              </div>
              <div>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <span>
                      End: {end.toLocaleString()} <span className="text-muted-foreground">(Local Time)</span>
                    </span>
                  </TooltipTrigger>
                  <TooltipContent className="drop-shadow-lg">
                    <p>UTC: {end.toUTCString()}</p>
                  </TooltipContent>
                </Tooltip>
              </div>
              <div>Mint Fee: {oaptToApt(stage.mint_fee_with_reduction)} MOVE</div>
            </>
          ) : (
            <div className="text-lg font-bold text-muted-foreground">Minting stage is over</div>
          )}
        </div>
        <div className="flex flex-col items-end gap-2">
          {walletBalance > 0 && (
            <Badge variant="outline" className="text-muted-foreground">
              Mint spots: <span className="text-foreground font-bold">{walletBalance}</span>
            </Badge>
          )}
          {walletBalance === 0 && address && (
            <Badge variant="secondary" className="text-xs text-muted-foreground bg-muted/20 border-muted/50">
              No mint spots
            </Badge>
          )}

          <div className="flex items-center gap-2">
            {isActive && (
              <NumberInput
                value={mintAmount}
                onChange={handleMintAmountChange}
                min={1}
                max={walletBalance}
                disabled={minting || walletBalance === 0}
                className="w-32"
                aria-label="Mint amount"
              />
            )}
            {connected && correctNetwork && (
              <Button
                disabled={!isActive || minting || walletBalance === 0 || insufficientBalance || !mintAmount || mintAmount < 1}
                className={!isActive ? "opacity-50 cursor-not-allowed" : ""}
                onClick={handleMint}
              >
                {minting ? "Minting..." : "Mint"}
              </Button>
            )}
            {isActive && (!connected || !correctNetwork) && <WalletSelector />}
          </div>
        </div>
      </CardContent>

      {/* Reduction NFTs Information */}
      {reductionNFTs.length > 0 && walletBalance > 0 && (
        <div className="px-6 pb-4 border-t border-border/50 pt-3">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <Badge variant="secondary" className="text-xs">
                🎫 Fee Reduction Applied
              </Badge>
              <span className="text-xs text-muted-foreground">
                {reductionNFTs.length} NFT{reductionNFTs.length > 1 ? "s" : ""}
              </span>
            </div>
            <div className="text-xs text-green-600 font-bold">
              Save {(oaptToApt(stage.mint_fee) - oaptToApt(stage.mint_fee_with_reduction) || 0).toFixed(2)} MOVE
            </div>
          </div>

          <div className="flex gap-2 mb-2">
            {reductionNFTs.slice(0, 4).map((nft) => (
              <div key={nft.token_data_id} className="relative">
                <img
                  src={nft.current_token_data?.token_uri || "/placeholder-nft.png"}
                  alt={nft.current_token_data?.token_name || "Reduction NFT"}
                  className="w-12 h-12 rounded-lg object-cover border border-border/50"
                  onError={(e) => {
                    e.currentTarget.src = "/placeholder-nft.png";
                  }}
                />
                <div className="absolute -top-1 -right-1 w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                  <span className="text-xs text-white">✓</span>
                </div>
              </div>
            ))}
            {reductionNFTs.length > 4 && (
              <div className="w-12 h-12 bg-muted/50 rounded-lg border border-border/50 flex items-center justify-center">
                <span className="text-xs text-muted-foreground">+{reductionNFTs.length - 4}</span>
              </div>
            )}
          </div>

          <div className="text-xs text-muted-foreground">
            <span className="font-medium">{oaptToApt(stage.mint_fee)} MOVE</span>
            <span className="mx-2">→</span>
            <span className="font-medium text-green-600">{oaptToApt(stage.mint_fee_with_reduction)} MOVE</span>
          </div>
        </div>
      )}
    </GlassCard>
  );
}
