import type { ResultOf } from "@graphql-typed-document-node/core";
import { graphql } from "@/graphql";

export const NFTFragment = graphql(/* GraphQL */ `
  fragment NFTFragment on current_token_ownerships_v2 {
    token_data_id
    current_token_data {
      collection_id
      token_name
      description
      token_properties
      token_uri
    }
  }
`);

export type NFT = ResultOf<typeof NFTFragment>;
