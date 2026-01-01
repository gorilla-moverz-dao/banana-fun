import { createFileRoute, Outlet, useParams } from "@tanstack/react-router";
import { CollectionBrowser } from "@/components/CollectionBrowser";

export const Route = createFileRoute("/mint")({
	component: RouteComponent,
});

function RouteComponent() {
	const collectionId: string | undefined = useParams({ from: "/mint/$collectionId", shouldThrow: false });

	if (!collectionId) {
		return (
			<>
				<div className="flex items-center justify-between">
					<h1 className="text-2xl pb-4 text-shadow-lg font-bold">Active & Upcoming Launches</h1>
				</div>
				<CollectionBrowser path="mint" />
			</>
		);
	}

	return <Outlet />;
}
