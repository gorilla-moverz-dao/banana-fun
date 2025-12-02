import { ExternalLinkIcon } from "lucide-react";
import { CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { Collection } from "@/fragments/collection";
import type { NFT } from "@/fragments/nft";
import { toShortAddress } from "@/lib/utils";
import { GlassCard } from "./GlassCard";

interface AssetDetailDialogProps {
	open: boolean;
	onOpenChange: (open: boolean) => void;
	nft: NFT | null;
	collectionData: Collection;
}

export function AssetDetailDialog({ open, onOpenChange, nft, collectionData }: AssetDetailDialogProps) {
	if (!nft) return null;

	const tokenProperties = nft.current_token_data?.token_properties || {};
	const hasProperties = Object.keys(tokenProperties).length > 0;

	return (
		<Dialog open={open} onOpenChange={onOpenChange}>
			<DialogContent className="w-[calc(100%-32px)] max-w-[calc(100%-16px)] max-h-[90vh] md:max-w-[95vw] md:w-[1200px] flex flex-col p-0 md:m-4">
				<DialogHeader className="p-4 md:p-6 pb-0 md:pb-0 flex-shrink-0">
					<DialogTitle className="flex flex-col sm:flex-row sm:items-center gap-2">
						<span>{nft.current_token_data?.token_name || "NFT Details"}</span>
					</DialogTitle>
				</DialogHeader>

				<div className="overflow-y-auto p-4 md:p-6 pt-0 md:pt-0">
					<div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6">
						{/* Left Column - NFT Image and Collection Info */}
						<div className="flex flex-col space-y-4 lg:col-span-1">
							<div className="w-full max-w-sm aspect-square bg-muted rounded-lg overflow-hidden border mx-auto lg:mx-0">
								{nft.current_token_data?.token_uri ? (
									<img
										src={nft.current_token_data.token_uri}
										alt={nft.current_token_data.token_name || "NFT"}
										className="w-full h-full object-cover"
										onError={(e) => {
											e.currentTarget.src = collectionData.uri || "";
										}}
									/>
								) : (
									<div className="w-full h-full flex items-center justify-center text-muted-foreground">
										<div className="text-center">
											<div className="text-4xl mb-2">🖼️</div>
											<p>No Image Available</p>
										</div>
									</div>
								)}
							</div>

							{/* Collection Information */}
							<GlassCard className="w-full gap-0">
								<CardHeader className="pb-3">
									<CardTitle className="text-lg">Collection Information</CardTitle>
								</CardHeader>
								<CardContent className="space-y-3 pt-0">
									<div className="space-y-3">
										<div>
											<span className="text-sm font-medium text-muted-foreground">Collection Name</span>
											<p className="text-sm">{collectionData.collection_name || "Unknown Collection"}</p>
										</div>
										<div>
											<span className="text-sm font-medium text-muted-foreground">Collection ID</span>
											<div className="flex items-center gap-2">
												<p className="text-sm font-mono">{toShortAddress(collectionData.collection_id)}</p>
												<button
													type="button"
													onClick={() => navigator.clipboard.writeText(collectionData.collection_id)}
													className="text-xs text-muted-foreground hover:text-foreground transition-colors"
													title="Copy collection ID"
												>
													📋
												</button>
											</div>
										</div>
									</div>

									{collectionData.description && (
										<div>
											<span className="text-sm font-medium text-muted-foreground">Collection Description</span>
											<p className="text-sm mt-1">{collectionData.description}</p>
										</div>
									)}
								</CardContent>
							</GlassCard>
						</div>

						{/* Right Column - Information */}
						<div className="space-y-4 lg:col-span-2">
							{/* Basic Information */}
							<GlassCard className="gap-0">
								<CardHeader className="pb-3">
									<CardTitle className="text-lg">Basic Information</CardTitle>
								</CardHeader>
								<CardContent className="space-y-3 pt-0">
									<div className="grid grid-cols-1 gap-3">
										<div>
											<span className="text-sm font-medium text-muted-foreground">Token Name</span>
											<p className="text-sm">{nft.current_token_data?.token_name || "Unnamed Token"}</p>
										</div>
										<div>
											<span className="text-sm font-medium text-muted-foreground">Token ID</span>
											<div className="flex items-center gap-2">
												<p className="text-sm font-mono">{toShortAddress(nft.token_data_id)}</p>
												<button
													type="button"
													onClick={() => navigator.clipboard.writeText(nft.token_data_id)}
													className="text-xs text-muted-foreground hover:text-foreground transition-colors"
													title="Copy full token ID"
												>
													📋
												</button>
											</div>
										</div>
									</div>

									{nft.current_token_data?.description && (
										<div>
											<span className="text-sm font-medium text-muted-foreground">Description</span>
											<p className="text-sm mt-1">{nft.current_token_data.description}</p>
										</div>
									)}

									{nft.current_token_data?.token_uri && (
										<div>
											<span className="text-sm font-medium text-muted-foreground">Token URI</span>
											<div className="flex flex-col sm:flex-row sm:items-center gap-2">
												<p className="text-sm font-mono break-all">{nft.current_token_data.token_uri}</p>
												<a
													href={nft.current_token_data.token_uri}
													target="_blank"
													rel="noopener noreferrer"
													className="text-xs text-muted-foreground hover:text-foreground transition-colors flex-shrink-0"
													title="Open token URI"
												>
													<ExternalLinkIcon className="w-3 h-3" />
												</a>
											</div>
										</div>
									)}
								</CardContent>
							</GlassCard>

							{/* Token Properties */}
							{hasProperties && (
								<GlassCard className="gap-0">
									<CardHeader className="pb-3">
										<CardTitle className="text-lg">Token Properties</CardTitle>
									</CardHeader>
									<CardContent className="pt-0">
										<div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
											{Object.entries(tokenProperties).map(([key, value]) => (
												<div key={key} className="space-y-1">
													<span className="text-sm font-medium text-muted-foreground capitalize">
														{key.replace(/_/g, " ")}
													</span>
													<div className="text-sm">
														{typeof value === "object" ? (
															<pre className="text-xs bg-muted p-2 rounded overflow-auto">
																{JSON.stringify(value, null, 2)}
															</pre>
														) : (
															<span className="break-all">{String(value)}</span>
														)}
													</div>
												</div>
											))}
										</div>
									</CardContent>
								</GlassCard>
							)}
						</div>
					</div>
				</div>
			</DialogContent>
		</Dialog>
	);
}
