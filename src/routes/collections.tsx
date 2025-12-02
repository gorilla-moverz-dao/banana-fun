import { createFileRoute, Outlet, useParams } from "@tanstack/react-router";
import { CollectionBrowser } from "@/components/CollectionBrowser";

export const Route = createFileRoute("/collections")({
	component: RouteComponent,
});

function RouteComponent() {
	const collectionId: string | undefined = useParams({ from: "/collections/$collectionId", shouldThrow: false });

	if (!collectionId) {
		return (
			<>
				<div className="flex items-center justify-between">
					<h1 className="text-2xl pb-4">Collections</h1>
				</div>
				<CollectionBrowser path="collections" />
			</>
		);
	}

	return <Outlet />;
}
