import { useQuery } from "@tanstack/react-query";
import type { Doc } from "convex/_generated/dataModel";
import { ExternalLinkIcon, Wallet } from "lucide-react";
import { toast } from "sonner";
import { GlassCard } from "@/components/GlassCard";
import { Button } from "@/components/ui/button";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { MOVE_NETWORK } from "@/constants";
import { useClients } from "@/hooks/useClients";
import { useTransaction } from "@/hooks/useTransaction";
import { vestingClient } from "@/lib/aptos";
import { faToDisplay, formatDuration, toShortAddress } from "@/lib/utils";

interface CreatorVestingCardProps {
	collectionData: Doc<"collections">;
}

export function CreatorVestingCard({ collectionData }: CreatorVestingCardProps) {
	const { vestingClient: walletVestingClient, connected, correctNetwork } = useClients();
	const { transactionInProgress: claiming, executeTransaction } = useTransaction();

	// Fetch creator claimable amount
	const {
		data: claimableAmount,
		isLoading: isLoadingClaimable,
		refetch: refetchClaimable,
	} = useQuery({
		queryKey: ["creator-claimable", collectionData.collectionId],
		queryFn: async () => {
			const result = await vestingClient.view.get_creator_claimable_amount({
				functionArguments: [collectionData.collectionId as `0x${string}`],
				typeArguments: [],
			});
			return Number(result[0]);
		},
		enabled: collectionData.saleCompleted,
		refetchInterval: 30000,
	});

	// Fetch creator claimed amount
	const { data: claimedAmount, isLoading: isLoadingClaimed } = useQuery({
		queryKey: ["creator-claimed", collectionData.collectionId],
		queryFn: async () => {
			const result = await vestingClient.view.get_creator_claimed_amount({
				functionArguments: [collectionData.collectionId as `0x${string}`],
				typeArguments: [],
			});
			return Number(result[0]);
		},
		enabled: collectionData.saleCompleted,
		refetchInterval: 30000,
	});

	// Fetch remaining creator vesting tokens
	const { data: remainingTokens } = useQuery({
		queryKey: ["creator-remaining", collectionData.collectionId],
		queryFn: async () => {
			const result = await vestingClient.view.get_remaining_creator_vesting_tokens({
				functionArguments: [collectionData.collectionId as `0x${string}`],
				typeArguments: [],
			});
			return Number(result[0]);
		},
		enabled: collectionData.saleCompleted,
		refetchInterval: 30000,
	});

	const totalPool = collectionData.faCreatorVestingAmount || 0;
	const hasClaimable = (claimableAmount ?? 0) > 0;

	// Calculate vesting progress
	const now = Math.floor(Date.now() / 1000);
	const vestingStart = collectionData.saleDeadline || 0;
	const vestingEnd = vestingStart + (collectionData.creatorVestingDuration || 0);
	const cliffEnd = vestingStart + (collectionData.creatorVestingCliff || 0);
	const isInCliff = now < cliffEnd;
	const vestingProgress = Math.min(100, Math.max(0, ((now - vestingStart) / (vestingEnd - vestingStart)) * 100));

	async function handleClaim() {
		if (!walletVestingClient || !hasClaimable) {
			toast.error("Nothing to claim");
			return;
		}

		try {
			await executeTransaction(
				walletVestingClient.claim_creator_vesting({
					arguments: [collectionData.collectionId as `0x${string}`],
					type_arguments: [],
				}),
			);
			toast.success(
				`Successfully claimed ${faToDisplay(claimableAmount || 0).toLocaleString()} ${collectionData.faSymbol}!`,
			);
			await refetchClaimable();
		} catch {
			// Error is handled by useTransaction
		}
	}

	return (
		<GlassCard className="w-full border-purple-500/30">
			<CardHeader>
				<div className="flex items-center justify-between">
					<div className="flex items-center gap-2">
						<Wallet className="w-5 h-5 text-purple-400" />
						<div>
							<CardTitle className="text-purple-400">Creator Vesting</CardTitle>
							<CardDescription>Your team token allocation</CardDescription>
						</div>
					</div>
					{connected && correctNetwork && hasClaimable && (
						<div className="flex items-center gap-3">
							<div className="text-right">
								<div className="text-sm text-muted-foreground">Claimable</div>
								<div className="text-lg font-bold text-purple-400">
									{isLoadingClaimable
										? "..."
										: `${faToDisplay(claimableAmount || 0).toLocaleString()} ${collectionData.faSymbol}`}
								</div>
							</div>
							<Button
								onClick={handleClaim}
								disabled={claiming || !hasClaimable}
								className="bg-purple-600 hover:bg-purple-700"
							>
								{claiming ? "Claiming..." : "Claim"}
							</Button>
						</div>
					)}
				</div>
			</CardHeader>
			<CardContent>
				<div className="space-y-4">
					{/* Beneficiary Address */}
					<div>
						<div className="text-sm font-semibold text-muted-foreground mb-1">Beneficiary (You)</div>
						<a
							href={MOVE_NETWORK.explorerUrl.replace("{0}", `account/${collectionData.creatorVestingWalletAddress}`)}
							target="_blank"
							rel="noopener noreferrer"
							className="text-base text-primary hover:underline flex items-center gap-1"
						>
							{toShortAddress(collectionData.creatorVestingWalletAddress)}
							<ExternalLinkIcon className="w-4 h-4" />
						</a>
					</div>

					{/* Vesting Progress */}
					<div>
						<div className="flex justify-between text-sm mb-2">
							<span className="text-muted-foreground">Vesting Progress</span>
							<span>{vestingProgress.toFixed(1)}%</span>
						</div>
						<Progress value={vestingProgress} className="h-2" />
						{isInCliff && (
							<div className="text-xs text-amber-400 mt-1">
								In cliff period - claiming starts {new Date(cliffEnd * 1000).toLocaleDateString()}
							</div>
						)}
					</div>

					{/* Vesting Schedule */}
					<div className="grid grid-cols-2 gap-4">
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Vesting Start</div>
							<div className="text-sm">{new Date(vestingStart * 1000).toLocaleDateString()}</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Full Vesting</div>
							<div className="text-sm">{new Date(vestingEnd * 1000).toLocaleDateString()}</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Cliff Period</div>
							<div className="text-sm">{formatDuration(collectionData.creatorVestingCliff || 0)}</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Duration</div>
							<div className="text-sm">{formatDuration(collectionData.creatorVestingDuration || 0)}</div>
						</div>
					</div>

					{/* Token Amounts */}
					<div className="grid grid-cols-3 gap-4 pt-2 border-t border-white/10">
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Total Pool</div>
							<div className="text-sm font-medium">
								{faToDisplay(totalPool).toLocaleString()} {collectionData.faSymbol}
							</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Claimed</div>
							<div className="text-sm font-medium text-green-400">
								{isLoadingClaimed ? "..." : faToDisplay(claimedAmount || 0).toLocaleString()}{" "}
								{collectionData.faSymbol}
							</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Remaining</div>
							<div className="text-sm font-medium">
								{faToDisplay(remainingTokens || 0).toLocaleString()} {collectionData.faSymbol}
							</div>
						</div>
					</div>
				</div>
			</CardContent>
		</GlassCard>
	);
}
