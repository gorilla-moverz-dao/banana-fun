import type { ResultOf } from "@graphql-typed-document-node/core";
import { graphql } from "@/graphql";

export const CollectionFragment = graphql(/* GraphQL */ `
  fragment CollectionFragment on current_collections_v2 {
    creator_address
    collection_id
    collection_name
    current_supply
    max_supply
    uri
    description
  }
`);

export type Collection = ResultOf<typeof CollectionFragment>;
