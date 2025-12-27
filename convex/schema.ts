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

		// NFT Holder Vesting configuration (from launchpad)
		vestingCliff: v.number(), // Cliff period in seconds
		vestingDuration: v.number(), // Total vesting duration in seconds
		// NFT Holder Vesting actual values (from vesting contract, set after sale completion)
		vestingStartTime: v.optional(v.number()), // Actual vesting start time from contract
		vestingTotalPool: v.optional(v.number()), // Actual total pool from contract
		vestingAmountPerNft: v.optional(v.number()), // Amount per NFT from contract

		// Creator Vesting configuration (from launchpad)
		creatorVestingWalletAddress: v.string(),
		creatorVestingCliff: v.number(), // Cliff period in seconds
		creatorVestingDuration: v.number(), // Total vesting duration in seconds
		// Creator Vesting actual values (from vesting contract, set after sale completion)
		creatorVestingStartTime: v.optional(v.number()), // Actual vesting start time from contract
		creatorVestingTotalPool: v.optional(v.number()), // Actual total pool from contract

		// Refund tracking (for failed launches)
		refundNftsBurned: v.optional(v.number()), // Number of NFTs burned for refunds
		refundTotalAmount: v.optional(v.number()), // Total MOVE amount refunded

		// Timestamps
		createdAt: v.number(), // When collection was created
		updatedAt: v.number(), // Last update timestamp
	})
		.index("by_collection_id", ["collectionId"])
		.index("by_state", ["saleCompleted", "mintEnabled"])
		.index("by_mint_enabled", ["mintEnabled"]),

	mintStages: defineTable({
		collectionId: v.string(), // Reference to collection
		name: v.string(), // Stage name
		mintFee: v.number(), // Base mint fee per NFT (in smallest unit)
		startTime: v.number(), // Unix timestamp in seconds
		endTime: v.number(), // Unix timestamp in seconds
		stageType: v.number(), // 1 = allowlist, 2 = public
		mintLimitPerAddr: v.optional(v.number()), // Max mints per address for this stage
		updatedAt: v.number(), // Last update timestamp
	}).index("by_collection_id", ["collectionId"]),

	// NFT reveal data - stores metadata for unrevealed NFTs
	nftRevealItems: defineTable({
		collectionId: v.string(), // Reference to collection
		name: v.string(),
		description: v.string(),
		uri: v.string(),
		traits: v.array(
			v.object({
				trait_type: v.string(),
				value: v.string(),
			}),
		),
		revealed: v.boolean(), // Whether assigned to an NFT
		nftTokenId: v.optional(v.string()), // Token ID after reveal
	})
		.index("by_collection_id", ["collectionId"])
		.index("by_collection_unrevealed", ["collectionId", "revealed"]),
});
