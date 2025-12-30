/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as aptos from "../aptos.js";
import type * as chat from "../chat.js";
import type * as collectionSyncActions from "../collectionSyncActions.js";
import type * as collections from "../collections.js";
import type * as crons from "../crons.js";
import type * as reveal from "../reveal.js";
import type * as revealActions from "../revealActions.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  aptos: typeof aptos;
  chat: typeof chat;
  collectionSyncActions: typeof collectionSyncActions;
  collections: typeof collections;
  crons: typeof crons;
  reveal: typeof reveal;
  revealActions: typeof revealActions;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
