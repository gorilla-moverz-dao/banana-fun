import { Link } from "@tanstack/react-router";
import { Home, Info, Menu, Rocket, X } from "lucide-react";
import { useEffect, useState } from "react";
import { WalletSelector } from "@/components/WalletSelector";

export default function Header() {
	const [isOpen, setIsOpen] = useState(false);
	const [isScrolled, setIsScrolled] = useState(false);

	useEffect(() => {
		const handleScroll = () => {
			setIsScrolled(window.scrollY > 10);
		};

		window.addEventListener("scroll", handleScroll, { passive: true });
		return () => window.removeEventListener("scroll", handleScroll);
	}, []);

	const links = [
		{
			label: "Home",
			to: "/",
			icon: Home,
		},
		{
			label: "Launches",
			to: "/collections",
			icon: Rocket,
		},
		{
			label: "About",
			to: "/about",
			icon: Info,
		},
	];

	return (
		<>
			<header
				className={`sticky top-0 p-4 flex items-center text-white z-50 overflow-x-hidden transition-all duration-300 ${
					isScrolled ? "bg-black/30 backdrop-blur-xl shadow-lg" : "bg-black/30"
				}`}
			>
				<div className="flex w-full max-w-7xl mx-auto items-center gap-2 md:gap-4 min-w-0">
					<button
						type="button"
						onClick={() => setIsOpen(true)}
						className="p-2 hover:bg-white/10 rounded-lg transition-colors md:hidden flex-shrink-0"
						aria-label="Open menu"
					>
						<Menu size={24} />
					</button>

					<Link
						to="/"
						className="text-xl md:text-4xl font-bold truncate min-w-0 flex-shrink-0 bg-gradient-to-r from-yellow-400 via-orange-400 to-yellow-500 bg-clip-text text-transparent"
					>
						BANANA FUN
					</Link>
					<div className="hidden md:flex flex-1 items-center gap-2 justify-center">
						{links.map((link) => (
							<Link
								key={link.to}
								to={link.to}
								className="flex items-center gap-2 p-2 rounded-lg hover:bg-white/10 transition-colors"
								activeProps={{
									className:
										"flex items-center gap-2 bg-yellow-500/80 hover:bg-yellow-500/90 transition-colors shadow-lg",
								}}
							>
								<link.icon size={20} />
								<span className="font-medium">{link.label}</span>
							</Link>
						))}
					</div>
					<div className="ml-auto flex-shrink-0">
						<WalletSelector />
					</div>
				</div>
			</header>

			<aside
				className={`fixed top-0 left-0 h-full w-80 bg-black/50 backdrop-blur-xl text-white shadow-2xl z-50 transform transition-transform duration-300 ease-in-out flex flex-col ${
					isOpen ? "translate-x-0" : "-translate-x-full"
				}`}
			>
				<div className="flex items-center justify-between p-4 border-b border-white/20">
					<h2 className="text-xl font-bold">Navigation</h2>
					<button
						type="button"
						onClick={() => setIsOpen(false)}
						className="p-2 hover:bg-white/10 rounded-lg transition-colors"
						aria-label="Close menu"
					>
						<X size={24} />
					</button>
				</div>

				<nav className="flex-1 p-4 overflow-y-auto">
					{links.map((link) => (
						<Link
							key={link.to}
							to={link.to}
							onClick={() => setIsOpen(false)}
							className="flex items-center gap-3 p-3 rounded-lg hover:bg-white/10 transition-colors mb-2"
							activeProps={{
								className:
									"flex items-center gap-3 p-3 rounded-lg bg-yellow-500/80 hover:bg-yellow-500/90 transition-colors mb-2 shadow-lg",
							}}
						>
							<link.icon size={20} />
							<span className="font-medium">{link.label}</span>
						</Link>
					))}
				</nav>
			</aside>
		</>
	);
}
