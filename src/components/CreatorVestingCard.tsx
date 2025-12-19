import { useQuery } from "@tanstack/react-query";
import type { Doc } from "convex/_generated/dataModel";
import { ExternalLinkIcon, Wallet } from "lucide-react";
import { toast } from "sonner";
import { GlassCard } from "@/components/GlassCard";
import { Button } from "@/components/ui/button";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { MOVE_NETWORK } from "@/constants";
import { useClients } from "@/hooks/useClients";
import { useTransaction } from "@/hooks/useTransaction";
import { vestingClient } from "@/lib/aptos";
import { faToDisplay, formatDuration, toShortAddress } from "@/lib/utils";

interface CreatorVestingCardProps {
	collectionData: Doc<"collections">;
}

export function CreatorVestingCard({ collectionData }: CreatorVestingCardProps) {
	const { vestingClient: walletVestingClient, connected, correctNetwork, address } = useClients();
	const { transactionInProgress: claiming, executeTransaction } = useTransaction();

	// Fetch creator claimable amount
	const {
		data: claimableAmount,
		isLoading: isLoadingClaimable,
		refetch: refetchClaimable,
	} = useQuery({
		queryKey: ["creator-claimable", collectionData.collectionId, address],
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

	// Fetch creator vested amount (what the backend calculates as vested)
	const { data: vestedAmount } = useQuery({
		queryKey: ["creator-vested", collectionData.collectionId],
		queryFn: async () => {
			const result = await vestingClient.view.get_creator_vested_amount({
				functionArguments: [collectionData.collectionId as `0x${string}`],
				typeArguments: [],
			});
			return Number(result[0]);
		},
		enabled: collectionData.saleCompleted,
		refetchInterval: 30000,
	});

	// Use vesting config from database (synced from contract)
	const totalPool = collectionData.creatorVestingTotalPool || collectionData.faCreatorVestingAmount || 0;
	const hasClaimable = (claimableAmount ?? 0) > 0;

	// Calculate vesting progress based on actual vested amount from backend
	// This is more accurate than calculating from time, especially if saleDeadline is incorrect
	const vestingProgress =
		totalPool > 0 && vestedAmount !== undefined ? Math.min(100, Math.max(0, (vestedAmount / totalPool) * 100)) : 0;

	// Calculate claimed progress as percentage
	const claimedProgress =
		totalPool > 0 && claimedAmount !== undefined ? Math.min(100, Math.max(0, (claimedAmount / totalPool) * 100)) : 0;

	// Use vesting start time from database (synced from contract), fall back to saleDeadline
	const vestingStart = collectionData.creatorVestingStartTime || collectionData.saleDeadline || 0;
	const vestingCliff = collectionData.creatorVestingCliff || 0;
	const vestingDuration = collectionData.creatorVestingDuration || 0;
	const cliffEnd = vestingStart + vestingCliff;

	// Calculate cliff period status
	const now = Math.floor(Date.now() / 1000);
	// If there are claimable tokens, the cliff period has definitely passed
	// Use claimable amount as the source of truth since it's fetched from the backend
	const isInCliff = hasClaimable ? false : now < cliffEnd;

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
							<span className="flex items-center gap-3">
								<span>
									Vested: {vestingProgress.toFixed(1)}%
									{vestedAmount !== undefined &&
										` (${faToDisplay(vestedAmount).toLocaleString()} ${collectionData.faSymbol})`}
								</span>
								<span className="text-green-400">
									Claimed: {claimedProgress.toFixed(1)}%
									{isLoadingClaimed
										? "..."
										: ` (${faToDisplay(claimedAmount || 0).toLocaleString()} ${collectionData.faSymbol})`}
								</span>
							</span>
						</div>
						{/* Combined progress bar */}
						<div className="relative w-full h-4 bg-muted rounded-full overflow-hidden">
							{/* Vested portion */}
							<div
								className="absolute left-0 top-0 h-full bg-primary/50 rounded-full"
								style={{ width: `${vestingProgress}%` }}
							/>
							{/* Claimed portion (within vested) */}
							<div
								className="absolute left-0 top-0 h-full bg-green-500 rounded-full"
								style={{ width: `${claimedProgress}%` }}
							/>
						</div>
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
							<div className="text-sm">{new Date((vestingStart + vestingDuration) * 1000).toLocaleDateString()}</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Cliff Period</div>
							<div className="text-sm">{formatDuration(vestingCliff)}</div>
						</div>
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Duration</div>
							<div className="text-sm">{formatDuration(vestingDuration)}</div>
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
								{isLoadingClaimed ? "..." : faToDisplay(claimedAmount || 0).toLocaleString()} {collectionData.faSymbol}
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
