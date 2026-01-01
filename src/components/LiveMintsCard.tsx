import { useQuery } from "convex/react";
import { Zap } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { toShortAddress } from "@/lib/utils";
import { api } from "../../convex/_generated/api";

interface LiveMintsCardProps {
	collectionId: string;
}

export function LiveMintsCard({ collectionId }: LiveMintsCardProps) {
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
		<GlassCard>
			<CardHeader className="pb-2">
				<CardTitle className="flex items-center gap-2 text-lg">
					<Zap className="w-5 h-5 text-yellow-400" />
					Live Mints
				</CardTitle>
			</CardHeader>
			<CardContent>
				<div className="overflow-x-auto">
					<table className="w-full text-sm">
						<thead>
							<tr className="text-muted-foreground text-xs uppercase tracking-wider">
								<th className="text-left pb-3 font-medium">Minter</th>
								<th className="text-right pb-3 font-medium">Time</th>
							</tr>
						</thead>
						<tbody className="divide-y divide-white/10">
							{recentMints.map((mint) => (
								<tr key={mint._id} className="hover:bg-white/5 transition-colors">
									<td className="py-3">
										<div className="flex items-center gap-3">
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
												<div className="font-medium truncate" title={mint.ownerAddress}>
													{mint.ownerAddress ? toShortAddress(mint.ownerAddress) : "Unknown"}
												</div>
												<div className="text-xs text-muted-foreground truncate">{mint.name}</div>
											</div>
										</div>
									</td>
									<td className="py-3 text-right text-muted-foreground whitespace-nowrap">
										{mint.mintedAt ? formatTimeAgo(mint.mintedAt) : "-"}
									</td>
								</tr>
							))}
						</tbody>
					</table>
				</div>
			</CardContent>
		</GlassCard>
	);
}
