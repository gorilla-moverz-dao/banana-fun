import { ConvexProvider, ConvexReactClient } from "convex/react";

// Get the Convex URL from environment variables
// In development, this is typically provided by `bunx convex dev`
const convexUrl = import.meta.env.VITE_CONVEX_URL || "";

if (!convexUrl) {
	console.warn("VITE_CONVEX_URL is not set. Convex features will not work. Run 'bunx convex dev' to get the URL.");
}

export const convexClient = new ConvexReactClient(convexUrl);

export { ConvexProvider };
