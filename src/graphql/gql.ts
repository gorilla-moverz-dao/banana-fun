/* eslint-disable */
import * as types from './graphql';



/**
 * Map of all GraphQL operations in the project.
 *
 * This map has several performance disadvantages:
 * 1. It is not tree-shakeable, so it will include all operations in the project.
 * 2. It is not minifiable, so the string of a GraphQL query will be multiple times inside the bundle.
 * 3. It does not support dead code elimination, so it will add unused operations.
 *
 * Therefore it is highly recommended to use the babel or swc plugin for production.
 * Learn more about it here: https://the-guild.dev/graphql/codegen/plugins/presets/preset-client#reducing-bundle-size
 */
type Documents = {
    "\n  fragment CollectionFragment on current_collections_v2 {\n    creator_address\n    collection_id\n    collection_name\n    current_supply\n    max_supply\n    uri\n    description\n  }\n": typeof types.CollectionFragmentFragmentDoc,
    "\n  fragment NFTFragment on current_token_ownerships_v2 {\n    token_data_id\n    current_token_data {\n      collection_id\n      token_name\n      description\n      token_properties\n      token_uri\n    }\n  }\n": typeof types.NftFragmentFragmentDoc,
    "\n  query TokenQuery($collection_id: String) {\n    current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {\n      ...CollectionFragment\n\t  \n    }\n    current_collection_ownership_v2_view(where: { collection_id: { _eq: $collection_id } }, order_by: { last_transaction_version: desc }) {\n      owner_address\n    }\n    current_collection_ownership_v2_view_aggregate(where: { collection_id: { _eq: $collection_id } }) {\n      aggregate {\n        count(distinct: true, columns: owner_address)\n      }\n    }\n  }\n": typeof types.TokenQueryDocument,
    "\n  query getNFTs(\n    $where: current_token_ownerships_v2_bool_exp\n    $orderBy: [current_token_ownerships_v2_order_by!]\n    $limit: Int\n    $offset: Int\n  ) {\n    current_token_ownerships_v2(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {\n      ...NFTFragment\n    }\n  }\n": typeof types.GetNfTsDocument,
    "\n  query MintingCollections($collection_ids: [String!]!) {\n    current_collections_v2(where: { collection_id: { _in: $collection_ids } }, order_by: { last_transaction_timestamp: desc }) {\n      collection_id\n      collection_name\n      current_supply\n      max_supply\n      uri\n      description\n    }\n  }\n": typeof types.MintingCollectionsDocument,
    "\n  query getUserReductionNFTs($owner_address: String!, $collection_addresses: [String!]!) {\n    current_token_ownerships_v2(\n      where: {\n        owner_address: { _eq: $owner_address }\n        current_token_data: { collection_id: { _in: $collection_addresses } }\n        amount: { _gt: 0 }\n      }\n      order_by: [{ last_transaction_timestamp: desc }]\n    ) {\n      token_data_id\n      owner_address\n      amount\n      token_properties_mutated_v1\n      current_token_data {\n        collection_id\n        token_name\n        description\n        token_uri\n      }\n    }\n  }\n": typeof types.GetUserReductionNfTsDocument,
};
const documents: Documents = {
    "\n  fragment CollectionFragment on current_collections_v2 {\n    creator_address\n    collection_id\n    collection_name\n    current_supply\n    max_supply\n    uri\n    description\n  }\n": types.CollectionFragmentFragmentDoc,
    "\n  fragment NFTFragment on current_token_ownerships_v2 {\n    token_data_id\n    current_token_data {\n      collection_id\n      token_name\n      description\n      token_properties\n      token_uri\n    }\n  }\n": types.NftFragmentFragmentDoc,
    "\n  query TokenQuery($collection_id: String) {\n    current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {\n      ...CollectionFragment\n\t  \n    }\n    current_collection_ownership_v2_view(where: { collection_id: { _eq: $collection_id } }, order_by: { last_transaction_version: desc }) {\n      owner_address\n    }\n    current_collection_ownership_v2_view_aggregate(where: { collection_id: { _eq: $collection_id } }) {\n      aggregate {\n        count(distinct: true, columns: owner_address)\n      }\n    }\n  }\n": types.TokenQueryDocument,
    "\n  query getNFTs(\n    $where: current_token_ownerships_v2_bool_exp\n    $orderBy: [current_token_ownerships_v2_order_by!]\n    $limit: Int\n    $offset: Int\n  ) {\n    current_token_ownerships_v2(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {\n      ...NFTFragment\n    }\n  }\n": types.GetNfTsDocument,
    "\n  query MintingCollections($collection_ids: [String!]!) {\n    current_collections_v2(where: { collection_id: { _in: $collection_ids } }, order_by: { last_transaction_timestamp: desc }) {\n      collection_id\n      collection_name\n      current_supply\n      max_supply\n      uri\n      description\n    }\n  }\n": types.MintingCollectionsDocument,
    "\n  query getUserReductionNFTs($owner_address: String!, $collection_addresses: [String!]!) {\n    current_token_ownerships_v2(\n      where: {\n        owner_address: { _eq: $owner_address }\n        current_token_data: { collection_id: { _in: $collection_addresses } }\n        amount: { _gt: 0 }\n      }\n      order_by: [{ last_transaction_timestamp: desc }]\n    ) {\n      token_data_id\n      owner_address\n      amount\n      token_properties_mutated_v1\n      current_token_data {\n        collection_id\n        token_name\n        description\n        token_uri\n      }\n    }\n  }\n": types.GetUserReductionNfTsDocument,
};

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  fragment CollectionFragment on current_collections_v2 {\n    creator_address\n    collection_id\n    collection_name\n    current_supply\n    max_supply\n    uri\n    description\n  }\n"): typeof import('./graphql').CollectionFragmentFragmentDoc;
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  fragment NFTFragment on current_token_ownerships_v2 {\n    token_data_id\n    current_token_data {\n      collection_id\n      token_name\n      description\n      token_properties\n      token_uri\n    }\n  }\n"): typeof import('./graphql').NftFragmentFragmentDoc;
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  query TokenQuery($collection_id: String) {\n    current_collections_v2(where: { collection_id: { _eq: $collection_id } }, limit: 1) {\n      ...CollectionFragment\n\t  \n    }\n    current_collection_ownership_v2_view(where: { collection_id: { _eq: $collection_id } }, order_by: { last_transaction_version: desc }) {\n      owner_address\n    }\n    current_collection_ownership_v2_view_aggregate(where: { collection_id: { _eq: $collection_id } }) {\n      aggregate {\n        count(distinct: true, columns: owner_address)\n      }\n    }\n  }\n"): typeof import('./graphql').TokenQueryDocument;
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  query getNFTs(\n    $where: current_token_ownerships_v2_bool_exp\n    $orderBy: [current_token_ownerships_v2_order_by!]\n    $limit: Int\n    $offset: Int\n  ) {\n    current_token_ownerships_v2(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {\n      ...NFTFragment\n    }\n  }\n"): typeof import('./graphql').GetNfTsDocument;
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  query MintingCollections($collection_ids: [String!]!) {\n    current_collections_v2(where: { collection_id: { _in: $collection_ids } }, order_by: { last_transaction_timestamp: desc }) {\n      collection_id\n      collection_name\n      current_supply\n      max_supply\n      uri\n      description\n    }\n  }\n"): typeof import('./graphql').MintingCollectionsDocument;
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(source: "\n  query getUserReductionNFTs($owner_address: String!, $collection_addresses: [String!]!) {\n    current_token_ownerships_v2(\n      where: {\n        owner_address: { _eq: $owner_address }\n        current_token_data: { collection_id: { _in: $collection_addresses } }\n        amount: { _gt: 0 }\n      }\n      order_by: [{ last_transaction_timestamp: desc }]\n    ) {\n      token_data_id\n      owner_address\n      amount\n      token_properties_mutated_v1\n      current_token_data {\n        collection_id\n        token_name\n        description\n        token_uri\n      }\n    }\n  }\n"): typeof import('./graphql').GetUserReductionNfTsDocument;


export function graphql(source: string) {
  return (documents as any)[source] ?? {};
}
