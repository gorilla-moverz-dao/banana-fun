module deployment_addr::dex {
    use yuzuswap::fa_helper;
    use yuzuswap::scripts;
    use yuzuswap::tick_math;
    use std::object;
    use std::fungible_asset;
    use aptos_std::math64;

    #[test_only]
    use std::signer;
    #[test_only]
    use std::account;

    public(package) fun create_pool_with_liquidity(
        signer: &signer,
        token_a_metadata: object::Object<fungible_asset::Metadata>,
        token_b_metadata: object::Object<fungible_asset::Metadata>,
        fee: u64,
        tick_lower: u32,
        tick_upper: u32,
        amount_a: u64,
        amount_b: u64
    ) {
        // Align price and amounts with Yuzuswap token ordering
        let is_sorted = fa_helper::is_sorted(token_a_metadata, token_b_metadata);
        let (token0_metadata, token1_metadata, amount0, amount1) =
            if (is_sorted) {
                (token_a_metadata, token_b_metadata, amount_a, amount_b)
            } else {
                (token_b_metadata, token_a_metadata, amount_b, amount_a)
            };
        let sqrt_token0 = math64::sqrt(amount0);
        let sqrt_token1 = math64::sqrt(amount1);

        // YuzuSwap uses Q48.80 format: sqrt_price = sqrt(price) * 2^80
        let raw_sqrt_price = ((sqrt_token1 as u128) << 80) / (sqrt_token0 as u128);
        let initial_tick = tick_math::get_tick_at_sqrt_price(raw_sqrt_price);
        let initial_sqrt_price = tick_math::get_sqrt_price_at_tick(initial_tick);

        scripts::create_pool_with_liquidity(
            signer,
            token0_metadata,
            token1_metadata,
            fee,
            initial_sqrt_price,
            tick_lower,
            tick_upper,
            amount0,
            amount1
        );
    }

    #[test_only]
    public fun setup_test_env(yuzuswap_signer: &signer) {
        yuzuswap::config::init_module_for_test(yuzuswap_signer);
        yuzuswap::emergency::init_module_for_test(yuzuswap_signer);
        yuzuswap::fee_tier::init_module_for_test(yuzuswap_signer);
        yuzuswap::liquidity_pool::init_module_for_test(yuzuswap_signer);
        yuzuswap::position_nft_manager::init_module_for_test(yuzuswap_signer);
        yuzuswap::coin_helper::init_module_for_test(yuzuswap_signer);
        // Default emergency_admin from yuzuswap init_module
        let default_emergency_admin =
            account::create_signer_for_test(
                @0x10834a54f1c6064da9909e0f3cf4319cad8e08ca9a38f7fa19a851bf951fcbce
            );
        yuzuswap::config::set_emergency_admin(
            &default_emergency_admin, signer::address_of(yuzuswap_signer)
        );
    }
}

