import { useLocation } from "@tanstack/react-router";
import type { Doc } from "convex/_generated/dataModel";
import { ChevronLeft, ChevronRight, Grid, List, Search, X } from "lucide-react";
import { useEffect, useState } from "react";
import type { NFT } from "@/fragments/nft";
import { useCollectionNFTs } from "@/hooks/useCollectionNFTs";
import { toShortAddress } from "@/lib/utils";
import { GlassCard } from "./GlassCard";
import { NFTThumbnail } from "./NFTThumbnail";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { CardContent } from "./ui/card";
import { Input } from "./ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";

type SortOption = "newest" | "oldest" | "name";
type ViewOption = "grid" | "list";
type FilterOption = "all" | "owned" | "available";

interface BrowserSearch {
	search?: string;
	sort?: SortOption;
	view?: ViewOption;
	filter?: FilterOption;
	page?: number;
}

const browserDefaults: Required<BrowserSearch> = {
	search: "",
	sort: "name",
	view: "grid",
	filter: "all",
	page: 1,
};

function parseSearchParams(): BrowserSearch {
	const params = new URLSearchParams(window.location.search);
	return {
		search: params.get("search") || undefined,
		sort: (params.get("sort") as SortOption) || undefined,
		view: (params.get("view") as ViewOption) || undefined,
		filter: (params.get("filter") as FilterOption) || undefined,
		page: params.get("page") ? Number(params.get("page")) : undefined,
	};
}

interface NFTBrowserCardProps {
	collectionId: string;
	collectionData: Doc<"collections">;
	onNFTClick?: (nft: NFT) => void;
	pageSize?: number;
	showFilters?: boolean;
}

export function NFTBrowserCard({
	collectionId,
	collectionData,
	onNFTClick,
	pageSize = 100,
	showFilters = true,
}: NFTBrowserCardProps) {
	const location = useLocation();

	// Initialize state from URL params
	const [params, setParams] = useState<BrowserSearch>(() => parseSearchParams());

	// Parse params with defaults
	const search = params.search ?? browserDefaults.search;
	const sort = params.sort ?? browserDefaults.sort;
	const view = params.view ?? browserDefaults.view;
	const filter = params.filter ?? browserDefaults.filter;
	const page = params.page ?? browserDefaults.page;

	const [localSearch, setLocalSearch] = useState(search);

	// Sync state from URL on external navigation (back/forward)
	useEffect(() => {
		const handlePopState = () => {
			setParams(parseSearchParams());
		};
		window.addEventListener("popstate", handlePopState);
		return () => window.removeEventListener("popstate", handlePopState);
	}, []);

	// Update URL search params and state
	const updateParams = (updates: Partial<BrowserSearch>) => {
		const newParams = { ...params, ...updates };

		// Update state first (triggers re-render)
		setParams(newParams);

		// Update URL
		const currentParams = new URLSearchParams(window.location.search);
		for (const [key, value] of Object.entries(updates)) {
			if (value === undefined || value === "" || value === browserDefaults[key as keyof BrowserSearch]) {
				currentParams.delete(key);
			} else {
				currentParams.set(key, String(value));
			}
		}
		const newSearch = currentParams.toString();
		const newUrl = `${location.pathname}${newSearch ? `?${newSearch}` : ""}`;
		window.history.replaceState(null, "", newUrl);
	};

	// Sync local search input with search param
	useEffect(() => {
		setLocalSearch(search);
	}, [search]);

	// Fetch NFTs
	const { data: nftsData, isLoading: nftsLoading } = useCollectionNFTs({
		onlyOwned: filter === "owned",
		collectionIds: [collectionId],
		sort,
		search,
		page,
		limit: pageSize,
	});

	const nfts = nftsData?.current_token_ownerships_v2 || [];
	const startIndex = (page - 1) * pageSize;
	const totalPages = Math.ceil((collectionData.currentSupply || 0) / pageSize);

	const hasActiveFilters = search || sort !== "name" || filter !== "all";

	const clearAllFilters = () => {
		setLocalSearch("");
		updateParams({
			search: undefined,
			sort: undefined,
			filter: undefined,
			page: undefined,
		});
	};

	const handleSearchSubmit = () => {
		updateParams({ search: localSearch || undefined, page: 1 });
	};

	return (
		<div className="space-y-4">
			{/* Filters Card */}
			{showFilters && (
				<GlassCard className="p-3 flex flex-col gap-2 backdrop-blur-3xl dark:bg-secondary/20">
					<div className="space-y-4">
						{/* Search and Basic Filters */}
						<div className="flex flex-col md:flex-row gap-4">
							{/* Search Bar */}
							<div className="flex-1 relative">
								<Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
								<Input
									placeholder="Search by name, description, or token ID..."
									value={localSearch}
									onChange={(e) => setLocalSearch(e.target.value)}
									onKeyDown={(e) => {
										if (e.key === "Enter") {
											handleSearchSubmit();
										}
									}}
									className="pl-10"
								/>
							</div>

							{/* Sort + View Toggle */}
							<div className="flex items-center gap-2 w-full md:w-auto">
								<div className="flex-1 md:flex-none md:w-48">
									<Select value={sort} onValueChange={(value) => updateParams({ sort: value as SortOption, page: 1 })}>
										<SelectTrigger className="w-full">
											<SelectValue />
										</SelectTrigger>
										<SelectContent>
											<SelectItem value="newest">Newest First</SelectItem>
											<SelectItem value="oldest">Oldest First</SelectItem>
											<SelectItem value="name">Name A-Z</SelectItem>
										</SelectContent>
									</Select>
								</div>

								{/* View Toggle */}
								<div className="flex border rounded-md ml-auto">
									<Button
										variant={view === "grid" ? "default" : "ghost"}
										size="sm"
										onClick={() => updateParams({ view: "grid" })}
										className="rounded-r-none"
									>
										<Grid className="w-4 h-4" />
									</Button>
									<Button
										variant={view === "list" ? "default" : "ghost"}
										size="sm"
										onClick={() => updateParams({ view: "list" })}
										className="rounded-l-none"
									>
										<List className="w-4 h-4" />
									</Button>
								</div>
							</div>

							{/* Filter Dropdown */}
							<Select
								value={filter}
								onValueChange={(value) => updateParams({ filter: value as FilterOption, page: 1 })}
							>
								<SelectTrigger className="w-full md:w-48">
									<SelectValue />
								</SelectTrigger>
								<SelectContent>
									<SelectItem value="all">All NFTs</SelectItem>
									<SelectItem value="owned">Owned by Me</SelectItem>
									<SelectItem value="available">Available</SelectItem>
								</SelectContent>
							</Select>

							{/* Active Filters Display */}
							{search && (
								<div className="flex flex-wrap gap-2">
									<Badge variant="default" className="flex items-center gap-1">
										Search: "{search}"
										<Button
											variant="ghost"
											size="sm"
											className="h-auto p-1"
											style={{ paddingInline: "4px" }}
											onClick={() => {
												updateParams({ search: undefined });
												setLocalSearch("");
											}}
										>
											<X className="w-3 h-3" />
										</Button>
									</Badge>

									{hasActiveFilters && (
										<Button
											variant="outline"
											style={{ paddingInline: "4px", paddingRight: "8px" }}
											size="sm"
											onClick={clearAllFilters}
											className="text-muted-foreground"
										>
											<X className="w-4 h-4 mr-0" />
											Clear All
										</Button>
									)}
								</div>
							)}
						</div>
					</div>

					{/* Results Count */}
					<div className="flex items-center justify-between">
						<div className="text-sm text-muted-foreground">
							Showing {startIndex + 1}-{startIndex + nfts.length} of {collectionData.currentSupply} NFTs
							{search && ` matching "${search}"`}
						</div>
					</div>
				</GlassCard>
			)}

			{/* NFTs Grid/List */}
			<GlassCard className="px-6">
				{nftsLoading ? (
					<div className="flex items-center justify-center min-h-[400px]">
						<div className="text-lg">Loading NFTs...</div>
					</div>
				) : nfts.length === 0 ? (
					<CardContent className="flex items-center justify-center min-h-[200px]">
						<div className="text-center space-y-2">
							<div className="text-lg font-medium">No NFTs found</div>
							<div className="text-sm text-muted-foreground">
								{search ? `No NFTs match "${search}"` : "This collection has no NFTs yet"}
							</div>
						</div>
					</CardContent>
				) : (
					<>
						{view === "grid" ? (
							<div className="grid gap-4 grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
								{nfts.map((nft) => (
									<NFTThumbnail
										key={nft.token_data_id}
										nft={nft}
										collectionData={collectionData}
										onClick={() => onNFTClick?.(nft)}
										className="cursor-pointer"
									/>
								))}
							</div>
						) : (
							<div className="space-y-2">
								{nfts.map((nft) => (
									<GlassCard
										hoverEffect={true}
										key={nft.token_data_id}
										className="p-2 cursor-pointer hover:bg-white/10 transition-all duration-200 backdrop-blur-sm bg-white/5 border border-white/20 group"
										onClick={() => onNFTClick?.(nft)}
									>
										<div className="flex items-center gap-4">
											<div className="w-20 h-20 rounded-lg overflow-hidden border border-white/20 transition-transform duration-300 group-hover:scale-120">
												<img
													src={nft.current_token_data?.token_uri}
													alt={nft.current_token_data?.token_name || "NFT"}
													className="w-full h-full object-cover"
													onError={(e) => {
														e.currentTarget.src = collectionData.uri;
													}}
												/>
											</div>
											<div className="flex-3">
												<h4 className="font-medium">
													{nft.current_token_data?.token_name || `Token ${nft.token_data_id}`}
												</h4>
												<p className="text-sm text-muted-foreground">{nft.current_token_data?.description}</p>
												<p className="text-xs text-muted-foreground">Token ID: {toShortAddress(nft.token_data_id)}</p>
											</div>
											<div className="flex-2 text-right">
												{Object.entries(nft.current_token_data?.token_properties || {}).map(([traitType, value]) => (
													<Badge key={traitType} variant="outline">
														{traitType}: {value as string}
													</Badge>
												))}
											</div>
										</div>
									</GlassCard>
								))}
							</div>
						)}

						{/* Pagination */}
						{totalPages > 1 && (
							<div className="flex items-center justify-center gap-2 py-4">
								<Button
									variant="outline"
									size="sm"
									disabled={page <= 1}
									onClick={() => updateParams({ page: page - 1 })}
								>
									<ChevronLeft className="w-4 h-4" />
									Previous
								</Button>
								<div className="text-sm">
									Page {page} of {totalPages}
								</div>
								<Button
									variant="outline"
									size="sm"
									disabled={page >= totalPages}
									onClick={() => updateParams({ page: page + 1 })}
								>
									Next
									<ChevronRight className="w-4 h-4" />
								</Button>
							</div>
						)}
					</>
				)}
			</GlassCard>
		</div>
	);
}
