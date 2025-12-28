import { createFileRoute } from "@tanstack/react-router";
import { CheckCircle2, Clock, Coins, Rocket, Shield, Users, XCircle, Zap } from "lucide-react";
import mermaid from "mermaid";
import { useEffect, useId, useRef, useState } from "react";
import { GlassCard } from "@/components/GlassCard";
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export const Route = createFileRoute("/about")({
	component: AboutPage,
});

// Mermaid will be initialized inside the component

const SALES_FLOW_DIAGRAM = `
flowchart TB
    A["👤 Creator Creates Collection"] --> B["📋 Configure Settings"]
    B --> C["🎯 Define Mint Stages"]
    C --> D{"🔓 Enable Mint"}
    D -->|Yes| E["✅ Mint Active"]
    D -->|No| D
    
    E --> F["🎨 Users Mint NFTs"]
    F --> G["💵 Funds Collected"]
    G --> H{"Max Supply Reached?"}
    
    H -->|Yes| I["🏁 Complete Sale"]
    H -->|No| J{"Deadline Passed?"}
    J -->|No| F
    J -->|Yes| K["❌ Sale Failed"]
    
    I --> L["🪙 Create Token"]
    L --> M["💱 Create DEX Pool"]
    M --> N["⏰ Init Vesting"]
    N --> O["🎉 SUCCESS"]
    
    K --> P["🔥 Users Reclaim"]
    P --> Q["📤 Burn NFT"]
    Q --> R["💰 Get Refund"]
    R --> S["❌ REFUNDED"]
    
    style O fill:#22c55e,color:#fff
    style S fill:#ef4444,color:#fff
    style I fill:#3b82f6,color:#fff
    style K fill:#f97316,color:#fff
`;

function MermaidDiagram({ chart }: { chart: string }) {
	const containerRef = useRef<HTMLDivElement>(null);
	const [svgContent, setSvgContent] = useState<string>("");
	const uniqueId = useId().replace(/:/g, "-");

	useEffect(() => {
		let isMounted = true;

		const renderDiagram = async () => {
			try {
				// Initialize mermaid each time to ensure clean state
				mermaid.initialize({
					startOnLoad: false,
					theme: "dark",
					securityLevel: "loose",
					themeVariables: {
						primaryColor: "#f0b429",
						primaryTextColor: "#e6edf3",
						primaryBorderColor: "#f0b429",
						lineColor: "#8b949e",
						secondaryColor: "#161b22",
						tertiaryColor: "#0d1117",
						background: "transparent",
						mainBkg: "#1a1f2e",
						nodeBorder: "#f0b429",
						clusterBkg: "rgba(240, 180, 41, 0.1)",
						clusterBorder: "#f0b429",
						defaultLinkColor: "#8b949e",
						titleColor: "#e6edf3",
						edgeLabelBackground: "transparent",
						nodeTextColor: "#e6edf3",
					},
					flowchart: {
						htmlLabels: true,
						curve: "basis",
						padding: 15,
						nodeSpacing: 40,
						rankSpacing: 50,
					},
				});

				const { svg } = await mermaid.render(`mermaid-${uniqueId}-${Date.now()}`, chart);
				if (isMounted) {
					setSvgContent(svg);
				}
			} catch (error) {
				console.error("Mermaid render error:", error);
				if (isMounted) {
					setSvgContent('<p class="text-red-400 text-center py-8">Failed to render diagram</p>');
				}
			}
		};

		renderDiagram();

		return () => {
			isMounted = false;
		};
	}, [chart, uniqueId]);

	return (
		<div
			ref={containerRef}
			className="flex justify-center overflow-x-auto py-4 [&_svg]:max-w-full"
			// biome-ignore lint/security/noDangerouslySetInnerHtml: Mermaid SVG output
			dangerouslySetInnerHTML={{ __html: svgContent }}
		/>
	);
}

function AboutPage() {
	return (
		<div className="flex flex-col gap-8 max-w-6xl mx-auto">
			{/* What is Banana Fun */}
			<GlassCard>
				<CardHeader>
					<CardTitle className="flex items-center gap-2 text-2xl">
						<Rocket className="w-6 h-6 text-yellow-400" />
						What is Banana Fun?
					</CardTitle>
				</CardHeader>
				<CardContent className="space-y-4 text-muted-foreground">
					<p>
						Banana Fun is an innovative NFT-based token launchpad that combines NFT sales, token generation, and
						community bootstrapping into a single mechanism.
					</p>
					<p>
						NFTs act as both <strong className="text-foreground">fundraising instruments</strong> and{" "}
						<strong className="text-foreground">access keys</strong> for token distribution.
					</p>
				</CardContent>
			</GlassCard>

			{/* Key Features */}
			<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
				<GlassCard>
					<CardContent className="pt-6 text-center">
						<Shield className="w-10 h-10 text-green-400 mx-auto mb-3" />
						<h3 className="font-semibold mb-2">Safe Presale</h3>
						<p className="text-sm text-muted-foreground">Full refund if sale doesn't reach target</p>
					</CardContent>
				</GlassCard>

				<GlassCard>
					<CardContent className="pt-6 text-center">
						<Zap className="w-10 h-10 text-yellow-400 mx-auto mb-3" />
						<h3 className="font-semibold mb-2">Instant Launch</h3>
						<p className="text-sm text-muted-foreground">NFT + Token launch simultaneously</p>
					</CardContent>
				</GlassCard>

				<GlassCard>
					<CardContent className="pt-6 text-center">
						<Coins className="w-10 h-10 text-blue-400 mx-auto mb-3" />
						<h3 className="font-semibold mb-2">Auto Liquidity</h3>
						<p className="text-sm text-muted-foreground">DEX pool created automatically</p>
					</CardContent>
				</GlassCard>

				<GlassCard>
					<CardContent className="pt-6 text-center">
						<Clock className="w-10 h-10 text-purple-400 mx-auto mb-3" />
						<h3 className="font-semibold mb-2">Vesting</h3>
						<p className="text-sm text-muted-foreground">Linear token unlock over time</p>
					</CardContent>
				</GlassCard>
			</div>

			{/* Sales Flow Diagram */}
			<GlassCard>
				<CardHeader>
					<CardTitle className="text-2xl">Sales Process Flow</CardTitle>
					<CardDescription>How an NFT launch progresses from creation to completion</CardDescription>
				</CardHeader>
				<CardContent>
					<MermaidDiagram chart={SALES_FLOW_DIAGRAM} />
				</CardContent>
			</GlassCard>

			{/* Outcome Paths */}
			<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
				{/* Success Path */}
				<GlassCard className="border-l-4 border-l-green-500">
					<CardHeader>
						<CardTitle className="flex items-center gap-2 text-green-400">
							<CheckCircle2 className="w-5 h-5" />
							Success Path
						</CardTitle>
						<CardDescription>When max supply is reached before deadline</CardDescription>
					</CardHeader>
					<CardContent className="space-y-3">
						<div className="space-y-2 text-sm">
							<div className="flex items-start gap-2">
								<span className="text-green-400 font-bold">1.</span>
								<span>Fungible token created (1B supply)</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-green-400 font-bold">2.</span>
								<span>DEX liquidity pool created with MOVE</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-green-400 font-bold">3.</span>
								<span>Vesting contracts initialized</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-green-400 font-bold">4.</span>
								<span>Holders can claim vested tokens</span>
							</div>
						</div>

						<div className="mt-4 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
							<h4 className="font-semibold text-green-400 mb-2">Token Distribution</h4>
							<div className="grid grid-cols-2 gap-2 text-sm">
								<div>
									<span className="text-muted-foreground">DEX LP:</span> 50%
								</div>
								<div>
									<span className="text-muted-foreground">Creator:</span> 30%
								</div>
								<div>
									<span className="text-muted-foreground">Holders:</span> 10%
								</div>
								<div>
									<span className="text-muted-foreground">Dev:</span> 10%
								</div>
							</div>
						</div>
					</CardContent>
				</GlassCard>

				{/* Failure Path */}
				<GlassCard className="border-l-4 border-l-red-500">
					<CardHeader>
						<CardTitle className="flex items-center gap-2 text-red-400">
							<XCircle className="w-5 h-5" />
							Failure Path
						</CardTitle>
						<CardDescription>When deadline passes without selling out</CardDescription>
					</CardHeader>
					<CardContent className="space-y-3">
						<div className="space-y-2 text-sm">
							<div className="flex items-start gap-2">
								<span className="text-red-400 font-bold">1.</span>
								<span>Deadline passes, target not met</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-red-400 font-bold">2.</span>
								<span>
									Users call <code className="bg-red-500/20 px-1 rounded">reclaim_funds()</code>
								</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-red-400 font-bold">3.</span>
								<span>Submit NFT as proof of purchase</span>
							</div>
							<div className="flex items-start gap-2">
								<span className="text-red-400 font-bold">4.</span>
								<span>NFT burned, MOVE refunded</span>
							</div>
						</div>

						<div className="mt-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
							<h4 className="font-semibold text-red-400 mb-2">Refund Details</h4>
							<ul className="text-sm space-y-1 text-muted-foreground">
								<li>• Mint fee is fully refunded</li>
								<li>• Protocol fees are NOT refunded</li>
								<li>• Each NFT can only be refunded once</li>
							</ul>
						</div>
					</CardContent>
				</GlassCard>
			</div>

			{/* How to Participate */}
			<GlassCard>
				<CardHeader>
					<CardTitle className="flex items-center gap-2 text-2xl">
						<Users className="w-6 h-6 text-blue-400" />
						How to Participate
					</CardTitle>
				</CardHeader>
				<CardContent>
					<div className="grid grid-cols-1 md:grid-cols-3 gap-6">
						<div className="text-center space-y-2">
							<div className="w-12 h-12 rounded-full bg-yellow-500/20 flex items-center justify-center mx-auto text-2xl font-bold text-yellow-400">
								1
							</div>
							<h3 className="font-semibold">Connect Wallet</h3>
							<p className="text-sm text-muted-foreground">Connect your Movement-compatible wallet</p>
						</div>

						<div className="text-center space-y-2">
							<div className="w-12 h-12 rounded-full bg-yellow-500/20 flex items-center justify-center mx-auto text-2xl font-bold text-yellow-400">
								2
							</div>
							<h3 className="font-semibold">Mint NFTs</h3>
							<p className="text-sm text-muted-foreground">Pay MOVE to mint NFTs during active stages</p>
						</div>

						<div className="text-center space-y-2">
							<div className="w-12 h-12 rounded-full bg-yellow-500/20 flex items-center justify-center mx-auto text-2xl font-bold text-yellow-400">
								3
							</div>
							<h3 className="font-semibold">Claim or Refund</h3>
							<p className="text-sm text-muted-foreground">Success: claim tokens • Failure: get refund</p>
						</div>
					</div>
				</CardContent>
			</GlassCard>
		</div>
	);
}
