import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Sync supply data frequently (currentSupply & ownerCount change often during mints)
crons.interval(
	"Sync collection supply data",
	{ seconds: 30 },
	internal.collectionSyncActions.syncCollectionSupplyAction,
);

// Sync full collection data less frequently (sale state, stages, etc. change rarely)
crons.interval(
	"Sync collection data from blockchain",
	{ minutes: 30 },
	internal.collectionSyncActions.syncCollectionDataAction,
);

export default crons;
