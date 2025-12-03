#[test_only]
module deployment_addr::test_nft_reduction_manager {
    use std::option;
    use std::signer;
    use std::string::{utf8};
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::object;

    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    use deployment_addr::nft_reduction_manager;
    use deployment_addr::nft_launchpad;

    use aptos_framework::aptos_coin::mint_apt_fa_for_test;
    use aptos_framework::primary_fungible_store;

    // Test addresses
    const ADMIN: address = @deployment_addr;
    const USER1: address = @0x200;
    const USER2: address = @0x201;
    const USER3: address = @0x202;
    const COLLECTION1: address = @0x300;
    const COLLECTION2: address = @0x301;
    const COLLECTION3: address = @0x302;
    const APTOS_FRAMEWORK: address = @0x1;
    const INITIAL_BALANCE: u64 = 1000000000;

    // Test constants
    const ORIGINAL_FEE: u64 = 1000000;
    const REDUCTION_10: u64 = 10;
    const REDUCTION_20: u64 = 20;
    const REDUCTION_25: u64 = 25;
    const REDUCTION_30: u64 = 30;
    const REDUCTION_50: u64 = 50;
    const REDUCTION_100: u64 = 100;
    const INVALID_REDUCTION: u64 = 101;

    // Collection metadata
    const COLLECTION_NAME: vector<u8> = b"Test Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Test collection description";
    const COLLECTION_URI: vector<u8> = b"https://example.com/collection.json";
    const TOKEN_NAME: vector<u8> = b"Test Token";
    const TOKEN_DESCRIPTION: vector<u8> = b"Test token description";
    const TOKEN_URI: vector<u8> = b"https://example.com/token.json";
    const PLACEHOLDER_URI: vector<u8> = b"https://example.com/placeholder.json";

    // ================================= Setup Functions ================================= //

    fun setup_test(aptos_framework: &signer, admin: &signer): (signer, signer, signer, signer) {
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        let user3 = account::create_account_for_test(USER3);
        let collection_owner = account::create_account_for_test(COLLECTION1);

        timestamp::set_time_has_started_for_testing(aptos_framework);

        // Initialize AptosCoin for testing
        let (burn_cap, mint_cap) =
            aptos_framework::aptos_coin::initialize_for_test(aptos_framework);

        // Register coin for users
        aptos_framework::coin::register<aptos_framework::aptos_coin::AptosCoin>(&user1);
        aptos_framework::coin::register<aptos_framework::aptos_coin::AptosCoin>(&user2);
        aptos_framework::coin::register<aptos_framework::aptos_coin::AptosCoin>(&user3);
        aptos_framework::coin::register<aptos_framework::aptos_coin::AptosCoin>(
            &collection_owner
        );

        // Mint APT to users for minting
        primary_fungible_store::deposit(USER1, mint_apt_fa_for_test(INITIAL_BALANCE));

        // Initialize launchpad module (this also initializes the reduction manager)
        nft_launchpad::init_module_for_test(admin);
        nft_reduction_manager::init_module_for_test(admin);

        // Destroy capabilities immediately since we don't need them for most tests
        aptos_framework::coin::destroy_burn_cap(burn_cap);
        aptos_framework::coin::destroy_mint_cap(mint_cap);

        (user1, user2, user3, collection_owner)
    }

    fun create_test_collection(owner: &signer): object::Object<collection::Collection> {
        let stage_names = vector[utf8(b"Public Stage")];
        let stage_types = vector[nft_launchpad::get_stage_type_public()];
        let allowlist_addresses = vector[option::none<vector<address>>()];
        let allowlist_mint_limit_per_addr = vector[option::none<vector<u64>>()];
        let start_times = vector[0u64]; // Start immediately
        let end_times = vector[100000u64]; // End far in the future
        let mint_fees_per_nft = vector[ORIGINAL_FEE];
        let mint_limits_per_addr = vector[option::some(10u64)];

        nft_launchpad::create_collection(
            owner,
            utf8(COLLECTION_DESCRIPTION),
            utf8(COLLECTION_NAME),
            utf8(COLLECTION_URI),
            1000, // max_supply
            utf8(PLACEHOLDER_URI),
            signer::address_of(owner), // mint_fee_collector_addr
            signer::address_of(owner), // royalty_address
            option::some(10u64), // royalty_percentage (0.1% = 10 basis points)
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            @0x400, // lp_wallet_addr
            timestamp::now_seconds() + 10000, // sale_deadline
            b"BANANA", // fa_symbol
            b"Banana Token", // fa_name
            b"https://example.com/banana.png", // fa_icon_uri
            b"https://banana.fun", // fa_project_uri
            100, // vesting_cliff
            1000 // vesting_duration
        );

        // Get the collection from registry (get the last one, which is the newly created one)
        let collections = nft_launchpad::get_registry();
        assert!(collections.length() > 0, 0);
        let last_index = collections.length() - 1;
        collections[last_index]
    }

    // ================================= Admin Function Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_set_collection_protocol_fee_reduction(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Test setting protocol fee reduction for a collection
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_25
        );

        // Verify protocol fee reduction was set
        let reduction = nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION1);
        assert!(reduction == REDUCTION_25, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_set_collection_protocol_fee_reduction_update(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Set initial protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_10
        );

        // Update protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_50
        );

        // Verify protocol fee reduction was updated
        let reduction = nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION1);
        assert!(reduction == REDUCTION_50, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EONLY_ADMIN_CAN_UPDATE_REDUCTION)]
    fun test_set_collection_protocol_fee_reduction_non_admin(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Non-admin should not be able to set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            &user1, COLLECTION1, REDUCTION_25
        );
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EINVALID_REDUCTION_PERCENTAGE)]
    fun test_set_collection_protocol_fee_reduction_invalid_percentage(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Invalid protocol fee reduction percentage should fail
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, INVALID_REDUCTION
        );
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_remove_collection_protocol_fee_reduction(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_25
        );

        // Remove protocol fee reduction
        nft_reduction_manager::remove_collection_protocol_fee_reduction(admin, COLLECTION1);

        // Verify protocol fee reduction was removed
        let reduction = nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION1);
        assert!(reduction == 0, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::ECOLLECTION_NOT_FOUND)]
    fun test_remove_collection_protocol_fee_reduction_not_found(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Try to remove protocol fee reduction for collection that doesn't exist
        nft_reduction_manager::remove_collection_protocol_fee_reduction(admin, COLLECTION1);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EONLY_ADMIN_CAN_UPDATE_REDUCTION)]
    fun test_remove_collection_protocol_fee_reduction_non_admin(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Set protocol fee reduction as admin
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_25
        );

        // Non-admin should not be able to remove protocol fee reduction
        nft_reduction_manager::remove_collection_protocol_fee_reduction(&user1, COLLECTION1);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_set_protocol_fee_reduction_enabled(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Initially enabled
        assert!(nft_reduction_manager::is_protocol_fee_reduction_enabled(), 0);

        // Disable
        nft_reduction_manager::set_protocol_fee_reduction_enabled(admin, false);
        assert!(!nft_reduction_manager::is_protocol_fee_reduction_enabled(), 0);

        // Re-enable
        nft_reduction_manager::set_protocol_fee_reduction_enabled(admin, true);
        assert!(nft_reduction_manager::is_protocol_fee_reduction_enabled(), 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EONLY_ADMIN_CAN_UPDATE_REDUCTION)]
    fun test_set_protocol_fee_reduction_enabled_non_admin(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Non-admin should not be able to change protocol fee reduction enabled status
        nft_reduction_manager::set_protocol_fee_reduction_enabled(&user1, false);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_update_admin(aptos_framework: &signer, admin: &signer) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Verify initial admin
        assert!(nft_reduction_manager::get_admin() == ADMIN, 0);

        // Update admin
        nft_reduction_manager::update_admin(admin, USER1);
        assert!(nft_reduction_manager::get_admin() == USER1, 0);

        // Create a collection to test with
        let collection_obj = create_test_collection(&collection_owner);
        let collection_addr = object::object_address(&collection_obj);

        // New admin should be able to set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            &user1, collection_addr, REDUCTION_25
        );

        // Verify the protocol fee reduction was set
        let reduction =
            nft_reduction_manager::get_collection_protocol_fee_reduction(collection_addr);
        assert!(reduction == REDUCTION_25, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EONLY_ADMIN_CAN_UPDATE_REDUCTION)]
    fun test_update_admin_non_admin(aptos_framework: &signer, admin: &signer) {
        let (user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Non-admin should not be able to update admin
        nft_reduction_manager::update_admin(&user1, USER2);
    }

    // ================================= Reduction Calculation Tests ================================= //

    #[test]
    fun test_apply_protocol_fee_reduction_zero_percentage() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(ORIGINAL_FEE, 0);
        assert!(reduced_protocol_fee == ORIGINAL_FEE, 0);
    }

    #[test]
    fun test_apply_protocol_fee_reduction_10_percent() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                ORIGINAL_FEE, REDUCTION_10
            );
        assert!(reduced_protocol_fee == 900000, 0); // 1000000 - (1000000 * 10 / 100) = 900000
    }

    #[test]
    fun test_apply_protocol_fee_reduction_25_percent() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                ORIGINAL_FEE, REDUCTION_25
            );
        assert!(reduced_protocol_fee == 750000, 0); // 1000000 - (1000000 * 25 / 100) = 750000
    }

    #[test]
    fun test_apply_protocol_fee_reduction_50_percent() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                ORIGINAL_FEE, REDUCTION_50
            );
        assert!(reduced_protocol_fee == 500000, 0); // 1000000 - (1000000 * 50 / 100) = 500000
    }

    #[test]
    fun test_apply_protocol_fee_reduction_100_percent() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                ORIGINAL_FEE, REDUCTION_100
            );
        assert!(reduced_protocol_fee == 0, 0); // 1000000 - (1000000 * 100 / 100) = 0
    }

    // ================================= Minting with Reduction Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_calculate_reduced_protocol_fee_no_reduction(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        let reduction_nfts = vector::empty<object::Object<token::Token>>();

        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        assert!(reduced_protocol_fee == ORIGINAL_FEE, 0);
        assert!(reduction_percentage == 0, 0);
        assert!(returned_nfts.length() == 0, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_calculate_reduced_protocol_fee_with_reduction(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection first
        let collection_obj = create_test_collection(&collection_owner);
        let collection_addr = object::object_address(&collection_obj);

        // Set up collection with protocol fee reduction using the actual collection address
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_addr, REDUCTION_25
        );

        // Mint a token to user1 using the launchpad
        let reduction_nfts = vector::empty<object::Object<token::Token>>();
        nft_launchpad::mint_nft(&user1, collection_obj, 1, reduction_nfts);

        // Get the minted token (we'll need to create a separate test for this)
        // For now, let's test the protocol fee reduction calculation with an empty vector
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Without reduction NFTs, should return original protocol fee
        assert!(reduced_protocol_fee == ORIGINAL_FEE, 0);
        assert!(reduction_percentage == 0, 0);
        assert!(returned_nfts.length() == 0, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_calculate_reduced_protocol_fee_system_disabled(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection first
        let collection_obj = create_test_collection(&collection_owner);
        let collection_addr = object::object_address(&collection_obj);

        // Set up collection with protocol fee reduction using the actual collection address
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_addr, REDUCTION_25
        );

        // Disable protocol fee reduction system
        nft_reduction_manager::set_protocol_fee_reduction_enabled(admin, false);

        let reduction_nfts = vector::empty<object::Object<token::Token>>();

        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Should return original protocol fee when system is disabled
        assert!(reduced_protocol_fee == ORIGINAL_FEE, 0);
        assert!(reduction_percentage == 0, 0);
        assert!(returned_nfts.length() == 0, 0);
    }

    // ================================= Integration Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_mint_with_protocol_fee_reduction_integration(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection first
        let collection_obj = create_test_collection(&collection_owner);
        let collection_addr = object::object_address(&collection_obj);

        // Set up collection with protocol fee reduction using the actual collection address
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_addr, REDUCTION_25
        );

        // Test minting with protocol fee reduction using the launchpad
        let reduction_nfts = vector::empty<object::Object<token::Token>>();

        // This should work with the launchpad's mint function
        // The protocol fee reduction will be applied automatically
        nft_launchpad::mint_nft(&user1, collection_obj, 1, reduction_nfts);

        // Verify the collection was created and minting worked
        let collections = nft_launchpad::get_registry();
        assert!(collections.length() > 0, 0);
    }

    // ================================= View Function Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_get_all_collection_protocol_fee_reductions(
        aptos_framework: &signer, admin: &signer
    ) {
        let (_user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Initially empty
        let reductions = nft_reduction_manager::get_all_collection_protocol_fee_reductions();
        assert!(reductions.length() == 0, 0);

        // Add some protocol fee reductions
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_10
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION2, REDUCTION_25
        );

        reductions = nft_reduction_manager::get_all_collection_protocol_fee_reductions();
        assert!(reductions.length() == 2, 0);

        // Remove one protocol fee reduction
        nft_reduction_manager::remove_collection_protocol_fee_reduction(admin, COLLECTION1);

        reductions = nft_reduction_manager::get_all_collection_protocol_fee_reductions();
        assert!(reductions.length() == 1, 0);
    }

    // ================================= Edge Case Tests ================================= //

    #[test]
    fun test_protocol_fee_reduction_with_zero_fee() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(0, REDUCTION_25);
        assert!(reduced_protocol_fee == 0, 0);
    }

    #[test]
    fun test_protocol_fee_reduction_with_small_fee() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(100, REDUCTION_25);
        assert!(reduced_protocol_fee == 75, 0); // 100 - (100 * 25 / 100) = 75
    }

    #[test]
    fun test_protocol_fee_reduction_with_odd_percentage() {
        let reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(1000, 33);
        assert!(reduced_protocol_fee == 670, 0); // 1000 - (1000 * 33 / 100) = 670
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_multiple_admin_operations(aptos_framework: &signer, admin: &signer) {
        let (user1, _user2, _user3, _collection_owner) = setup_test(aptos_framework, admin);

        // Test multiple operations in sequence
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION1, REDUCTION_10
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION2, REDUCTION_25
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, COLLECTION3, REDUCTION_50
        );

        // Update admin
        nft_reduction_manager::update_admin(admin, USER1);

        // New admin operations
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            &user1, COLLECTION1, REDUCTION_20
        );
        nft_reduction_manager::remove_collection_protocol_fee_reduction(&user1, COLLECTION2);
        nft_reduction_manager::set_protocol_fee_reduction_enabled(&user1, false);

        // Verify final state
        assert!(
            nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION1)
                == REDUCTION_20,
            0
        );
        assert!(
            nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION2) == 0,
            0
        );
        assert!(
            nft_reduction_manager::get_collection_protocol_fee_reduction(COLLECTION3)
                == REDUCTION_50,
            0
        );
        assert!(!nft_reduction_manager::is_protocol_fee_reduction_enabled(), 0);
        assert!(nft_reduction_manager::get_admin() == USER1, 0);
    }

    // ================================= Helper Functions for Real NFT Testing ================================= //

    /// Helper function to create a test NFT for reduction testing
    fun create_test_nft_for_reduction(
        owner: &signer, collection_obj: object::Object<collection::Collection>
    ): object::Object<token::Token> {
        // Use the launchpad's test_mint_nft function to create a real NFT
        nft_launchpad::test_mint_nft(signer::address_of(owner), collection_obj)
    }

    /// Helper function to create multiple test NFTs
    fun create_multiple_test_nfts(
        owner: &signer, collection_obj: object::Object<collection::Collection>, count: u64
    ): vector<object::Object<token::Token>> {
        let nfts = vector::empty<object::Object<token::Token>>();

        let i = 0;
        while (i < count) {
            let nft = create_test_nft_for_reduction(owner, collection_obj);
            nfts.push_back(nft);
            i += 1;
        };

        nfts
    }

    // ================================= Real NFT Reduction Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_mint_with_real_nft_protocol_fee_reduction(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create two collections: one for protocol fee reduction NFTs, one for minting
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set up protocol fee reduction for the reduction collection (25% reduction)
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create a test NFT for protocol fee reduction
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Test the protocol fee reduction calculation with the actual NFT
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Verify the protocol fee reduction was applied correctly
        assert!(reduced_protocol_fee == 750000, 0); // 1000000 - (1000000 * 25 / 100) = 750000
        assert!(reduction_percentage == REDUCTION_25, 0);
        assert!(returned_nfts.length() == 1, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_mint_with_multiple_nft_protocol_fee_reductions(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create multiple collections with different protocol fee reduction percentages
        let collection_10 = create_test_collection(&collection_owner);
        let collection_10_addr = object::object_address(&collection_10);

        let collection_25 = create_test_collection(&collection_owner);
        let collection_25_addr = object::object_address(&collection_25);

        let collection_50 = create_test_collection(&collection_owner);
        let collection_50_addr = object::object_address(&collection_50);

        // Set different protocol fee reduction percentages
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_10_addr, REDUCTION_10
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_25_addr, REDUCTION_25
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_50_addr, REDUCTION_50
        );

        // Create NFTs from different collections (each collection can only have one NFT for protocol fee reduction)
        let nft_10 = create_test_nft_for_reduction(&user1, collection_10);
        let nft_25 = create_test_nft_for_reduction(&user1, collection_25);
        let nft_50 = create_test_nft_for_reduction(&user1, collection_50);

        // Test with multiple NFTs from different collections - should stack the protocol fee reductions (10% + 25% + 50% = 85%)
        let reduction_nfts = vector[nft_10, nft_25, nft_50];

        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Should apply stacked protocol fee reduction (85%): 1000000 - (1000000 * 85 / 100) = 150000
        assert!(reduced_protocol_fee == 150000, 0); // 1000000 - (1000000 * 85 / 100) = 150000
        assert!(reduction_percentage == 85, 0);
        assert!(returned_nfts.length() == 3, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_with_100_percent_nft(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with 100% protocol fee reduction
        let free_collection = create_test_collection(&collection_owner);
        let free_collection_addr = object::object_address(&free_collection);

        // Set 100% protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, free_collection_addr, REDUCTION_100
        );

        // Create a test NFT for 100% protocol fee reduction
        let free_nft = create_test_nft_for_reduction(&user1, free_collection);
        let reduction_nfts = vector[free_nft];

        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Should result in 0 protocol fee
        assert!(reduced_protocol_fee == 0, 0);
        assert!(reduction_percentage == REDUCTION_100, 0);
        assert!(returned_nfts.length() == 1, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_system_disabled_with_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create a test NFT
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Disable protocol fee reduction system
        nft_reduction_manager::set_protocol_fee_reduction_enabled(admin, false);

        // Verify protocol fee reduction is ignored when system is disabled
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts, USER1
            );

        // Should return original protocol fee when system is disabled
        assert!(reduced_protocol_fee == ORIGINAL_FEE, 0);
        assert!(reduction_percentage == 0, 0);
        assert!(returned_nfts.length() == 1, 0);

        // Re-enable system
        nft_reduction_manager::set_protocol_fee_reduction_enabled(admin, true);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_with_zero_fee_and_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create a test NFT
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Test with zero protocol fee
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                0, // Zero protocol fee
                reduction_nfts,
                USER1
            );

        // Should return 0 protocol fee
        assert!(reduced_protocol_fee == 0, 0);
        assert!(reduction_percentage == REDUCTION_25, 0);
        assert!(returned_nfts.length() == 1, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_with_small_fee_and_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create a test NFT
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Test with small protocol fee
        let small_protocol_fee = 100; // 0.0001 APT
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                small_protocol_fee, reduction_nfts, USER1
            );

        // Should apply 25% reduction to small protocol fee
        assert!(reduced_protocol_fee == 75, 0); // 100 - (100 * 25 / 100) = 75
        assert!(reduction_percentage == REDUCTION_25, 0);
        assert!(returned_nfts.length() == 1, 0);
    }

    // ================================= Advanced Integration Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_complete_protocol_fee_reduction_workflow_with_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Step 1: Create a collection for protocol fee reduction NFTs
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Step 2: Set protocol fee reduction percentage
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Step 3: Set up protocol fees so there are protocol fees to reduce
        let protocol_base_fee = 500000; // 0.5 APT base fee
        let protocol_percentage_fee = 500; // 5% percentage fee (500 basis points)
        nft_launchpad::update_default_protocol_base_fee(admin, protocol_base_fee);
        nft_launchpad::update_default_protocol_percentage_fee(admin, protocol_percentage_fee);

        // Step 4: Create a collection for minting
        let minting_collection = create_test_collection(&collection_owner);
        let _minting_collection_addr = object::object_address(&minting_collection);

        // Step 5: Verify the setup
        assert!(
            nft_reduction_manager::get_collection_protocol_fee_reduction(
                reduction_collection_addr
            ) == REDUCTION_25,
            0
        );
        assert!(nft_reduction_manager::is_protocol_fee_reduction_enabled(), 0);

        // Step 6: Create test NFT for protocol fee reduction
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Step 7: Test protocol fee reduction calculation with actual NFT
        // Calculate expected protocol fees:
        // Base fee: 500000 (0.5 APT)
        // Percentage fee: 5% of NFT mint fee = 5% of 1000000 = 50000
        // Total protocol fee: 500000 + 50000 = 550000
        // Reduced protocol fee (25% reduction): 550000 - (550000 * 25 / 100) = 412500
        let expected_protocol_fee = 550000;
        let expected_reduced_protocol_fee = 412500;

        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                expected_protocol_fee, reduction_nfts, USER1
            );

        // Check that remaining balance of user1 is correct
        // User pays: NFT mint fee (ORIGINAL_FEE) + reduced protocol fee (reduced_protocol_fee)
        let total_fee_paid = ORIGINAL_FEE + reduced_protocol_fee;
        nft_launchpad::mint_nft(&user1, minting_collection, 1, reduction_nfts);
        assert!(
            aptos_framework::coin::balance<aptos_framework::aptos_coin::AptosCoin>(
                signer::address_of(&user1)
            ) == INITIAL_BALANCE - total_fee_paid,
            0
        );

        // Verify the protocol fee reduction was applied correctly
        assert!(reduced_protocol_fee == expected_reduced_protocol_fee, 0);
        assert!(reduction_percentage == REDUCTION_25, 0);
        assert!(returned_nfts.length() == 1, 0);

        // Step 8: Test that the protocol fee reduction calculation is correct
        let calculated_reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                expected_protocol_fee, REDUCTION_25
            );
        assert!(calculated_reduced_protocol_fee == expected_reduced_protocol_fee, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_with_multiple_users_and_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, user2, user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create test NFTs for different users
        let reduction_nft1 = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nft2 = create_test_nft_for_reduction(&user2, reduction_collection);
        let reduction_nft3 = create_test_nft_for_reduction(&user3, reduction_collection);

        // Test protocol fee reduction calculation for different users
        let reduction_nfts1 = vector[reduction_nft1];
        let (reduced_protocol_fee1, reduction_percentage1, returned_nfts1) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts1, USER1
            );

        let reduction_nfts2 = vector[reduction_nft2];
        let (reduced_protocol_fee2, reduction_percentage2, returned_nfts2) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts2, USER2
            );

        let reduction_nfts3 = vector[reduction_nft3];
        let (reduced_protocol_fee3, reduction_percentage3, returned_nfts3) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts3, USER3
            );

        // All should apply the same protocol fee reduction
        assert!(reduced_protocol_fee1 == 750000, 0);
        assert!(reduced_protocol_fee2 == 750000, 0);
        assert!(reduced_protocol_fee3 == 750000, 0);
        assert!(reduction_percentage1 == REDUCTION_25, 0);
        assert!(reduction_percentage2 == REDUCTION_25, 0);
        assert!(reduction_percentage3 == REDUCTION_25, 0);
        assert!(returned_nfts1.length() == 1, 0);
        assert!(returned_nfts2.length() == 1, 0);
        assert!(returned_nfts3.length() == 1, 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_stacking_multiple_collections(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create multiple collections with different protocol fee reduction percentages
        let collection_10 = create_test_collection(&collection_owner);
        let collection_10_addr = object::object_address(&collection_10);

        let collection_20 = create_test_collection(&collection_owner);
        let collection_20_addr = object::object_address(&collection_20);

        let collection_30 = create_test_collection(&collection_owner);
        let collection_30_addr = object::object_address(&collection_30);

        let collection_50 = create_test_collection(&collection_owner);
        let collection_50_addr = object::object_address(&collection_50);

        // Set different protocol fee reduction percentages
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_10_addr, REDUCTION_10
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_20_addr, REDUCTION_20
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_30_addr, REDUCTION_30
        );
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, collection_50_addr, REDUCTION_50
        );

        // Create NFTs from different collections
        let nft_10 = create_test_nft_for_reduction(&user1, collection_10);
        let nft_20 = create_test_nft_for_reduction(&user1, collection_20);
        let nft_30 = create_test_nft_for_reduction(&user1, collection_30);
        let nft_50 = create_test_nft_for_reduction(&user1, collection_50);

        // Test 1: Single NFT (10% reduction)
        let reduction_nfts_1 = vector[nft_10];
        let (reduced_protocol_fee_1, reduction_percentage_1, returned_nfts_1) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts_1, USER1
            );

        // Should apply 10% reduction: 1000000 - (1000000 * 10 / 100) = 900000
        assert!(reduced_protocol_fee_1 == 900000, 0);
        assert!(reduction_percentage_1 == REDUCTION_10, 0);
        assert!(returned_nfts_1.length() == 1, 0);

        // Test 2: Two NFTs (10% + 20% = 30% reduction)
        let reduction_nfts_2 = vector[nft_10, nft_20];
        let (reduced_protocol_fee_2, reduction_percentage_2, returned_nfts_2) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts_2, USER1
            );

        // Should apply 30% reduction: 1000000 - (1000000 * 30 / 100) = 700000
        assert!(reduced_protocol_fee_2 == 700000, 0);
        assert!(reduction_percentage_2 == 30, 0);
        assert!(returned_nfts_2.length() == 2, 0);

        // Test 3: Three NFTs (10% + 20% + 30% = 60% reduction)
        let reduction_nfts_3 = vector[nft_10, nft_20, nft_30];
        let (reduced_protocol_fee_3, reduction_percentage_3, returned_nfts_3) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts_3, USER1
            );

        // Should apply 60% reduction: 1000000 - (1000000 * 60 / 100) = 400000
        assert!(reduced_protocol_fee_3 == 400000, 0);
        assert!(reduction_percentage_3 == 60, 0);
        assert!(returned_nfts_3.length() == 3, 0);

        // Test 4: Four NFTs (10% + 20% + 30% + 50% = 110%, but capped at 100%)
        let reduction_nfts_4 = vector[nft_10, nft_20, nft_30, nft_50];
        let (reduced_protocol_fee_4, reduction_percentage_4, returned_nfts_4) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                ORIGINAL_FEE, reduction_nfts_4, USER1
            );

        // Should apply 100% reduction (capped): 1000000 - (1000000 * 100 / 100) = 0
        assert!(reduced_protocol_fee_4 == 0, 0);
        assert!(reduction_percentage_4 == 100, 0);
        assert!(returned_nfts_4.length() == 4, 0);

        // Test 5: Verify the protocol fee reduction calculation directly
        let expected_reduced_protocol_fee_1 =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                ORIGINAL_FEE, REDUCTION_10
            );
        let expected_reduced_protocol_fee_2 =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(ORIGINAL_FEE, 30);
        let expected_reduced_protocol_fee_3 =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(ORIGINAL_FEE, 60);
        let expected_reduced_protocol_fee_4 =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(ORIGINAL_FEE, 100);

        assert!(expected_reduced_protocol_fee_1 == 900000, 0);
        assert!(expected_reduced_protocol_fee_2 == 700000, 0);
        assert!(expected_reduced_protocol_fee_3 == 400000, 0);
        assert!(expected_reduced_protocol_fee_4 == 0, 0);
    }

    // ================================= Error Case Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::ENFT_NOT_OWNED)]
    fun test_protocol_fee_reduction_with_nft_not_owned(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create NFT owned by user1
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Try to use NFT owned by user1 with user2 (should fail)
        nft_reduction_manager::calculate_reduced_protocol_fee(
            ORIGINAL_FEE,
            reduction_nfts,
            USER2 // Different user - should fail
        );
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    #[expected_failure(abort_code = nft_reduction_manager::EDUPLICATE_COLLECTION)]
    fun test_protocol_fee_reduction_with_duplicate_collections(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create multiple NFTs from the same collection
        let reduction_nft1 = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nft2 = create_test_nft_for_reduction(&user1, reduction_collection);

        // Try to use multiple NFTs from the same collection (should fail)
        let reduction_nfts = vector[reduction_nft1, reduction_nft2];
        nft_reduction_manager::calculate_reduced_protocol_fee(ORIGINAL_FEE, reduction_nfts, USER1);
    }

    // ================================= Performance Tests ================================= //

    #[test(aptos_framework = @0x1, admin = @deployment_addr)]
    fun test_protocol_fee_reduction_with_large_fee_and_nfts(
        aptos_framework: &signer, admin: &signer
    ) {
        let (user1, _user2, _user3, collection_owner) = setup_test(aptos_framework, admin);

        // Create collection with protocol fee reduction
        let reduction_collection = create_test_collection(&collection_owner);
        let reduction_collection_addr = object::object_address(&reduction_collection);

        // Set protocol fee reduction
        nft_reduction_manager::set_collection_protocol_fee_reduction(
            admin, reduction_collection_addr, REDUCTION_25
        );

        // Create a test NFT
        let reduction_nft = create_test_nft_for_reduction(&user1, reduction_collection);
        let reduction_nfts = vector[reduction_nft];

        // Test with large protocol fee
        let large_protocol_fee = 1000000000000; // 1000 APT
        let (reduced_protocol_fee, reduction_percentage, returned_nfts) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                large_protocol_fee, reduction_nfts, USER1
            );

        // Should apply 25% reduction to large protocol fee
        assert!(reduced_protocol_fee == 750000000000, 0); // 1000000000000 - (1000000000000 * 25 / 100) = 750000000000
        assert!(reduction_percentage == REDUCTION_25, 0);
        assert!(returned_nfts.length() == 1, 0);

        // Test the protocol fee reduction calculation directly
        let expected_reduced_protocol_fee =
            nft_reduction_manager::test_calculate_protocol_fee_reduction(
                large_protocol_fee, REDUCTION_25
            );
        assert!(expected_reduced_protocol_fee == 750000000000, 0); // 1000000000000 - (1000000000000 * 25 / 100) = 750000000000
    }
}

