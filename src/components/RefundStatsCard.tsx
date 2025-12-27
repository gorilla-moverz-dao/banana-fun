import type { Doc } from "convex/_generated/dataModel";
import { Flame, Wallet } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { oaptToApt } from "@/lib/utils";

interface RefundStatsCardProps {
	collectionData: Doc<"collections">;
}

export function RefundStatsCard({ collectionData }: RefundStatsCardProps) {
	const nftsBurned = collectionData.refundNftsBurned ?? 0;
	const totalRefunded = collectionData.refundTotalAmount ?? 0;
	const totalMinted = collectionData.currentSupply ?? 0;
	const totalCollected = collectionData.totalFundsCollected ?? 0;

	// Calculate remaining (not yet refunded)
	const nftsRemaining = totalMinted - nftsBurned;
	const fundsRemaining = totalCollected;

	return (
		<GlassCard className="w-full border-orange-500/30 bg-gradient-to-br from-orange-500/10 to-red-500/10">
			<CardHeader>
				<CardTitle className="flex items-center gap-2 text-orange-400">
					<Flame className="w-5 h-5" />
					Refund Progress
				</CardTitle>
				<CardDescription>Track the refund claims from this failed launch</CardDescription>
			</CardHeader>
			<div className="px-6 pb-6 grid grid-cols-2 md:grid-cols-4 gap-4">
				{/* NFTs Burned */}
				<Tooltip>
					<TooltipTrigger asChild>
						<div className="text-center p-4 rounded-lg bg-black/20 border border-orange-500/20">
							<div className="text-2xl font-bold text-orange-400">{nftsBurned}</div>
							<div className="text-sm text-muted-foreground">NFTs Burned</div>
						</div>
					</TooltipTrigger>
					<TooltipContent>
						<p>Number of NFTs that have been burned for refunds</p>
					</TooltipContent>
				</Tooltip>

				{/* Total Refunded */}
				<Tooltip>
					<TooltipTrigger asChild>
						<div className="text-center p-4 rounded-lg bg-black/20 border border-orange-500/20">
							<div className="text-2xl font-bold text-orange-400">
								{oaptToApt(totalRefunded).toLocaleString()}
							</div>
							<div className="text-sm text-muted-foreground">MOVE Refunded</div>
						</div>
					</TooltipTrigger>
					<TooltipContent>
						<p>Total MOVE tokens that have been refunded to users</p>
					</TooltipContent>
				</Tooltip>

				{/* NFTs Remaining */}
				<Tooltip>
					<TooltipTrigger asChild>
						<div className="text-center p-4 rounded-lg bg-black/20 border border-white/10">
							<div className="text-2xl font-bold text-muted-foreground">{nftsRemaining}</div>
							<div className="text-sm text-muted-foreground">NFTs Remaining</div>
						</div>
					</TooltipTrigger>
					<TooltipContent>
						<p>NFTs that haven't been burned yet (eligible for refund)</p>
					</TooltipContent>
				</Tooltip>

				{/* Funds Remaining */}
				<Tooltip>
					<TooltipTrigger asChild>
						<div className="text-center p-4 rounded-lg bg-black/20 border border-white/10">
							<div className="flex items-center justify-center gap-1 text-2xl font-bold text-muted-foreground">
								<Wallet className="w-5 h-5" />
								{oaptToApt(fundsRemaining).toLocaleString()}
							</div>
							<div className="text-sm text-muted-foreground">MOVE Remaining</div>
						</div>
					</TooltipTrigger>
					<TooltipContent>
						<p>MOVE tokens still available for refunds in the contract</p>
					</TooltipContent>
				</Tooltip>
			</div>
		</GlassCard>
	);
}

