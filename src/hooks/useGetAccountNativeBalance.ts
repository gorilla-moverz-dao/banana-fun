import { useQuery } from "@tanstack/react-query";
import { aptos } from "@/lib/aptos";
import { oaptToApt } from "@/lib/utils";
import { useMovementWallet } from "./useMovementWallet";

export const useGetAccountNativeBalance = (address?: string) => {
	const { address: walletAddress } = useMovementWallet();

	const accountAddress = address || walletAddress;

	return useQuery({
		queryKey: ["nativeBalance", accountAddress],
		queryFn: async () => {
			if (!accountAddress) return null;
			const nativeBalance = await aptos.getAccountAPTAmount({ accountAddress });
			return { nativeBalance, balance: oaptToApt(nativeBalance) };
		},
	});
};
