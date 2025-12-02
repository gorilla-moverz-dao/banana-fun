import { MOVE_NETWORK } from "@/constants";
import type { TypedDocumentString } from "./graphql";

export async function executeGraphQL<TResult, TVariables>(
	query: TypedDocumentString<TResult, TVariables>,
	...[variables]: TVariables extends Record<string, never> ? [] : [TVariables]
) {
	const response = await fetch(MOVE_NETWORK.indexerUrl, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Accept: "application/graphql-response+json",
		},
		body: JSON.stringify({
			query,
			variables,
		}),
	});

	if (!response.ok) {
		throw new Error("Network response was not ok");
	}

	const json = await response.json();
	return json.data as TResult;
}
