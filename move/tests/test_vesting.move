#[test_only]
module deployment_addr::test_vesting {
    use std::string;
    use std::vector;
    use aptos_std::debug;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::object;
    use std::signer;

    use deployment_addr::nft_launchpad;
    use deployment_addr::vesting;
    use deployment_addr::test_end_to_end;

    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset;

    // Test constants (reused from test_end_to_end)
    const MINT_FEE_SMALL: u64 = 2u64;
    const MINT_LIMIT_XLARGE: u64 = 20u64;
    const DURATION_MEDIUM: u64 = 200u64;
    const MAX_SUPPLY: u64 = 10u64;
    const SALE_DEADLINE_OFFSET: u64 = 10000u64;
    const FA_SYMBOL: vector<u8> = b"BANANA";
    const VESTING_CLIFF: u64 = 100u64;
    const VESTING_DURATION: u64 = 1000u64;
    const STAGE_NAME_PUBLIC: vector<u8> = b"Public mint stage";

    // ================================= Vesting Tests ================================= //

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 1, location = vesting)]
    /// Test that claiming before cliff period fails
    fun test_vesting_claim_before_cliff_fails(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = test_end_to_end::setup_test_env(aptos_framework, user1, admin);

        // Create collection and mint all NFTs
        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL,
                MINT_LIMIT_XLARGE,
                DURATION_MEDIUM
            );

        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj,
                string::utf8(STAGE_NAME_PUBLIC),
                MAX_SUPPLY
            );
        test_end_to_end::mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Move time past sale deadline but NOT past cliff
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);

        // Complete the sale
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Get user's first NFT
        let nft_obj = *vector::borrow(&nfts, 0);

        // Try to claim before cliff - should fail with ECLIFF_NOT_PASSED (error code 1)
        vesting::claim(user1, collection_obj, nft_obj);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    /// Test successful vesting claim after cliff period
    fun test_vesting_claim_after_cliff_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = test_end_to_end::setup_test_env(aptos_framework, user1, admin);

        // Create collection and mint all NFTs
        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL,
                MINT_LIMIT_XLARGE,
                DURATION_MEDIUM
            );

        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj,
                string::utf8(STAGE_NAME_PUBLIC),
                MAX_SUPPLY
            );
        test_end_to_end::mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Move time past sale deadline
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);

        // Complete the sale
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Get user's first NFT
        let nft_obj = *vector::borrow(&nfts, 0);

        // Get FA metadata
        let collection_owner_obj = nft_launchpad::get_collection_owner_obj(collection_obj);
        let collection_owner_addr = object::object_address(&collection_owner_obj);
        let fa_obj_addr = object::create_object_address(&collection_owner_addr, FA_SYMBOL);
        let fa_metadata = object::address_to_object<fungible_asset::Metadata>(fa_obj_addr);

        // Check initial balance is 0
        let initial_balance = primary_fungible_store::balance(user1_addr, fa_metadata);
        assert!(initial_balance == 0, 0);

        // Move time past cliff (VESTING_CLIFF = 100, so move to SALE_DEADLINE_OFFSET + 1 + 150)
        // This should vest ~15% of the amount (150/1000 duration)
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1 + 150);

        // Claim vested tokens
        vesting::claim(user1, collection_obj, nft_obj);

        // Check balance increased
        let final_balance = primary_fungible_store::balance(user1_addr, fa_metadata);
        debug::print(&final_balance);
        assert!(final_balance > 0, 1);

        // Calculate expected vested amount
        // Total vesting pool = 10% of 1B = 100M tokens
        // Amount per NFT = 100M / 10 = 10M tokens
        // Elapsed = 150s, Duration = 1000s
        // Vested = 10M * 150 / 1000 = 1.5M tokens
        let total_supply: u64 = 1_000_000_000_000_000_000;
        let vesting_pool = total_supply * 10 / 100;
        let amount_per_nft = vesting_pool / MAX_SUPPLY;
        let expected_vested = amount_per_nft * 150 / VESTING_DURATION;
        debug::print(&expected_vested);
        assert!(final_balance == expected_vested, 2);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    /// Test full vesting claim after duration
    fun test_vesting_full_claim_after_duration(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = test_end_to_end::setup_test_env(aptos_framework, user1, admin);

        // Create collection and mint all NFTs
        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL,
                MINT_LIMIT_XLARGE,
                DURATION_MEDIUM
            );

        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj,
                string::utf8(STAGE_NAME_PUBLIC),
                MAX_SUPPLY
            );
        test_end_to_end::mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Move time past sale deadline
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);

        // Complete the sale
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Get user's first NFT
        let nft_obj = *vector::borrow(&nfts, 0);

        // Get FA metadata
        let collection_owner_obj = nft_launchpad::get_collection_owner_obj(collection_obj);
        let collection_owner_addr = object::object_address(&collection_owner_obj);
        let fa_obj_addr = object::create_object_address(&collection_owner_addr, FA_SYMBOL);
        let fa_metadata = object::address_to_object<fungible_asset::Metadata>(fa_obj_addr);

        // Move time past full vesting duration (SALE_DEADLINE_OFFSET + 1 + VESTING_DURATION + 100)
        timestamp::update_global_time_for_test_secs(
            SALE_DEADLINE_OFFSET + 1 + VESTING_DURATION + 100
        );

        // Claim fully vested tokens
        vesting::claim(user1, collection_obj, nft_obj);

        // Check balance is full amount per NFT
        let final_balance = primary_fungible_store::balance(user1_addr, fa_metadata);
        debug::print(&final_balance);

        // Expected: 10% of 1B / 10 NFTs = 10M tokens per NFT
        let total_supply: u64 = 1_000_000_000_000_000_000;
        let vesting_pool = total_supply * 10 / 100;
        let amount_per_nft = vesting_pool / MAX_SUPPLY;
        debug::print(&amount_per_nft);
        assert!(final_balance == amount_per_nft, 1);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            user2 = @0x201,
            royalty_user = @0x300
        )
    ]
    #[expected_failure(abort_code = 3, location = vesting)]
    /// Test that non-owner cannot claim
    fun test_vesting_non_owner_cannot_claim(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = test_end_to_end::setup_test_env(aptos_framework, user1, admin);
        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);

        // Create collection and mint all NFTs to user1
        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL,
                MINT_LIMIT_XLARGE,
                DURATION_MEDIUM
            );

        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj,
                string::utf8(STAGE_NAME_PUBLIC),
                MAX_SUPPLY
            );
        test_end_to_end::mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Complete the sale
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Get user1's NFT
        let nft_obj = *vector::borrow(&nfts, 0);

        // Move time past cliff
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1 + VESTING_CLIFF + 50);

        // User2 tries to claim user1's NFT - should fail with ENOT_NFT_OWNER (error code 3)
        vesting::claim(user2, collection_obj, nft_obj);
    }
}

