import { useQuery } from "convex/react";
import { Zap } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

export type LiveMint = {
	_id: string;
	name: string;
	uri: string;
	description: string;
	nftTokenId?: string;
	ownerAddress?: string;
	mintedAt?: number;
};

interface LiveMintsCardProps {
	collectionId: string;
	onMintClick?: (mint: LiveMint) => void;
}

export function LiveMintsCard({ collectionId, onMintClick }: LiveMintsCardProps) {
	const recentMints = useQuery(api.reveal.getRecentMints, { collectionId });

	const formatTimeAgo = (timestamp: number) => {
		const seconds = Math.floor((Date.now() - timestamp) / 1000);

		if (seconds < 60) return "just now";
		if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
		if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
		return `${Math.floor(seconds / 86400)}d ago`;
	};

	if (!recentMints || recentMints.length === 0) {
		return null;
	}

	return (
		<GlassCard className="gap-0">
			<CardHeader className="pb-2">
				<CardTitle className="flex items-center gap-2 text-lg">
					<Zap className="w-5 h-5 text-yellow-400" />
					Live Mints
				</CardTitle>
			</CardHeader>
			<CardContent>
				<div className="max-h-[300px] overflow-y-auto rounded-lg bg-black/20">
					{/* Header */}
					<div className="sticky top-0 bg-black/60 backdrop-blur-sm rounded-t-lg px-3 py-2 flex justify-between text-muted-foreground text-xs uppercase tracking-wider font-medium">
						<span>Minter</span>
						<span>Time</span>
					</div>
					{/* Items */}
					<div className="divide-y divide-white/10">
						{recentMints.map((mint) => (
							<button
								type="button"
								key={mint._id}
								onClick={() => onMintClick?.(mint as LiveMint)}
								className="flex items-center justify-between w-full px-3 py-2 hover:bg-white/5 transition-colors cursor-pointer text-left"
							>
								<div className="flex items-center gap-3 min-w-0">
									<div className="w-8 h-8 rounded-full overflow-hidden bg-gradient-to-br from-yellow-400 to-orange-500 flex-shrink-0">
										{mint.uri && (
											<img
												src={mint.uri}
												alt={mint.name}
												className="w-full h-full object-cover"
												onError={(e) => {
													e.currentTarget.style.display = "none";
												}}
											/>
										)}
									</div>
									<div className="min-w-0">
										<div className="font-medium truncate text-sm" title={mint.ownerAddress}>
											{mint.ownerAddress ? toShortAddress(mint.ownerAddress) : "Unknown"}
										</div>
										<div className="text-xs text-muted-foreground truncate">{mint.name}</div>
									</div>
								</div>
								<div className="text-sm text-muted-foreground whitespace-nowrap ml-2">
									{mint.mintedAt ? formatTimeAgo(mint.mintedAt) : "-"}
								</div>
							</button>
						))}
					</div>
				</div>
			</CardContent>
		</GlassCard>
	);
}
