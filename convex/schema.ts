import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
	collections: defineTable({
		// Basic collection info (from indexer/DAS)
		collectionId: v.string(), // Object address of the collection
		collectionName: v.string(),
		description: v.string(),
		uri: v.string(),
		placeholderUri: v.string(),
		creatorAddress: v.string(),
		royaltyAddress: v.string(),
		royaltyPercentage: v.optional(v.number()),
		maxSupply: v.number(),
		currentSupply: v.number(), // Updated from indexer
		ownerCount: v.optional(v.number()), // Number of unique owners
		mintEnabled: v.boolean(),

		// Sale configuration
		saleDeadline: v.number(), // Unix timestamp in seconds
		saleCompleted: v.boolean(),
		totalFundsCollected: v.optional(v.number()), // In smallest unit (8 decimals)
		devWalletAddress: v.optional(v.string()),

		// Fungible Asset (FA) configuration
		// These are set when collection is created
		faSymbol: v.string(),
		faName: v.string(),
		faIconUri: v.string(),
		faProjectUri: v.string(),

		// FA information (set when sale is completed)
		faMetadataAddress: v.optional(v.string()), // Object address of FA metadata
		faTotalMinted: v.optional(v.number()), // Total FA tokens minted (1B * 10^9)
		faLpAmount: v.optional(v.number()), // Amount allocated to liquidity pool (50%)
		faVestingAmount: v.optional(v.number()), // Amount for NFT holder vesting (10%)
		faDevWalletAmount: v.optional(v.number()), // Amount sent to dev wallet (10%)
		faCreatorVestingAmount: v.optional(v.number()), // Amount for creator vesting (30%)

		// NFT Holder Vesting configuration
		vestingCliff: v.optional(v.number()), // Cliff period in seconds
		vestingDuration: v.optional(v.number()), // Total vesting duration in seconds

		// Creator Vesting configuration
		creatorVestingWalletAddress: v.optional(v.string()),
		creatorVestingCliff: v.optional(v.number()), // Cliff period in seconds
		creatorVestingDuration: v.optional(v.number()), // Total vesting duration in seconds

		// Timestamps
		createdAt: v.number(), // When collection was created
		updatedAt: v.number(), // Last update timestamp
	})
		.index("by_collection_id", ["collectionId"])
		.index("by_creator", ["creatorAddress"])
		.index("by_state", ["saleCompleted", "mintEnabled"]),
        
	mintStages: defineTable({
		collectionId: v.string(), // Reference to collection
		name: v.string(), // Stage name
		mintFee: v.number(), // Base mint fee per NFT (in smallest unit)
		startTime: v.number(), // Unix timestamp in seconds
		endTime: v.number(), // Unix timestamp in seconds
		stageType: v.number(), // 1 = allowlist, 2 = public
		mintLimitPerAddr: v.optional(v.number()), // Max mints per address for this stage
		updatedAt: v.number(), // Last update timestamp
	})
		.index("by_collection_id", ["collectionId"])
		.index("by_collection_and_name", ["collectionId", "name"]),
});
