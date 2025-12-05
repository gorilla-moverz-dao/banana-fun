#[test_only]
module deployment_addr::test_dex {
    use std::signer;
    use std::object;
    use std::fungible_asset;
    use std::option;
    use std::string::{utf8};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::aptos_coin::mint_apt_fa_for_test;
    use aptos_framework::timestamp;
    use aptos_framework::account;

    use deployment_addr::dex;

    #[test(aptos_framework = @0x1, user1 = @0x200)]
    fun test_create_pool_with_liquidity(
        aptos_framework: &signer, user1: &signer
    ) {
        let user1_addr = signer::address_of(user1);
        let supply: u64 = 1000000000000000000;
        let move_supply: u64 = 1000000000000;

        primary_fungible_store::deposit(user1_addr, mint_apt_fa_for_test(move_supply));

        timestamp::set_time_has_started_for_testing(aptos_framework);
        account::create_account_for_test(user1_addr);

        let yuzuswap_signer = account::create_signer_for_test(@yuzuswap);
        dex::setup_test_env(&yuzuswap_signer);

        let constructor_ref = &object::create_named_object(user1, b"TOKEN_A");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(supply as u128), // Hard cap - no more tokens can ever be minted
            utf8(b"TOKEN_A"),
            utf8(b"TOKEN_A"),
            9, // decimals
            utf8(b"https://example.com/token.json"),
            utf8(b"https://example.com/project.json")
        );

        // Create mint ref to mint the tokens
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let token_a_metadata =
            object::object_from_constructor_ref<fungible_asset::Metadata>(constructor_ref);

        // Mint the total supply
        let minted_fa = fungible_asset::mint(&mint_ref, supply);

        // Extract LP portion and deposit to user (for Yuzuswap pool creation)
        let lp_fa = fungible_asset::extract(&mut minted_fa, supply);
        fungible_asset::destroy_zero(minted_fa); // Destroy the now-empty FA
        primary_fungible_store::deposit(user1_addr, lp_fa);

        let token_b_metadata = object::address_to_object<fungible_asset::Metadata>(@0xa); // Native MOVE metadata
        let fee: u64 = 10000;
        let lower_tick: u32 = 36;
        let upper_tick: u32 = 887236;

        dex::create_pool_with_liquidity(
            user1,
            token_a_metadata,
            token_b_metadata,
            fee,
            lower_tick,
            upper_tick,
            supply,
            move_supply
        );
    }
}

