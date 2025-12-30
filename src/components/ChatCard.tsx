import { useMutation, useQuery } from "convex/react";
import { MessageCircle, Send, User } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { api } from "../../convex/_generated/api";
import { useClients } from "@/hooks/useClients";
import { useDeviceId } from "@/hooks/useDeviceId";
import { Button } from "@/components/ui/button";
import {
	Dialog,
	DialogContent,
	DialogDescription,
	DialogFooter,
	DialogHeader,
	DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface ChatCardProps {
	collectionId: string;
}

export function ChatCard({ collectionId }: ChatCardProps) {
	const deviceId = useDeviceId();
	const { address } = useClients();
	const [message, setMessage] = useState("");
	const [nicknameInput, setNicknameInput] = useState("");
	const [showNicknameDialog, setShowNicknameDialog] = useState(false);
	const [isSubmitting, setIsSubmitting] = useState(false);
	const containerRef = useRef<HTMLDivElement>(null);

	// Convex queries and mutations
	const nickname = useQuery(
		api.chat.getUserNickname,
		deviceId ? { deviceId } : "skip",
	);
	const messages = useQuery(api.chat.getMessages, { collectionId });
	const setNicknameMutation = useMutation(api.chat.setNickname);
	const sendMessageMutation = useMutation(api.chat.sendMessage);

	// Auto-scroll to bottom within the container when new messages arrive
	useEffect(() => {
		if (messages && messages.length > 0 && containerRef.current) {
			containerRef.current.scrollTop = containerRef.current.scrollHeight;
		}
	}, [messages]);

	const handleSendMessage = async () => {
		if (!deviceId || !message.trim()) return;

		// If no nickname, show dialog first
		if (!nickname) {
			setShowNicknameDialog(true);
			return;
		}

		setIsSubmitting(true);
		try {
			await sendMessageMutation({
				deviceId,
				collectionId,
				message: message.trim(),
			});
			setMessage("");
		} catch (error) {
			console.error("Failed to send message:", error);
		} finally {
			setIsSubmitting(false);
		}
	};

	const handleSetNickname = async () => {
		if (!deviceId || !nicknameInput.trim()) return;

		setIsSubmitting(true);
		try {
			await setNicknameMutation({
				deviceId,
				nickname: nicknameInput.trim(),
				walletAddress: address,
			});
			setShowNicknameDialog(false);
			setNicknameInput("");
			// After setting nickname, send the pending message if any
			if (message.trim()) {
				await sendMessageMutation({
					deviceId,
					collectionId,
					message: message.trim(),
				});
				setMessage("");
			}
		} catch (error) {
			console.error("Failed to set nickname:", error);
		} finally {
			setIsSubmitting(false);
		}
	};

	const handleKeyDown = (e: React.KeyboardEvent) => {
		if (e.key === "Enter" && !e.shiftKey) {
			e.preventDefault();
			handleSendMessage();
		}
	};

	const handleNicknameKeyDown = (e: React.KeyboardEvent) => {
		if (e.key === "Enter") {
			e.preventDefault();
			handleSetNickname();
		}
	};

	const formatTime = (timestamp: number) => {
		const date = new Date(timestamp);
		return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
	};

	if (!deviceId) {
		return null; // Wait for device ID to load
	}

	return (
		<>
			<GlassCard>
				<CardHeader>
					<CardTitle className="flex items-center gap-2 text-lg">
						<MessageCircle className="w-5 h-5" />
						Chat
						{nickname && (
							<span className="text-sm font-normal text-muted-foreground ml-auto">
								Chatting as <span className="font-medium text-foreground">{nickname}</span>
							</span>
						)}
					</CardTitle>
				</CardHeader>
				<CardContent className="space-y-4">
					{/* Messages Container */}
					<div ref={containerRef} className="h-64 overflow-y-auto rounded-lg bg-black/20 p-3 space-y-2">
						{messages?.length === 0 && (
							<div className="flex items-center justify-center h-full text-muted-foreground text-sm">
								No messages yet. Be the first to say something!
							</div>
						)}
						{messages?.map((msg) => (
							<div
								key={msg._id}
								className={`flex flex-col ${
									msg.deviceId === deviceId ? "items-end" : "items-start"
								}`}
							>
								<div
									className={`max-w-[80%] rounded-lg px-3 py-2 ${
										msg.deviceId === deviceId
											? "bg-yellow-500/30 text-foreground"
											: "bg-white/10 text-foreground"
									}`}
								>
									<div className="flex items-center gap-2 mb-1">
										<span className="text-xs font-semibold text-yellow-400">
											{msg.nickname}
										</span>
										<span className="text-xs text-muted-foreground">
											{formatTime(msg.createdAt)}
										</span>
									</div>
									<p className="text-sm break-words">{msg.message}</p>
								</div>
							</div>
						))}
					</div>

					{/* Input Area */}
					<div className="flex gap-2">
						<Input
							placeholder={nickname ? "Type a message..." : "Set nickname to chat"}
							value={message}
							onChange={(e) => setMessage(e.target.value)}
							onKeyDown={handleKeyDown}
							className="flex-1 bg-black/20 border-white/20"
							maxLength={500}
						/>
						<Button
							onClick={handleSendMessage}
							disabled={!message.trim() || isSubmitting}
							className="bg-yellow-500 hover:bg-yellow-600 text-black"
						>
							<Send className="w-4 h-4" />
						</Button>
					</div>

					{/* Set Nickname Button (if not set) */}
					{!nickname && (
						<Button
							variant="outline"
							onClick={() => setShowNicknameDialog(true)}
							className="w-full"
						>
							<User className="w-4 h-4 mr-2" />
							Set Nickname to Chat
						</Button>
					)}
				</CardContent>
			</GlassCard>

			{/* Nickname Dialog */}
			<Dialog open={showNicknameDialog} onOpenChange={setShowNicknameDialog}>
				<DialogContent>
					<DialogHeader>
						<DialogTitle>Set Your Nickname</DialogTitle>
						<DialogDescription>
							Choose a nickname to display in the chat. This will be visible to
							other users.
						</DialogDescription>
					</DialogHeader>
					<div className="py-4">
						<Input
							placeholder="Enter nickname (2-20 characters)"
							value={nicknameInput}
							onChange={(e) => setNicknameInput(e.target.value)}
							onKeyDown={handleNicknameKeyDown}
							maxLength={20}
							autoFocus
						/>
					</div>
					<DialogFooter>
						<Button
							variant="outline"
							onClick={() => setShowNicknameDialog(false)}
						>
							Cancel
						</Button>
						<Button
							onClick={handleSetNickname}
							disabled={
								nicknameInput.trim().length < 2 ||
								nicknameInput.trim().length > 20 ||
								isSubmitting
							}
							className="bg-yellow-500 hover:bg-yellow-600 text-black"
						>
							{isSubmitting ? "Setting..." : "Set Nickname"}
						</Button>
					</DialogFooter>
				</DialogContent>
			</Dialog>
		</>
	);
}

