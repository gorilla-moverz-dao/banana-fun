import { createFileRoute, Link, Outlet, useParams } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { AlertTriangle, CheckCircle, Clock } from "lucide-react";
import { GlassCard } from "@/components/GlassCard";
import { Badge } from "@/components/ui/badge";
import { searchDefaults } from "@/hooks/useCollectionSearch";
import { api } from "../../convex/_generated/api";

export const Route = createFileRoute("/collections")({
	component: RouteComponent,
});

interface GroupedCollection {
	collectionId: string;
	collectionName: string;
	currentSupply: number;
	maxSupply: number;
	uri: string;
	description: string;
	saleDeadline: number;
	collection_id: string;
	collection_name: string;
	current_supply: number;
	max_supply: number;
	sale_deadline: number;
}

function CollectionCard({
	collection,
	status,
}: {
	collection: GroupedCollection;
	status: "ongoing" | "successful" | "failed";
}) {
	const linkPath = "/collections/$collectionId";

	return (
		<Link to={linkPath} params={{ collectionId: collection.collection_id }} search={searchDefaults} className="block">
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
					{status === "ongoing" && (
						<Badge className="absolute top-2 right-2 bg-blue-500/90 text-white border-blue-400/50 shadow-lg backdrop-blur-sm">
							<Clock className="size-3 mr-1" />
							Live
						</Badge>
					)}
					{status === "successful" && (
						<Badge className="absolute top-2 right-2 bg-emerald-500/90 text-white border-emerald-400/50 shadow-lg backdrop-blur-sm">
							<CheckCircle className="size-3 mr-1" />
							Completed
						</Badge>
					)}
				</div>
				<div className="font-semibold text-lg text-foreground truncate w-full" title={collection.collection_name}>
					{collection.collection_name}
				</div>
				<div className="text-sm text-muted-foreground w-full line-clamp-2" title={collection.description}>
					{collection.description}
				</div>
				<div className="flex items-center justify-between w-full mt-auto pt-2">
					<span className="text-xs text-muted-foreground">
						{collection.current_supply} / {collection.max_supply} minted
					</span>
					{status === "failed" && (
						<Badge variant="destructive" className="text-xs">
							Refund Available
						</Badge>
					)}
				</div>
			</GlassCard>
		</Link>
	);
}

const statusBadgeStyles = {
	ongoing: "bg-blue-500/90 text-white border-blue-400/50",
	successful: "bg-emerald-500/90 text-white border-emerald-400/50",
	failed: "bg-red-500/90 text-white border-red-400/50",
};

function CollectionGroup({
	title,
	icon,
	collections,
	status,
	emptyMessage,
}: {
	title: string;
	icon: React.ReactNode;
	collections: GroupedCollection[];
	status: "ongoing" | "successful" | "failed";
	emptyMessage: string;
}) {
	return (
		<section className="mb-10">
			<div className="flex items-center gap-2 mb-4">
				<Badge className={`flex items-center gap-2 ${statusBadgeStyles[status]}`}>
					<span className="flex items-center justify-center">{icon}</span>
					<h2 className="text-xl font-bold text-shadow-lg">{title}</h2>
					<Badge className="text-xs text-white bg-opacity-50 border border-white/50">{collections.length}</Badge>
				</Badge>
			</div>
			{collections.length === 0 ? (
				<GlassCard className="p-6 text-center">
					<p className="text-muted-foreground">{emptyMessage}</p>
				</GlassCard>
			) : (
				<div className="grid gap-6 grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
					{collections.map((collection) => (
						<CollectionCard key={collection.collection_id} collection={collection} status={status} />
					))}
				</div>
			)}
		</section>
	);
}

function RouteComponent() {
	const collectionId: string | undefined = useParams({ from: "/collections/$collectionId", shouldThrow: false });
	const data = useQuery(api.collections.getCollectionsGrouped);

	if (collectionId) {
		return <Outlet />;
	}

	if (data === undefined) {
		return <div className="text-center py-8">Loading collections...</div>;
	}

	return (
		<div>
			{/* Ongoing Launches */}
			<CollectionGroup
				title="Live Launches"
				icon={<Clock className="w-5 h-5" />}
				collections={data.ongoing}
				status="ongoing"
				emptyMessage="No live launches at the moment."
			/>

			{/* Successful Launches */}
			<CollectionGroup
				title="Completed Launches"
				icon={<CheckCircle className="w-5 h-5" />}
				collections={data.successful}
				status="successful"
				emptyMessage="No completed launches yet."
			/>

			{/* Failed Launches */}
			{data.failed.length > 0 && (
				<CollectionGroup
					title="Failed Launches"
					icon={<AlertTriangle className="w-5 h-5" />}
					collections={data.failed}
					status="failed"
					emptyMessage="No failed launches."
				/>
			)}
		</div>
	);
}
