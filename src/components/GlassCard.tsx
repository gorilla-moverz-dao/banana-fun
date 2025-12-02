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
				// Brighter glassmorphism styles
				"backdrop-blur-lg bg-white/10 dark:bg-white/5 border border-white/20 shadow-xl",
				hoverEffect && "hover:bg-white/20 dark:hover:bg-white/10",
				"transition-all duration-200",
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
