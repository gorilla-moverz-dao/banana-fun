import { useNavigate, useParams, useSearch } from "@tanstack/react-router";

// Search params validation
export type CollectionSearch = {
	search: string;
	sort: "newest" | "oldest" | "name";
	view: "grid" | "list";
	page: number;
	filter: "all" | "owned" | "available";
};

const filterDefaults: Omit<CollectionSearch, "view" | "sort"> = {
	search: "",
	page: 1,
	filter: "all",
};

export const searchDefaults: CollectionSearch = {
	sort: "name",
	view: "grid",
	...filterDefaults,
};

export function applyCollectionSearchDefaults(updates: Partial<CollectionSearch>) {
	return {
		...searchDefaults,
		...updates,
	};
}

export function useCollectionSearch() {
	const search = useSearch({ from: "/collections/$collectionId" });
	const navigate = useNavigate();
	const { collectionId } = useParams({ from: "/collections/$collectionId" });

	// Helper function to update search params
	const updateSearchParams = (updates: Partial<CollectionSearch>) => {
		navigate({
			to: "/collections/$collectionId",
			params: { collectionId },
			search: (prev) => ({
				...applyCollectionSearchDefaults({ ...prev, ...updates }),
			}),
		});
	};

	// Helper function to clear all filters
	const clearAllFilters = () => {
		updateSearchParams({ ...filterDefaults });
	};

	const handleSearchChange = (value: string) => {
		updateSearchParams({ search: value, page: 1 });
	};

	// Handle sort change
	const handleSortChange = (value: CollectionSearch["sort"]) => {
		updateSearchParams({ sort: value, page: 1 });
	};

	// Handle view change
	const handleViewChange = (value: CollectionSearch["view"]) => {
		updateSearchParams({ view: value });
	};

	// Handle filter change
	const handleFilterChange = (value: CollectionSearch["filter"]) => {
		updateSearchParams({ filter: value, page: 1 });
	};

	return {
		search,
		collectionId,
		updateSearchParams,
		searchDefaults,
		clearAllFilters,
		handleSearchChange,
		handleSortChange,
		handleViewChange,
		handleFilterChange,
	};
}
