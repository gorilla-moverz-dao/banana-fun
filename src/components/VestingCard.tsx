import type { Doc } from "convex/_generated/dataModel";
import { ExternalLinkIcon, InfoIcon } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent } from "@/components/ui/card";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { MOVE_NETWORK } from "@/constants";
import { formatDuration, oaptToApt, toShortAddress } from "@/lib/utils";

export interface VestingCardProps {
	type: "holder" | "team";
	collectionData: Doc<"collections">;
}

export function VestingCard({ type, collectionData }: VestingCardProps) {
	const isHolder = type === "holder";
	const title = isHolder ? "NFT Holder Vesting" : "Team Vesting";
	const beneficiaryAddress = collectionData.creatorVestingWalletAddress;

	// Get vesting config from database (synced from contract)
	const vestingStartTime = isHolder ? collectionData.vestingStartTime : collectionData.creatorVestingStartTime;
	const vestingTotalPool = isHolder ? collectionData.vestingTotalPool : collectionData.creatorVestingTotalPool;
	const vestingCliff = isHolder ? collectionData.vestingCliff : collectionData.creatorVestingCliff;
	const vestingDuration = isHolder ? collectionData.vestingDuration : collectionData.creatorVestingDuration;

	// Fall back to saleDeadline if vestingStartTime is not yet synced
	const startTime = vestingStartTime || collectionData.saleDeadline || 0;

	const totalPool =
		vestingTotalPool || (isHolder ? collectionData.faVestingAmount || 0 : collectionData.faCreatorVestingAmount || 0);

	const formatDateTime = (timestamp: number) =>
		new Date(timestamp * 1000).toLocaleString(undefined, {
			month: "short",
			day: "numeric",
			hour: "2-digit",
			minute: "2-digit",
		});

	return (
		<GlassCard className="w-full p-0">
			<CardContent className="p-6">
				<div className="flex items-center justify-between mb-2">
					<span className="font-semibold">{title}</span>
					{totalPool > 0 && (
						<span className="text-sm text-muted-foreground">
							{oaptToApt(totalPool).toLocaleString()} {collectionData.faSymbol}
						</span>
					)}
				</div>

				<div className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
					{/* Beneficiary Address (Team vesting only) */}
					{!isHolder && beneficiaryAddress && (
						<>
							<span className="text-muted-foreground">Beneficiary</span>
							<a
								href={MOVE_NETWORK.explorerUrl.replace("{0}", `account/${beneficiaryAddress}`)}
								target="_blank"
								rel="noopener noreferrer"
								className="text-primary hover:underline flex items-center gap-1 justify-end"
							>
								{toShortAddress(beneficiaryAddress)}
								<ExternalLinkIcon className="w-3.5 h-3.5" />
							</a>
						</>
					)}

					{/* When sale is completed, show full vesting schedule */}
					{collectionData.saleCompleted && (
						<>
							<span className="text-muted-foreground">Start</span>
							<span className="text-right">{formatDateTime(startTime)}</span>

							<span className="text-muted-foreground">Cliff</span>
							<span className="text-right">
								{formatDuration(vestingCliff || 0)}
								<span className="text-muted-foreground ml-1">→ {formatDateTime(startTime + (vestingCliff || 0))}</span>
							</span>

							<span className="text-muted-foreground">Duration</span>
							<span className="text-right">
								{formatDuration(vestingDuration || 0)}
								<span className="text-muted-foreground ml-1">
									→ {formatDateTime(startTime + (vestingDuration || 0))}
								</span>
							</span>
						</>
					)}

					{/* When sale is not completed, show basic info with tooltips */}
					{!collectionData.saleCompleted && (
						<>
							<span className="text-muted-foreground">Cliff</span>
							<span className="text-right flex items-center justify-end gap-1">
								{formatDuration(vestingCliff || 0)}
								<Tooltip>
									<TooltipTrigger asChild>
										<InfoIcon className="w-3.5 h-3.5 text-muted-foreground cursor-help" />
									</TooltipTrigger>
									<TooltipContent>
										<p>Vesting will start after sale completion</p>
									</TooltipContent>
								</Tooltip>
							</span>

							<span className="text-muted-foreground">Duration</span>
							<span className="text-right flex items-center justify-end gap-1">
								{formatDuration(vestingDuration || 0)}
								<Tooltip>
									<TooltipTrigger asChild>
										<InfoIcon className="w-3.5 h-3.5 text-muted-foreground cursor-help" />
									</TooltipTrigger>
									<TooltipContent>
										<p>Vesting will start after sale completion</p>
									</TooltipContent>
								</Tooltip>
							</span>
						</>
					)}
				</div>
			</CardContent>
		</GlassCard>
	);
}
