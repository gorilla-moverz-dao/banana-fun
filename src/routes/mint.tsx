import { createFileRoute, Outlet, redirect, useParams } from "@tanstack/react-router";
import { CollectionBrowser } from "@/components/CollectionBrowser";
import { COLLECTION_ID, SINGLE_COLLECTION_MODE } from "@/constants";

export const Route = createFileRoute("/mint")({
	beforeLoad: ({ location }) => {
		// Only redirect if we're exactly at /mint (not at a child route)
		if (location.pathname === "/mint" && SINGLE_COLLECTION_MODE) {
			throw redirect({
				to: "/mint/$collectionId",
				params: { collectionId: COLLECTION_ID },
			});
		}
	},
	component: RouteComponent,
});

function RouteComponent() {
	const collectionId: string | undefined = useParams({ from: "/mint/$collectionId", shouldThrow: false });

	if (!collectionId) {
		return (
			<>
				<div className="flex items-center justify-between">
					<h1 className="text-2xl pb-4">Active & Upcoming Launches</h1>
				</div>
				<CollectionBrowser path="mint" />
			</>
		);
	}

	return <Outlet />;
}
