import type { Doc } from "convex/_generated/dataModel";
import { ExternalLinkIcon, InfoIcon } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
	const description = isHolder ? "Token vesting schedule for NFT holders" : "Token vesting schedule for team";
	const beneficiaryAddress = collectionData.creatorVestingWalletAddress;

	return (
		<GlassCard className="w-full">
			<CardHeader>
				<CardTitle>{title}</CardTitle>
				<CardDescription>{description}</CardDescription>
			</CardHeader>
			<CardContent>
				<div className="space-y-4">
					{/* Beneficiary Address (Team vesting only) */}
					{!isHolder && beneficiaryAddress && (
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Beneficiary Address</div>
							<a
								href={MOVE_NETWORK.explorerUrl.replace("{0}", `account/${beneficiaryAddress}`)}
								target="_blank"
								rel="noopener noreferrer"
								className="text-base text-primary hover:underline flex items-center gap-1"
							>
								{toShortAddress(beneficiaryAddress)}
								<ExternalLinkIcon className="w-4 h-4" />
							</a>
						</div>
					)}

					{/* When sale is completed, show full vesting schedule */}
					{collectionData.saleCompleted && collectionData.saleDeadline && (
						<>
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Vesting Start</div>
								<div className="text-base">{new Date(collectionData.saleDeadline * 1000).toLocaleString()}</div>
							</div>
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Cliff Period</div>
								<div className="text-base">{formatDuration(collectionData.vestingCliff)}</div>
								<div className="text-sm text-muted-foreground mt-1">
									Cliff ends:{" "}
									{new Date((collectionData.saleDeadline + collectionData.vestingCliff) * 1000).toLocaleString()}
								</div>
							</div>
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Vesting Duration</div>
								<div className="text-base">{formatDuration(collectionData.vestingDuration)}</div>
								<div className="text-sm text-muted-foreground mt-1">
									Full vesting ends:{" "}
									{new Date((collectionData.saleDeadline + collectionData.vestingDuration) * 1000).toLocaleString()}
								</div>
							</div>
						</>
					)}

					{/* When sale is not completed, show basic info with tooltips */}
					{!collectionData.saleCompleted && (
						<>
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Cliff Period</div>
								<div className="text-base flex items-center gap-2">
									{formatDuration(collectionData.vestingCliff)}
									<Tooltip>
										<TooltipTrigger asChild>
											<InfoIcon className="w-4 h-4 text-muted-foreground cursor-help" />
										</TooltipTrigger>
										<TooltipContent>
											<p>Vesting will start after sale completion</p>
										</TooltipContent>
									</Tooltip>
								</div>
							</div>
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Vesting Duration</div>
								<div className="text-base flex items-center gap-2">
									{formatDuration(collectionData.vestingDuration)}
									<Tooltip>
										<TooltipTrigger asChild>
											<InfoIcon className="w-4 h-4 text-muted-foreground cursor-help" />
										</TooltipTrigger>
										<TooltipContent>
											<p>Vesting will start after sale completion</p>
										</TooltipContent>
									</Tooltip>
								</div>
							</div>
						</>
					)}

					{/* Vesting Amount */}
					{collectionData.faVestingAmount && (
						<div>
							<div className="text-sm font-semibold text-muted-foreground mb-1">Total Vesting Pool</div>
							<div className="text-base">
								{oaptToApt(collectionData.faVestingAmount || 0).toLocaleString()} {collectionData.faSymbol}
							</div>
						</div>
					)}
				</div>
			</CardContent>
		</GlassCard>
	);
}
