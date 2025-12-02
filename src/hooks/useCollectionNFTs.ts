import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useQuery } from "@tanstack/react-query";
import { executeGraphQL } from "@/graphql/executeGraphQL";
import { graphql } from "@/graphql/gql";
import type {
	Current_Token_Ownerships_V2_Bool_Exp,
	Current_Token_Ownerships_V2_Order_By,
	Order_By,
} from "@/graphql/graphql";
import type { CollectionSearch } from "@/hooks/useCollectionSearch";

interface NFTQueryFilter {
	onlyOwned: boolean;
	collectionIds: Array<string>;
	tokenIds?: Array<string>;
	search?: string;
}

// Interface for NFT query parameters
export interface NFTQueryParams extends NFTQueryFilter {
	sort?: CollectionSearch["sort"];
	page?: number;
	limit?: number;
	enabled?: boolean;
}

const query = graphql(`
  query getNFTs(
    $where: current_token_ownerships_v2_bool_exp
    $orderBy: [current_token_ownerships_v2_order_by!]
    $limit: Int
    $offset: Int
  ) {
    current_token_ownerships_v2(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {
      ...NFTFragment
    }
  }
`);

const getOrderBy = (sort: CollectionSearch["sort"]): Array<Current_Token_Ownerships_V2_Order_By> => {
	switch (sort) {
		case "newest":
			return [{ last_transaction_timestamp: "desc" as Order_By }];
		case "oldest":
			return [{ last_transaction_timestamp: "asc" as Order_By }];
		case "name":
			return [{ current_token_data: { token_name: "asc" as Order_By } }];
		default:
			return [{ last_transaction_timestamp: "desc" as Order_By }];
	}
};

const getWhere = ({ onlyOwned, collectionIds, tokenIds, search }: NFTQueryFilter, address: string | undefined) => {
	const where: Current_Token_Ownerships_V2_Bool_Exp = {
		amount: { _gt: 0 },
		current_token_data: { collection_id: { _in: collectionIds } },
	};

	if (tokenIds && tokenIds.length > 0) {
		where.token_data_id = { _in: tokenIds };
	}

	if (onlyOwned) {
		where.owner_address = { _eq: address };
	}

	// Add search filter if provided
	if (search) {
		where._or = [
			{ current_token_data: { token_name: { _ilike: `%${search}%` } } },
			{ current_token_data: { description: { _ilike: `%${search}%` } } },
			{ token_data_id: { _ilike: `%${search}%` } },
		];
	}

	return where;
};

export const useCollectionNFTs = (params: NFTQueryParams) => {
	const { account, connected } = useWallet();

	const orderBy = getOrderBy(params.sort ?? "newest");
	const limit = params.limit ?? 100;
	const page = params.page ?? 1;
	const offset = (page - 1) * limit;

	return useQuery({
		queryKey: ["nfts", account?.address.toString(), params],
		enabled: (params.enabled ?? true) && (!params.onlyOwned || (!!account && connected)),
		staleTime: 1000 * 60,
		queryFn: async () => {
			const where = getWhere(params, account?.address.toString());

			const res = await executeGraphQL(query, {
				where,
				orderBy,
				limit,
				offset,
			});
			return res;
		},
	});
};
