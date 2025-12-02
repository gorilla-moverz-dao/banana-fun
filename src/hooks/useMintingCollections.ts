import { useQuery } from "@tanstack/react-query";
import { executeGraphQL } from "@/graphql/executeGraphQL";
import { graphql } from "@/graphql/gql";
import { launchpadClient } from "@/lib/aptos";
import { normalizeHexAddress } from "@/lib/utils";

const query = graphql(`
  query MintingCollections($collection_ids: [String!]!) {
    current_collections_v2(where: { collection_id: { _in: $collection_ids } }, order_by: { last_transaction_timestamp: desc }) {
      collection_id
      collection_name
      current_supply
      max_supply
      uri
      description
    }
  }
`);

export const useMintingCollections = () => {
	return useQuery({
		queryKey: ["minting-collections"],
		queryFn: async () => {
			const [registry] = await launchpadClient.view.get_registry({
				functionArguments: [],
				typeArguments: [],
			});

			const collectionIds = registry.map((item) => normalizeHexAddress(item.inner));
			const collections = await executeGraphQL(query, { collection_ids: collectionIds });
			return collections.current_collections_v2;
		},
	});
};
