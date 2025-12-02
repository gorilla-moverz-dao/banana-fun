import { useQuery } from "@tanstack/react-query";
import { launchpadClient } from "@/lib/aptos";
import { useUserReductionNFTs } from "./useUserReductionNFTs";

export interface MintStageInfo {
	name: string;
	mint_fee: string;
	mint_fee_with_reduction: string;
	start_time: string;
	end_time: string;
	stage_type: number;
}

export const useMintStages = (senderAddress: `0x${string}` | undefined, collectionAddress: `0x${string}`) => {
	const { data: reductionNFTs = [], isLoading: isLoadingReductionNFTs } = useUserReductionNFTs(senderAddress);
	return useQuery<Array<MintStageInfo>>({
		queryKey: ["stages", senderAddress, collectionAddress],
		enabled: !isLoadingReductionNFTs,
		staleTime: 1000 * 60,
		queryFn: async () => {
			console.log(
				"get_mint_stages_info",
				senderAddress,
				collectionAddress,
				reductionNFTs.map((nft) => nft.token_data_id as `0x${string}`),
			);
			const [res] = await launchpadClient.view.get_mint_stages_info({
				functionArguments: [
					senderAddress ?? "0x0",
					collectionAddress,
					reductionNFTs.map((nft) => nft.token_data_id as `0x${string}`),
				],
				typeArguments: [],
			});

			return res as Array<MintStageInfo>;
		},
	});
};
