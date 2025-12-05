module deployment_addr::dex {
    use yuzuswap::scripts;
    use std::object;
    use std::fungible_asset;
    use std::debug;
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
        // Calculate sqrt_price from amounts: sqrt_price = sqrt(move_supply / supply) * 2^64
        // = sqrt(move_supply) * 2^64 / sqrt(supply)
        let sqrt_move = math64::sqrt(amount_a);
        let sqrt_supply = math64::sqrt(amount_b);
        let initial_sqrt_price = ((sqrt_move as u128) << 64) / (sqrt_supply as u128);

        debug::print(signer);
        debug::print(&token_a_metadata);
        debug::print(&token_b_metadata);
        debug::print(&fee);
        debug::print(&initial_sqrt_price);
        debug::print(&tick_lower);
        debug::print(&tick_upper);
        debug::print(&amount_a);
        debug::print(&amount_b);

        scripts::create_pool_with_liquidity(
            signer,
            token_a_metadata,
            token_b_metadata,
            fee,
            initial_sqrt_price,
            tick_lower,
            tick_upper,
            amount_a,
            amount_b
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

