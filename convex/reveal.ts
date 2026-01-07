import { v } from "convex/values";
import { internalMutation, internalQuery, query } from "./_generated/server";

// Trait type definition for reuse
export const traitValidator = v.object({
	trait_type: v.string(),
	value: v.string(),
});

// Reveal item validator
export const revealItemValidator = v.object({
	name: v.string(),
	description: v.string(),
	uri: v.string(),
	traits: v.array(traitValidator),
});

/**
 * Internal mutation to insert a batch of reveal items
 * Convex limits mutations to ~8000 items, so we batch at 100 for safety
 */
export const uploadRevealDataBatch = internalMutation({
	args: {
		collectionId: v.string(),
		items: v.array(revealItemValidator),
	},
	handler: async (ctx, args) => {
		for (const item of args.items) {
			await ctx.db.insert("nftRevealItems", {
				collectionId: args.collectionId,
				name: item.name,
				description: item.description,
				uri: item.uri,
				traits: item.traits,
				revealed: false,
				nftTokenId: undefined,
			});
		}
		return args.items.length;
	},
});

/**
 * Internal mutation to mark an item as revealed and link to NFT token ID
 */
export const markRevealed = internalMutation({
	args: {
		itemId: v.id("nftRevealItems"),
		nftTokenId: v.string(),
		ownerAddress: v.optional(v.string()),
	},
	handler: async (ctx, args) => {
		await ctx.db.patch(args.itemId, {
			revealed: true,
			nftTokenId: args.nftTokenId,
			mintedAt: Date.now(),
			ownerAddress: args.ownerAddress,
		});
	},
});

/**
 * Internal query to get a random unrevealed item for a collection
 */
export const getRandomUnrevealedItem = internalQuery({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		// Get all unrevealed items for the collection (using prefix of by_collection_minted index)
		const unrevealedItems = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_collection_minted", (q) => q.eq("collectionId", args.collectionId).eq("revealed", false))
			.collect();

		if (unrevealedItems.length === 0) {
			return null;
		}

		// Pick a random item
		const randomIndex = Math.floor(Math.random() * unrevealedItems.length);
		return unrevealedItems[randomIndex];
	},
});

/**
 * Internal query to count all reveal items for a collection
 */
export const countRevealItems = internalQuery({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		// Using prefix of by_collection_minted index (just collectionId)
		const items = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_collection_minted", (q) => q.eq("collectionId", args.collectionId))
			.collect();

		return items.length;
	},
});

/**
 * Public query to get recent mints for a collection (last 20)
 */
export const getRecentMints = query({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		// Get revealed items ordered by mintedAt desc (most recent first)
		// The index is ["collectionId", "mintedAt"], so order("desc") sorts by mintedAt descending
		const items = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_collection_minted", (q) => q.eq("collectionId", args.collectionId).eq("revealed", true))
			.order("desc")
			.take(20);

		return items;
	},
});

/**
 * Public query to get recent mints across all collections (last 30)
 */
export const getAllRecentMints = query({
	args: {},
	handler: async (ctx) => {
		// Use index by_revealed_minted to efficiently query revealed items ordered by mintedAt
		const sortedItems = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_revealed_minted", (q) => q.eq("revealed", true))
			.order("desc")
			.take(30);

		// Enrich with collection info
		const itemsWithCollectionInfo = await Promise.all(
			sortedItems.map(async (item) => {
				const collection = await ctx.db
					.query("collections")
					.withIndex("by_collection_id", (q) => q.eq("collectionId", item.collectionId))
					.first();

				const now = Math.floor(Date.now() / 1000);
				const isActiveMint = collection && !collection.saleCompleted && now < collection.saleDeadline;

				return {
					...item,
					collectionName: collection?.collectionName || "Unknown Collection",
					isActiveMint: isActiveMint,
				};
			}),
		);

		return itemsWithCollectionInfo;
	},
});

/**
 * Internal query to get a revealed item by NFT token ID
 */
export const getRevealedItemByNftTokenId = internalQuery({
	args: {
		nftTokenId: v.string(),
	},
	handler: async (ctx, args) => {
		// Query all revealed items and filter - not ideal but works for now
		// TODO: Add an index by nftTokenId if this becomes a performance issue
		const items = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_revealed_minted", (q) => q.eq("revealed", true))
			.collect();

		return items.find((item) => item.nftTokenId === args.nftTokenId) || null;
	},
});
