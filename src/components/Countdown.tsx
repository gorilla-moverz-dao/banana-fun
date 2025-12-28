import { useEffect, useState } from "react";

interface CountdownProps {
	deadline: number; // Unix timestamp in seconds
	className?: string;
}

interface TimeLeft {
	days: number;
	hours: number;
	minutes: number;
	seconds: number;
	total: number;
}

function calculateTimeLeft(deadline: number): TimeLeft {
	const now = Math.floor(Date.now() / 1000);
	const total = deadline - now;

	if (total <= 0) {
		return { days: 0, hours: 0, minutes: 0, seconds: 0, total: 0 };
	}

	return {
		days: Math.floor(total / (60 * 60 * 24)),
		hours: Math.floor((total % (60 * 60 * 24)) / (60 * 60)),
		minutes: Math.floor((total % (60 * 60)) / 60),
		seconds: total % 60,
		total,
	};
}

export function Countdown({ deadline, className }: CountdownProps) {
	const [timeLeft, setTimeLeft] = useState<TimeLeft>(() => calculateTimeLeft(deadline));

	useEffect(() => {
		const timer = setInterval(() => {
			setTimeLeft(calculateTimeLeft(deadline));
		}, 1000);

		return () => clearInterval(timer);
	}, [deadline]);

	if (timeLeft.total <= 0) {
		return (
			<div className={className}>
				<span className="text-red-400">Sale ended</span>
			</div>
		);
	}

	return (
		<div className={className}>
			<span className="font-bold" style={{ textShadow: "0 1px 2px rgba(0,0,0,0.5)" }}>
				Sale ends in:{" "}
				{timeLeft.days > 0 && <span>{timeLeft.days}d </span>}
				<span>{String(timeLeft.hours).padStart(2, "0")}:</span>
				<span>{String(timeLeft.minutes).padStart(2, "0")}:</span>
				<span>{String(timeLeft.seconds).padStart(2, "0")}</span>
			</span>
		</div>
	);
}

