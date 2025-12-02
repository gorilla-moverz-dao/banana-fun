import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useQuery } from "@tanstack/react-query";
import { aptos } from "@/lib/aptos";
import { oaptToApt } from "@/lib/utils";

export const useGetAccountNativeBalance = (address?: string) => {
  const { account } = useWallet();

  const accountAddress = address || account?.address;

  return useQuery({
    queryKey: ["nativeBalance", accountAddress],
    queryFn: async () => {
      if (!accountAddress) return null;
      const nativeBalance = await aptos.getAccountAPTAmount({ accountAddress });
      return { nativeBalance, balance: oaptToApt(nativeBalance) };
    },
  });
};
