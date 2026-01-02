import { Link } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { MessageCircle } from "lucide-react";
import { useEffect, useRef } from "react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { api } from "../../convex/_generated/api";

/**
 * Read-only chat feed showing latest messages across all collections
 */
export function ChatFeed() {
	const messages = useQuery(api.chat.getLatestMessages);
	const containerRef = useRef<HTMLDivElement>(null);

	// Auto-scroll to bottom within the container when messages change
	useEffect(() => {
		if (messages && messages.length > 0 && containerRef.current) {
			containerRef.current.scrollTop = containerRef.current.scrollHeight;
		}
	}, [messages]);

	const formatTime = (timestamp: number) => {
		const date = new Date(timestamp);
		const now = new Date();
		const isToday = date.toDateString() === now.toDateString();

		if (isToday) {
			return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
		}
		return (
			date.toLocaleDateString([], { month: "short", day: "numeric" }) +
			" " +
			date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
		);
	};

	return (
		<GlassCard className="gap-1">
			<CardHeader className="pb-2">
				<CardTitle className="flex items-center gap-2 text-lg">
					<MessageCircle className="w-5 h-5" />
					Live Chat
				</CardTitle>
			</CardHeader>
			<CardContent>
				<div ref={containerRef} className="h-48 overflow-y-auto rounded-lg bg-black/20 p-3 space-y-2">
					{messages?.length === 0 && (
						<div className="flex items-center justify-center h-full text-muted-foreground text-sm">No messages yet</div>
					)}
					{messages?.map((msg) => (
						<Link
							key={msg._id}
							to={msg.isActiveMint ? "/mint/$collectionId" : "/collections/$collectionId"}
							params={{ collectionId: msg.collectionId }}
							className="block text-sm rounded-md px-2 py-1 -mx-2 hover:bg-white/10 transition-colors cursor-pointer"
						>
							<div className="flex items-center gap-2 flex-wrap">
								<span className="text-yellow-400 font-semibold">{msg.nickname}</span>
								<span className="text-muted-foreground text-xs">{formatTime(msg.createdAt)}</span>
								<span className="text-xs text-primary/70 truncate">in {msg.collectionName}</span>
							</div>
							<p className="text-foreground/90 break-words">{msg.message}</p>
						</Link>
					))}
				</div>
			</CardContent>
		</GlassCard>
	);
}
