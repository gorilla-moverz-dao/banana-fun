import type { Doc } from "convex/_generated/dataModel";
import { ArrowRightLeft, ExternalLinkIcon } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { Button } from "@/components/ui/button";
import { CardContent } from "@/components/ui/card";
import { MOVE_NETWORK } from "@/constants";
import { toShortAddress } from "@/lib/utils";

interface TokenInfoCardProps {
	collectionData: Doc<"collections">;
}

export function TokenInfoCard({ collectionData }: TokenInfoCardProps) {
	const { faIconUri, faName, faSymbol, saleDeadline, faProjectUri, faMetadataAddress } = collectionData;

	if (!faSymbol && !faName && !saleDeadline && !faProjectUri) {
		return null;
	}

	return (
		<GlassCard className="w-full">
			<CardContent>
				<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
					{/* Left Column: Icon and Symbol */}
					<div className="flex items-start gap-4">
						{faIconUri && (
							<div className="w-16 h-16 rounded-lg overflow-hidden border border-white/20 flex-shrink-0">
								<img
									src={faIconUri}
									alt={faName || "FA Icon"}
									className="w-full h-full object-cover"
									onError={(e) => {
										e.currentTarget.src = "/images/favicon-1.png";
									}}
								/>
							</div>
						)}
						<div className="flex-1 space-y-2">
							{faSymbol && (
								<div>
									<div className="text-sm font-semibold text-muted-foreground mb-1">Symbol</div>
									<div className="text-lg font-bold">{faSymbol}</div>
								</div>
							)}
							{faName && (
								<div>
									<div className="text-sm font-semibold text-muted-foreground mb-1">Name</div>
									<div className="text-base">{faName}</div>
								</div>
							)}
							{faMetadataAddress && (
								<div>
									<div className="text-sm font-semibold text-muted-foreground mb-1">Metadata Address</div>
									<a
										href={MOVE_NETWORK.explorerUrl.replace("{0}", `object/${faMetadataAddress}`)}
										target="_blank"
										rel="noopener noreferrer"
										className="text-base text-primary hover:underline flex items-center gap-1"
									>
										{toShortAddress(faMetadataAddress)}
										<ExternalLinkIcon className="w-4 h-4" />
									</a>
								</div>
							)}
							{faMetadataAddress && collectionData.saleCompleted && (
								<a
									href={`https://bardock.yuzu.finance/swap?tokenIn=0xa&tokenOut=${faMetadataAddress}`}
									target="_blank"
									rel="noopener noreferrer"
								>
									<Button className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600">
										<ArrowRightLeft className="w-4 h-4 mr-2" />
										Trade on Yuzu
									</Button>
								</a>
							)}
						</div>
					</div>

					{/* Right Column: Sale Deadline and Project */}
					<div className="space-y-4">
						{saleDeadline !== undefined && (
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Sale Deadline</div>
								<div className="text-base">{new Date(saleDeadline * 1000).toLocaleString()}</div>
							</div>
						)}
						{faProjectUri && (
							<div>
								<div className="text-sm font-semibold text-muted-foreground mb-1">Project</div>
								<a
									href={faProjectUri}
									target="_blank"
									rel="noopener noreferrer"
									className="text-base text-primary hover:underline flex items-center gap-1"
								>
									{faProjectUri}
									<ExternalLinkIcon className="w-4 h-4" />
								</a>
							</div>
						)}
					</div>
				</div>
			</CardContent>
		</GlassCard>
	);
}
