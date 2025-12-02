import { createFileRoute } from "@tanstack/react-router";
import { CollectionBrowser } from "@/components/CollectionBrowser";

export const Route = createFileRoute("/")({
	component: App,
});

function App() {
	return (
		<>
			<div className="flex items-center justify-between">
				<h1 className="text-2xl pb-4">Active & Upcoming Mints</h1>
			</div>
			<CollectionBrowser path="mint" />
		</>
	);
}
