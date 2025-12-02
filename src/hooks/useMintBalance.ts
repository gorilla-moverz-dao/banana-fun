import { useQuery } from "@tanstack/react-query";
import { launchpadClient } from "@/lib/aptos";
import { useClients } from "./useClients";
import { useMintStages } from "./useMintStages";

export const useMintBalance = (collectionAddress: `0x${string}`) => {
	const { address } = useClients();
	const { data: stages, isLoading: isLoadingStages } = useMintStages(
		address?.toString() as `0x${string}`,
		collectionAddress,
	);

	return useQuery({
		queryKey: ["mint-balance", collectionAddress, address],
		enabled: !isLoadingStages,
		queryFn: async () => {
			if (!address || !stages) return [];

			try {
				const promises = stages.map((stage) =>
					launchpadClient.view
						.get_mint_balance({
							functionArguments: [collectionAddress, stage.name, address],
							typeArguments: [],
						})
						.then((res) => ({ stage: stage.name, balance: Number(res[0]) })),
				);
				const results = await Promise.all(promises);
				return results;
			} catch (error) {
				console.error(error);
				return [];
			}
		},
	});
};
