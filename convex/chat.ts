import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Get the nickname for a device ID
 */
export const getUserNickname = query({
	args: {
		deviceId: v.string(),
	},
	handler: async (ctx, args) => {
		const user = await ctx.db
			.query("chatUsers")
			.withIndex("by_device_id", (q) => q.eq("deviceId", args.deviceId))
			.first();

		return user?.nickname ?? null;
	},
});

/**
 * Set or update nickname for a device
 */
export const setNickname = mutation({
	args: {
		deviceId: v.string(),
		nickname: v.string(),
		walletAddress: v.optional(v.string()),
	},
	handler: async (ctx, args) => {
		// Validate nickname
		const trimmedNickname = args.nickname.trim();
		if (trimmedNickname.length < 2 || trimmedNickname.length > 20) {
			throw new Error("Nickname must be between 2 and 20 characters");
		}

		// Check if user already exists
		const existingUser = await ctx.db
			.query("chatUsers")
			.withIndex("by_device_id", (q) => q.eq("deviceId", args.deviceId))
			.first();

		if (existingUser) {
			// Update existing user
			await ctx.db.patch(existingUser._id, {
				nickname: trimmedNickname,
				walletAddress: args.walletAddress ?? existingUser.walletAddress,
			});
		} else {
			// Create new user
			await ctx.db.insert("chatUsers", {
				deviceId: args.deviceId,
				nickname: trimmedNickname,
				walletAddress: args.walletAddress,
				createdAt: Date.now(),
			});
		}

		return { success: true };
	},
});

/**
 * Send a chat message
 */
export const sendMessage = mutation({
	args: {
		deviceId: v.string(),
		collectionId: v.string(),
		message: v.string(),
	},
	handler: async (ctx, args) => {
		// Get user's nickname
		const user = await ctx.db
			.query("chatUsers")
			.withIndex("by_device_id", (q) => q.eq("deviceId", args.deviceId))
			.first();

		if (!user) {
			throw new Error("Please set a nickname before sending messages");
		}

		// Validate message
		const trimmedMessage = args.message.trim();
		if (trimmedMessage.length === 0) {
			throw new Error("Message cannot be empty");
		}
		if (trimmedMessage.length > 500) {
			throw new Error("Message cannot exceed 500 characters");
		}

		// Insert message
		await ctx.db.insert("chatMessages", {
			collectionId: args.collectionId,
			deviceId: args.deviceId,
			nickname: user.nickname, // Denormalized for display
			message: trimmedMessage,
			createdAt: Date.now(),
		});

		return { success: true };
	},
});

/**
 * Get chat messages for a collection (last 100, newest first)
 */
export const getMessages = query({
	args: {
		collectionId: v.string(),
	},
	handler: async (ctx, args) => {
		const messages = await ctx.db
			.query("chatMessages")
			.withIndex("by_collection_id", (q) => q.eq("collectionId", args.collectionId))
			.order("desc")
			.take(100);

		// Return in chronological order (oldest first) for display
		return messages.reverse();
	},
});

/**
 * Get latest chat messages across all collections (for home page feed)
 * Includes collection info for navigation
 */
export const getLatestMessages = query({
	args: {},
	handler: async (ctx) => {
		// Get all messages ordered by creation time (newest first)
		const messages = await ctx.db
			.query("chatMessages")
			.order("desc")
			.take(50);

		// Fetch collection info for each unique collection
		const collectionIds = [...new Set(messages.map((m) => m.collectionId))];
		const collections = await Promise.all(
			collectionIds.map((id) =>
				ctx.db
					.query("collections")
					.withIndex("by_collection_id", (q) => q.eq("collectionId", id))
					.first()
			)
		);

		// Create a map of collection info
		const collectionMap = new Map(
			collections
				.filter((c) => c !== null)
				.map((c) => [
					c.collectionId,
					{
						name: c.collectionName,
						// Active mint: deadline not passed and not sold out
						isActiveMint: !c.saleCompleted && c.saleDeadline > Math.floor(Date.now() / 1000),
					},
				])
		);

		// Enrich messages with collection info
		const enrichedMessages = messages.map((msg) => ({
			...msg,
			collectionName: collectionMap.get(msg.collectionId)?.name ?? "Unknown",
			isActiveMint: collectionMap.get(msg.collectionId)?.isActiveMint ?? false,
		}));

		// Return in chronological order (oldest first) for display
		return enrichedMessages.reverse();
	},
});

