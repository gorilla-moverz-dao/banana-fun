import React from "react";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * GlassCard - A reusable card with glassmorphism (frosted glass) effect.
 * Wraps the existing Card component and applies glassy styles.
 */
interface GlassCardProps extends React.ComponentProps<"div"> {
	hoverEffect?: boolean;
}

const GlassCard = React.forwardRef<HTMLDivElement, GlassCardProps>(
	({ className, children, hoverEffect = false, ...props }, ref) => (
		<Card
			ref={ref}
			className={cn(
				// Glassmorphism styles with flicker prevention:
				// - border-none + border-transparent ensures no border rendering at all
				// - ring-0 removes any ring
				// - Use inset box-shadow for the border effect instead (more stable with backdrop-blur)
				// - isolation-isolate creates a new stacking context to prevent compositing issues
				"backdrop-blur-lg bg-white/10 dark:bg-white/5",
				"border-none border-transparent ring-0 outline-none",
				"shadow-[inset_0_0_0_1px_rgba(255,255,255,0.2),0_25px_50px_-12px_rgba(0,0,0,0.25)]",
				"isolate transform-gpu",
				hoverEffect && "hover:bg-white/20 dark:hover:bg-white/10",
				"transition-[background-color] duration-200",
				className,
			)}
			{...props}
		>
			{children}
		</Card>
	),
);
GlassCard.displayName = "GlassCard";

export { GlassCard };
