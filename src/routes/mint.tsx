import { Outlet, createFileRoute, redirect, useParams } from "@tanstack/react-router";
import { COLLECTION_ID, SINGLE_COLLECTION_MODE } from "@/constants";
import { CollectionBrowser } from "@/components/CollectionBrowser";

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
    return <CollectionBrowser path="mint" />;
  }

  return <Outlet />;
}
