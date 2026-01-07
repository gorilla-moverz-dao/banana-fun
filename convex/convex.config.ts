import workpool from "@convex-dev/workpool/convex.config";
import { defineApp } from "convex/server";

const app = defineApp();

// Workpool for reveal transactions - maxParallelism: 1 ensures only one
// blockchain transaction runs at a time, preventing "Transaction already in mempool" errors
app.use(workpool, { name: "revealWorkpool" });

export default app;
