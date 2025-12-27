import { TanStackDevtools } from "@tanstack/react-devtools";
import type { QueryClient } from "@tanstack/react-query";
import { createRootRouteWithContext, Outlet } from "@tanstack/react-router";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";
import { Toaster } from "sonner";
import Header from "../components/Header";
import TanStackQueryDevtools from "../integrations/tanstack-query/devtools";

interface MyRouterContext {
	queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<MyRouterContext>()({
	component: () => (
		<>
			<div
				className="fixed top-0 left-0 -z-10 h-screen w-screen bg-cover bg-center bg-no-repeat"
				style={{
					backgroundImage: "url('/images/background.webp')",
				}}
			/>
			<div className="fixed top-0 left-0 -z-10 h-screen w-screen bg-black/20" />
			<Header />
			<main className="pt-4 px-4 md:px-6 lg:px-0 pb-8 w-full max-w-7xl mx-auto">
				<Outlet />
			</main>
			<Toaster />
			<TanStackDevtools
				config={{
					position: "bottom-right",
				}}
				plugins={[
					{
						name: "Tanstack Router",
						render: <TanStackRouterDevtoolsPanel />,
					},
					TanStackQueryDevtools,
				]}
			/>
		</>
	),
});
