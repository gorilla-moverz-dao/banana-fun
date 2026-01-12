import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "convex/react";
import { ArrowRight, Coins, Droplets, Rocket, Shield, Sparkles, Timer } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { ChatFeed } from "@/components/ChatFeed";
import { GlassCard } from "@/components/GlassCard";
import { LiveMintsFeed } from "@/components/LiveMintsFeed";
import { Button } from "@/components/ui/button";
import { searchDefaults } from "@/hooks/useCollectionSearch";
import { api } from "../../convex/_generated/api";

type FeaturedCollection = {
	collection_id: string;
	collection_name: string;
	description: string;
	uri: string;
	current_supply: number;
	max_supply: number;
};

function CollectionCard({ collection }: { collection: FeaturedCollection }) {
	const [isShaking, setIsShaking] = useState(false);
	const prevSupplyRef = useRef(collection.current_supply);

	useEffect(() => {
		if (prevSupplyRef.current !== collection.current_supply && prevSupplyRef.current < collection.current_supply) {
			setIsShaking(true);
			const timer = setTimeout(() => setIsShaking(false), 500);
			prevSupplyRef.current = collection.current_supply;
			return () => clearTimeout(timer);
		}
		prevSupplyRef.current = collection.current_supply;
	}, [collection.current_supply]);

	const progress = (collection.current_supply / collection.max_supply) * 100;

	return (
		<Link
			to="/collections/$collectionId"
			params={{ collectionId: collection.collection_id }}
			search={searchDefaults}
			className="block group"
		>
			<div
				className={`flex gap-4 p-3 rounded-lg bg-background/30 hover:bg-background/50 transition-colors border border-transparent hover:border-yellow-500/20 ${isShaking ? "animate-shake-mint" : ""}`}
			>
				<div className="w-20 h-20 flex-shrink-0 overflow-hidden rounded-lg border border-white/10">
					<img
						src={collection.uri}
						alt={collection.collection_name}
						className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-110"
						onError={(e) => {
							e.currentTarget.src = "/images/favicon-1.png";
						}}
					/>
				</div>
				<div className="flex-1 min-w-0 flex flex-col justify-center gap-1">
					<div className="flex items-center gap-2">
						<span className="font-semibold truncate" title={collection.collection_name}>
							{collection.collection_name}
						</span>
						{collection.current_supply < collection.max_supply && (
							<span className="text-[10px] px-1.5 py-0.5 rounded bg-green-500/90 text-white font-medium shrink-0">
								LIVE
							</span>
						)}
					</div>
					<p className="text-xs text-muted-foreground line-clamp-2">{collection.description}</p>
					<div className="flex items-center gap-3 mt-1">
						<div className="flex-1 h-1.5 bg-muted/30 rounded-full overflow-hidden">
							<div
								className="h-full bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full transition-all duration-500"
								style={{ width: `${progress}%` }}
							/>
						</div>
						<span className="text-xs text-muted-foreground whitespace-nowrap tabular-nums">
							{collection.current_supply}/{collection.max_supply}
						</span>
					</div>
				</div>
			</div>
		</Link>
	);
}

export const Route = createFileRoute("/")({
	component: HomePage,
});

function HomePage() {
	const collections = useQuery(api.collections.getCollectionsGrouped);

	const featuredCollections = collections?.ongoing?.slice(0, 3) ?? [];

	return (
		<div className="flex flex-col lg:flex-row gap-8">
			{/* Main Content - Left Column */}
			<div className="lg:w-2/3 lg:flex-shrink-0 space-y-8 pb-12">
				{/* Hero Section */}
				<GlassCard>
					<section className="flex flex-col md:flex-row items-center gap-6 px-4">
						<img src="/images/logo1.webp" alt="Banana Fun" className="w-2/3 md:w-1/3 object-contain" />
						<div>
							<p className="text-2xl text-muted-foreground">
								An NFT-backed token launchpad platform that combines NFT sales, token generation, and liquidity pool
								creation into a single streamlined mechanism. <br />
								Launch NFT collections while simultaneously bootstrapping token liquidity on decentralized exchanges.
							</p>
						</div>
					</section>
				</GlassCard>

				{/* How It Works */}
				<section>
					<h2 className="text-2xl font-bold mb-6 text-shadow-lg">How It Works</h2>
					<div className="grid gap-4 md:grid-cols-3">
						<GlassCard className="p-5 text-center">
							<div className="w-14 h-14 rounded-full bg-gradient-to-br from-yellow-400/20 to-orange-400/20 flex items-center justify-center mx-auto mb-3">
								<Sparkles className="w-7 h-7 text-yellow-400" />
							</div>
							<h3 className="font-semibold mb-2">1. Mint NFTs</h3>
							<p className="text-muted-foreground text-sm">
								Each NFT you own entitles you to a share of the token allocation.
							</p>
						</GlassCard>
						<GlassCard className="p-5 text-center">
							<div className="w-14 h-14 rounded-full bg-gradient-to-br from-blue-400/20 to-cyan-400/20 flex items-center justify-center mx-auto mb-3">
								<Droplets className="w-7 h-7 text-blue-400" />
							</div>
							<h3 className="font-semibold mb-2">2. Liquidity Created</h3>
							<p className="text-muted-foreground text-sm">
								Liquidity is automatically added to DEX pools when the sale completes.
							</p>
						</GlassCard>
						<GlassCard className="p-5 text-center">
							<div className="w-14 h-14 rounded-full bg-gradient-to-br from-green-400/20 to-emerald-400/20 flex items-center justify-center mx-auto mb-3">
								<Coins className="w-7 h-7 text-green-400" />
							</div>
							<h3 className="font-semibold mb-2">3. Claim Tokens</h3>
							<p className="text-muted-foreground text-sm">
								Claim your vested tokens over time. More NFTs = more tokens.
							</p>
						</GlassCard>
					</div>
				</section>

				{/* Key Features */}
				<section>
					<h2 className="text-2xl font-bold mb-6 text-shadow-lg">Why Banana Fun?</h2>
					<div className="grid gap-4 md:grid-cols-2">
						<GlassCard className="p-5">
							<div className="flex items-start gap-3">
								<div className="w-10 h-10 rounded-lg bg-gradient-to-br from-green-400/20 to-emerald-400/20 flex items-center justify-center flex-shrink-0">
									<Shield className="w-5 h-5 text-green-400" />
								</div>
								<div>
									<h3 className="font-semibold mb-1">Safe NFT & Token Launch</h3>
									<p className="text-muted-foreground text-sm">
										Refund by burning NFTs if a launch doesn't reach its target.
									</p>
								</div>
							</div>
						</GlassCard>
						<GlassCard className="p-5">
							<div className="flex items-start gap-3">
								<div className="w-10 h-10 rounded-lg bg-gradient-to-br from-purple-400/20 to-pink-400/20 flex items-center justify-center flex-shrink-0">
									<Sparkles className="w-5 h-5 text-purple-400" />
								</div>
								<div>
									<h3 className="font-semibold mb-1">Instant Reveal</h3>
									<p className="text-muted-foreground text-sm">
										NFTs reveal immediately. Evaluate quality from day one.
									</p>
								</div>
							</div>
						</GlassCard>
						<GlassCard className="p-5">
							<div className="flex items-start gap-3">
								<div className="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-400/20 to-cyan-400/20 flex items-center justify-center flex-shrink-0">
									<Droplets className="w-5 h-5 text-blue-400" />
								</div>
								<div>
									<h3 className="font-semibold mb-1">Auto Liquidity</h3>
									<p className="text-muted-foreground text-sm">50% of tokens go directly to DEX liquidity pools.</p>
								</div>
							</div>
						</GlassCard>
						<GlassCard className="p-5">
							<div className="flex items-start gap-3">
								<div className="w-10 h-10 rounded-lg bg-gradient-to-br from-orange-400/20 to-yellow-400/20 flex items-center justify-center flex-shrink-0">
									<Timer className="w-5 h-5 text-orange-400" />
								</div>
								<div>
									<h3 className="font-semibold mb-1">Fair Vesting</h3>
									<p className="text-muted-foreground text-sm">
										Tokens vest over time to prevent dumping and stabilize price.
									</p>
								</div>
							</div>
						</GlassCard>
					</div>
				</section>

				{/* Token Distribution */}
				<section>
					<h2 className="text-2xl font-bold mb-6 text-shadow-lg">Token Distribution</h2>
					<GlassCard className="p-6">
						<div className="space-y-4">
							<div className="flex items-center gap-4">
								<div className="w-4 h-4 rounded-full bg-blue-500" />
								<div className="flex-1">
									<div className="flex justify-between">
										<span className="font-medium">Liquidity Pool (DEX)</span>
										<span className="text-muted-foreground">50%</span>
									</div>
									<div className="w-full bg-muted/30 rounded-full h-2 mt-1">
										<div className="bg-blue-500 h-2 rounded-full" style={{ width: "50%" }} />
									</div>
								</div>
							</div>
							<div className="flex items-center gap-4">
								<div className="w-4 h-4 rounded-full bg-orange-500" />
								<div className="flex-1">
									<div className="flex justify-between">
										<span className="font-medium">Team Vesting</span>
										<span className="text-muted-foreground">30%</span>
									</div>
									<div className="w-full bg-muted/30 rounded-full h-2 mt-1">
										<div className="bg-orange-500 h-2 rounded-full" style={{ width: "30%" }} />
									</div>
								</div>
							</div>
							<div className="flex items-center gap-4">
								<div className="w-4 h-4 rounded-full bg-green-500" />
								<div className="flex-1">
									<div className="flex justify-between">
										<span className="font-medium">NFT Holder Vesting</span>
										<span className="text-muted-foreground">10%</span>
									</div>
									<div className="w-full bg-muted/30 rounded-full h-2 mt-1">
										<div className="bg-green-500 h-2 rounded-full" style={{ width: "10%" }} />
									</div>
								</div>
							</div>
							<div className="flex items-center gap-4">
								<div className="w-4 h-4 rounded-full bg-purple-500" />
								<div className="flex-1">
									<div className="flex justify-between">
										<span className="font-medium">Dev Wallet (Airdrops)</span>
										<span className="text-muted-foreground">10%</span>
									</div>
									<div className="w-full bg-muted/30 rounded-full h-2 mt-1">
										<div className="bg-purple-500 h-2 rounded-full" style={{ width: "10%" }} />
									</div>
								</div>
							</div>
						</div>
					</GlassCard>
				</section>
			</div>

			{/* Active Launches - Right Column */}
			<div className="lg:w-1/3 lg:flex-shrink-0">
				<div>
					{/* Prominent Active Launches Card */}
					<GlassCard className="p-5 border-yellow-500/30 bg-gradient-to-br from-yellow-500/5 to-orange-500/5 gap-1">
						<div className="flex items-center justify-between mb-4">
							<div className="flex items-center gap-2">
								<div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
								<h2 className="text-lg font-bold">Active Launches</h2>
							</div>
							<Link
								to="/collections"
								className="text-yellow-400 hover:text-yellow-300 flex items-center gap-1 text-xs font-medium"
							>
								View all <ArrowRight className="w-3 h-3" />
							</Link>
						</div>

						{featuredCollections.length > 0 ? (
							<div className="space-y-3">
								{featuredCollections.map((collection) => (
									<CollectionCard key={collection.collection_id} collection={collection} />
								))}
							</div>
						) : (
							<div className="text-center py-4">
								<p className="text-muted-foreground text-sm">No active launches</p>
							</div>
						)}

						{/* Integrated CTA */}
						<Link to="/collections" className="block mt-4">
							<Button
								size="sm"
								className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600 text-sm h-9"
							>
								<Rocket className="w-3.5 h-3.5 mr-1.5" />
								Browse All Launches
							</Button>
						</Link>
					</GlassCard>

					{/* Live Chat Feed */}
					<div className="mt-4">
						<ChatFeed />
					</div>

					{/* Live Mints Feed */}
					<div className="mt-4">
						<LiveMintsFeed />
					</div>
				</div>
			</div>
		</div>
	);
}
