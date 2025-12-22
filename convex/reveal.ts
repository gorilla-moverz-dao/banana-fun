import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";

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
	},
	handler: async (ctx, args) => {
		await ctx.db.patch(args.itemId, {
			revealed: true,
			nftTokenId: args.nftTokenId,
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
		// Get all unrevealed items for the collection
		const unrevealedItems = await ctx.db
			.query("nftRevealItems")
			.withIndex("by_collection_unrevealed", (q) => q.eq("collectionId", args.collectionId).eq("revealed", false))
			.collect();

		if (unrevealedItems.length === 0) {
			return null;
		}

		// Pick a random item
		const randomIndex = Math.floor(Math.random() * unrevealedItems.length);
		return unrevealedItems[randomIndex];
	},
});
