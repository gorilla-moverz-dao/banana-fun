import { Link } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { CheckCircle } from "lucide-react";
import { api } from "../../convex/_generated/api";
import { GlassCard } from "./GlassCard";
import { Badge } from "./ui/badge";

export function CollectionBrowser({ path }: { path: "mint" | "collections" }) {
	const data = useQuery(api.collections.getCollectionsGrouped);

	if (data === undefined) return <div>Loading collections...</div>;

	// Combine ongoing and successful collections, with successful ones marked
	const collections = [
		...data.ongoing.map((c) => ({ ...c, isSuccessful: false })),
		...data.successful.map((c) => ({ ...c, isSuccessful: true })),
	];

	if (collections.length === 0) return <div>No collections found.</div>;

	return (
		<div className="grid gap-6 grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-3">
			{collections.map((collection) => (
				<Link
					key={collection.collection_id}
					to={collection.isSuccessful ? "/collections/$collectionId" : `/${path}/$collectionId`}
					params={{ collectionId: collection.collection_id }}
					className="block"
				>
					<GlassCard hoverEffect={true} className="flex flex-col items-center p-4 h-full group gap-2">
						<div className="relative w-full flex items-center justify-center mb-3 overflow-hidden rounded-lg border">
							<img
								src={collection.uri}
								alt={collection.collection_name}
								className="w-full h-full object-cover border-white/20 bg-white/10 transition-transform duration-300 group-hover:scale-110"
								onError={(e) => {
									e.currentTarget.src = "/images/favicon-1.png";
								}}
							/>
							{collection.isSuccessful && (
								<Badge className="absolute top-2 right-2 bg-emerald-500/90 text-white border-emerald-400/50 shadow-lg backdrop-blur-sm">
									<CheckCircle className="size-3" />
									Successful
								</Badge>
							)}
						</div>
						<div className="font-semibold text-lg text-foreground truncate w-full" title={collection.collection_name}>
							{collection.collection_name}
						</div>
						<div className="text-sm text-muted-foreground w-full line-clamp-3" title={collection.description}>
							{collection.description}
						</div>
					</GlassCard>
				</Link>
			))}
		</div>
	);
}
