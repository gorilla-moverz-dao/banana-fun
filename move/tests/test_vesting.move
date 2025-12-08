#[test_only]
module deployment_addr::test_vesting {
    use std::string::utf8;
    use aptos_std::debug;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::object::{Self, Object};
    use std::signer;

    use aptos_token_objects::collection::Collection;
    use aptos_token_objects::token::Token;

    use deployment_addr::nft_launchpad;
    use deployment_addr::vesting;
    use deployment_addr::test_end_to_end;

    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::Metadata;

    // Only keep constants that differ from test_end_to_end or are specific to vesting tests
    const MINT_FEE: u64 = 2;
    const MINT_LIMIT: u64 = 20;
    const STAGE_DURATION: u64 = 200;
    const MAX_SUPPLY: u64 = 10;
    const SALE_DEADLINE_OFFSET: u64 = 10000;
    const FA_SYMBOL: vector<u8> = b"BANANA";
    const STAGE_NAME_PUBLIC: vector<u8> = b"Public mint stage";

    // Vesting constants
    const VESTING_CLIFF: u64 = 100;
    const VESTING_DURATION: u64 = 1000;
    const CREATOR_VESTING_CLIFF: u64 = 200;
    const CREATOR_VESTING_DURATION: u64 = 2000;

    // FA distribution constants (must match launchpad)
    const FA_TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_000;
    const NFT_VESTING_PERCENTAGE: u64 = 10;
    const CREATOR_VESTING_PERCENTAGE: u64 = 30;

    // ================================= Helper Functions ================================= //

    /// Setup a completed sale with minted NFTs, returns (collection, nfts, user_addr)
    fun setup_completed_sale(
        aptos_framework: &signer,
        admin: &signer,
        user: &signer,
        royalty_user: &signer
    ): (Object<Collection>, vector<Object<Token>>, address) {
        let user_addr = test_end_to_end::setup_test_env(aptos_framework, user, admin);

        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE,
                MINT_LIMIT,
                STAGE_DURATION
            );

        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj,
                utf8(STAGE_NAME_PUBLIC),
                MAX_SUPPLY
            );
        test_end_to_end::mint(user_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user, collection_obj, MAX_SUPPLY, vector[]);

        // Move time past sale deadline and complete
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);
        nft_launchpad::check_and_complete_sale(collection_obj);

        (collection_obj, nfts, user_addr)
    }

    /// Get FA metadata from a collection
    fun get_fa_metadata(collection_obj: Object<Collection>): Object<Metadata> {
        let collection_owner_obj = nft_launchpad::get_collection_owner_obj(collection_obj);
        let collection_owner_addr = object::object_address(&collection_owner_obj);
        let fa_obj_addr = object::create_object_address(&collection_owner_addr, FA_SYMBOL);
        object::address_to_object<Metadata>(fa_obj_addr)
    }

    /// Calculate expected NFT vesting amount per NFT
    fun expected_amount_per_nft(): u64 {
        let vesting_pool = ((FA_TOTAL_SUPPLY as u128) * (NFT_VESTING_PERCENTAGE as u128) / 100 as u64);
        vesting_pool / MAX_SUPPLY
    }

    /// Calculate expected creator vesting pool
    fun expected_creator_vesting_pool(): u64 {
        ((FA_TOTAL_SUPPLY as u128) * (CREATOR_VESTING_PERCENTAGE as u128) / 100 as u64)
    }

    // ================================= NFT Holder Vesting Tests ================================= //

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 1, location = vesting)]
    fun test_vesting_claim_before_cliff_fails(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        // Setup but DON'T move time past cliff yet
        let user1_addr = test_end_to_end::setup_test_env(aptos_framework, user1, admin);
        let collection_obj =
            test_end_to_end::create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE,
                MINT_LIMIT,
                STAGE_DURATION
            );
        let total_fee =
            test_end_to_end::get_total_mint_fee(
                collection_obj, utf8(STAGE_NAME_PUBLIC), MAX_SUPPLY
            );
        test_end_to_end::mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Complete sale (time past deadline but NOT past cliff)
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Try to claim before cliff - should fail
        vesting::claim(user1, collection_obj, nfts[0]);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_vesting_claim_after_cliff_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let (collection_obj, nfts, user1_addr) =
            setup_completed_sale(aptos_framework, admin, user1, royalty_user);
        let fa_metadata = get_fa_metadata(collection_obj);

        assert!(primary_fungible_store::balance(user1_addr, fa_metadata) == 0);

        // Move time past cliff (150s elapsed, ~15% vested)
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1 + 150);
        vesting::claim(user1, collection_obj, nfts[0]);

        let balance = primary_fungible_store::balance(user1_addr, fa_metadata);
        let expected = (((expected_amount_per_nft() as u128) * 150) / (VESTING_DURATION as u128) as u64);
        debug::print(&balance);
        assert!(balance == expected);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_vesting_full_claim_after_duration(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let (collection_obj, nfts, user1_addr) =
            setup_completed_sale(aptos_framework, admin, user1, royalty_user);
        let fa_metadata = get_fa_metadata(collection_obj);

        // Move time past full duration
        timestamp::update_global_time_for_test_secs(
            SALE_DEADLINE_OFFSET + 1 + VESTING_DURATION + 100
        );
        vesting::claim(user1, collection_obj, nfts[0]);

        let balance = primary_fungible_store::balance(user1_addr, fa_metadata);
        debug::print(&balance);
        assert!(balance == expected_amount_per_nft());
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
    fun test_vesting_non_owner_cannot_claim(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer
    ) {
        let (collection_obj, nfts, _) =
            setup_completed_sale(aptos_framework, admin, user1, royalty_user);
        account::create_account_for_test(signer::address_of(user2));

        // Move time past cliff
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1 + VESTING_CLIFF + 50);

        // User2 tries to claim user1's NFT - should fail
        vesting::claim(user2, collection_obj, nfts[0]);
    }

    // ================================= Creator Vesting Tests ================================= //

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            creator_wallet = @0x500
        )
    ]
    fun test_creator_vesting_claim_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        creator_wallet: &signer
    ) {
        let (collection_obj, _, _) = setup_completed_sale(
            aptos_framework, admin, user1, royalty_user
        );
        let creator_wallet_addr = signer::address_of(creator_wallet);
        account::create_account_for_test(creator_wallet_addr);
        let fa_metadata = get_fa_metadata(collection_obj);

        assert!(vesting::is_creator_vesting_initialized(collection_obj));
        assert!(primary_fungible_store::balance(creator_wallet_addr, fa_metadata) == 0);

        // Move time past creator cliff (300s elapsed, ~15% vested)
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1 + 300);
        vesting::claim_creator_vesting(creator_wallet, collection_obj);

        let balance = primary_fungible_store::balance(creator_wallet_addr, fa_metadata);
        let expected =
            (((expected_creator_vesting_pool() as u128) * 300) / (CREATOR_VESTING_DURATION as u128) as u64);
        debug::print(&balance);
        assert!(balance == expected);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            creator_wallet = @0x500
        )
    ]
    #[expected_failure(abort_code = 1, location = vesting)]
    fun test_creator_vesting_claim_before_cliff_fails(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        creator_wallet: &signer
    ) {
        let (collection_obj, _, _) = setup_completed_sale(
            aptos_framework, admin, user1, royalty_user
        );
        account::create_account_for_test(signer::address_of(creator_wallet));

        // Don't move time past cliff - should fail
        vesting::claim_creator_vesting(creator_wallet, collection_obj);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            wrong_wallet = @0x600
        )
    ]
    #[expected_failure(abort_code = 9, location = vesting)]
    fun test_creator_vesting_non_beneficiary_cannot_claim(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        wrong_wallet: &signer
    ) {
        let (collection_obj, _, _) = setup_completed_sale(
            aptos_framework, admin, user1, royalty_user
        );
        account::create_account_for_test(signer::address_of(wrong_wallet));

        // Move time past cliff
        timestamp::update_global_time_for_test_secs(
            SALE_DEADLINE_OFFSET + 1 + CREATOR_VESTING_CLIFF + 100
        );

        // Wrong wallet tries to claim - should fail
        vesting::claim_creator_vesting(wrong_wallet, collection_obj);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            creator_wallet = @0x500
        )
    ]
    fun test_creator_vesting_full_claim_after_duration(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        creator_wallet: &signer
    ) {
        let (collection_obj, _, _) = setup_completed_sale(
            aptos_framework, admin, user1, royalty_user
        );
        let creator_wallet_addr = signer::address_of(creator_wallet);
        account::create_account_for_test(creator_wallet_addr);
        let fa_metadata = get_fa_metadata(collection_obj);

        // Move time past full duration
        timestamp::update_global_time_for_test_secs(
            SALE_DEADLINE_OFFSET + 1 + CREATOR_VESTING_DURATION + 100
        );
        vesting::claim_creator_vesting(creator_wallet, collection_obj);

        let balance = primary_fungible_store::balance(creator_wallet_addr, fa_metadata);
        debug::print(&balance);
        assert!(balance == expected_creator_vesting_pool());
    }
}

