import { useQuery } from "@tanstack/react-query";
import { launchpadClient } from "@/lib/aptos";
import { useClients } from "./useClients";
import type { MintStageInfo } from "./useMintStages";

export const useMintBalance = (collectionAddress: `0x${string}`, stages: Array<MintStageInfo> = []) => {
	const { address } = useClients();

	return useQuery({
		queryKey: ["mint-balance", collectionAddress, address, stages.length],
		enabled: !!address && stages.length > 0,
		queryFn: async () => {
			if (!address || stages.length === 0) return [];

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
