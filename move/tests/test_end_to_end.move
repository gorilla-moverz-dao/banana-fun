#[test_only]
module deployment_addr::test_end_to_end {
    use std::option;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::debug;

    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin::{Self};
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::object;

    use aptos_token_objects::collection;

    use deployment_addr::nft_launchpad;
    use deployment_addr::nft_reduction_manager;
    use deployment_addr::vesting;

    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset;
    use aptos_framework::aptos_coin::mint_apt_fa_for_test;

    // Test addresses
    const ADMIN: address = @deployment_addr;
    const USER1: address = @0x200;
    const USER2: address = @0x201;
    const ROYALTY_USER: address = @0x300;
    const USER3: address = @0x123;

    // Test constants
    const BASE_FEE: u64 = 100000000; // 1 APT in octas
    const MINT_FEE_SMALL: u64 = 2u64;
    const MINT_FEE_MEDIUM: u64 = 3u64;
    const MINT_FEE_LARGE: u64 = 10u64;
    const MINT_FEE_XLARGE: u64 = 100u64;
    const PROTOCOL_BASE_FEE: u64 = 5u64;
    const PROTOCOL_BASE_FEE_LARGE: u64 = 10u64;
    const PROTOCOL_PERCENTAGE_FEE_SMALL: u64 = 250; // 2.5% in basis points
    const PROTOCOL_PERCENTAGE_FEE_MEDIUM: u64 = 500; // 5% in basis points
    const PROTOCOL_PERCENTAGE_FEE_LARGE: u64 = 1000; // 10% in basis points
    const ROYALTY_PERCENTAGE: u64 = 10u64;
    const MAX_SUPPLY: u64 = 10u64;
    const MINT_LIMIT_SMALL: u64 = 1u64;
    const MINT_LIMIT_MEDIUM: u64 = 2u64;
    const MINT_LIMIT_LARGE: u64 = 5u64;
    const MINT_LIMIT_XLARGE: u64 = 20u64;
    const DURATION_SHORT: u64 = 100u64;
    const DURATION_MEDIUM: u64 = 200u64;
    const DURATION_LONG: u64 = 500u64;
    const DURATION_XLONG: u64 = 900u64;
    const DURATION_XXLONG: u64 = 1000u64;
    const PREMINT_AMOUNT_SMALL: u64 = 2u64;
    const PREMINT_AMOUNT_MEDIUM: u64 = 3u64;
    const PREMINT_AMOUNT_LARGE: u64 = 5u64;
    const PREMINT_AMOUNT_ZERO: u64 = 0u64;

    // Sale configuration constants
    const LP_WALLET: address = @0x400;
    const SALE_DEADLINE_OFFSET: u64 = 10000u64; // 10000 seconds from now

    // Fungible asset configuration for tests
    const FA_SYMBOL: vector<u8> = b"BANANA";
    const FA_NAME: vector<u8> = b"Banana Token";
    const FA_ICON_URI: vector<u8> = b"https://example.com/banana.png";
    const FA_PROJECT_URI: vector<u8> = b"https://banana.fun";

    // Vesting configuration
    const VESTING_CLIFF: u64 = 100u64; // 100 seconds cliff
    const VESTING_DURATION: u64 = 1000u64; // 1000 seconds total duration

    // Stage types
    const STAGE_TYPE_ALLOWLIST: u8 = 1u8;
    const STAGE_TYPE_PUBLIC: u8 = 2u8;

    // Stage names
    const STAGE_NAME_ALLOWLIST: vector<u8> = b"FCFS allowlist mint stage";
    const STAGE_NAME_PUBLIC: vector<u8> = b"Public mint stage";
    const STAGE_NAME_GUARANTEED_ALLOWLIST: vector<u8> = b"Guaranteed allowlist mint stage";
    const STAGE_NAME_ALLOWLIST_ONLY: vector<u8> = b"Allowlist mint stage";

    // Collection metadata
    const COLLECTION_NAME: vector<u8> = b"Test Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Test collection description";
    const COLLECTION_URI: vector<u8> = b"https://gateway.irys.xyz/manifest_id/collection.json";
    const REVEALED_NAME: vector<u8> = b"revealed name";
    const REVEALED_DESCRIPTION: vector<u8> = b"revealed description";
    const REVEALED_URI: vector<u8> = b"https://gateway.irys.xyz/manifest_id/revealed.json";
    const PROPERTY_NAME: vector<u8> = b"property1";
    const PROPERTY_VALUE: vector<u8> = b"value1";
    const PLACEHOLDER_URI: vector<u8> = b"https://gateway.irys.xyz/manifest_id/placeholder.json";

    /// Helper function to create a collection with sensible defaults
    /// Most parameters have reasonable defaults, only specify what you need to customize
    fun create_test_collection(
        sender: &signer,
        royalty_user: &signer,
        stage_names: vector<string::String>,
        stage_types: vector<u8>,
        allowlist_addresses: vector<option::Option<vector<address>>>,
        allowlist_mint_limit_per_addr: vector<option::Option<vector<u64>>>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        mint_fees_per_nft: vector<u64>,
        mint_limits_per_addr: vector<option::Option<u64>>,
        premint_amount: u64
    ): object::Object<collection::Collection> {
        nft_launchpad::create_collection(
            sender,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(sender),
            signer::address_of(royalty_user),
            option::some(ROYALTY_PERCENTAGE),
            option::some(premint_amount), // premint amount
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            LP_WALLET,
            timestamp::now_seconds() + SALE_DEADLINE_OFFSET,
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        registry[vector::length(&registry) - 1]
    }

    /// Helper function to create a simple public-only collection
    public fun create_public_only_collection(
        sender: &signer,
        royalty_user: &signer,
        mint_fee: u64,
        mint_limit: u64,
        duration: u64
    ): object::Object<collection::Collection> {
        let stage_names = vector[string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::none()];
        let allowlist_mint_limit_per_addr = vector[option::none()];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + duration];
        let mint_fees_per_nft = vector[mint_fee];
        let mint_limits_per_addr = vector[option::some(mint_limit)];

        create_test_collection(
            sender,
            royalty_user,
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            0
        )
    }

    /// Helper function to create a simple allowlist-only collection
    fun create_allowlist_only_collection(
        sender: &signer,
        royalty_user: &signer,
        allowlist_addresses: vector<address>,
        allowlist_mint_limits: vector<u64>,
        mint_fee: u64,
        duration: u64
    ): object::Object<collection::Collection> {
        let stage_names = vector[string::utf8(STAGE_NAME_ALLOWLIST_ONLY)];
        let stage_types = vector[STAGE_TYPE_ALLOWLIST];
        let allowlist_addresses_vec = vector[option::some(allowlist_addresses)];
        let allowlist_mint_limit_per_addr = vector[option::some(allowlist_mint_limits)];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + duration];
        let mint_fees_per_nft = vector[mint_fee];
        let mint_limits_per_addr = vector[option::none()];

        create_test_collection(
            sender,
            royalty_user,
            stage_names,
            stage_types,
            allowlist_addresses_vec,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            0 // default premint amount
        )
    }

    /// Helper function to create a collection with allowlist followed by public stage
    fun create_allowlist_then_public_collection(
        sender: &signer,
        royalty_user: &signer,
        allowlist_addresses: vector<address>,
        allowlist_mint_limits: vector<u64>,
        allowlist_mint_fee: u64,
        public_mint_fee: u64,
        public_mint_limit: u64,
        allowlist_duration: u64,
        public_duration: u64,
        premint_amount: u64
    ): object::Object<collection::Collection> {
        let stage_names = vector[string::utf8(STAGE_NAME_ALLOWLIST), string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_ALLOWLIST, STAGE_TYPE_PUBLIC];
        let allowlist_addresses_vec = vector[option::some(allowlist_addresses), option::none()];
        let allowlist_mint_limit_per_addr = vector[option::some(allowlist_mint_limits), option::none()];
        let start_times = vector[timestamp::now_seconds(), timestamp::now_seconds()
            + allowlist_duration];
        let end_times = vector[
            timestamp::now_seconds() + allowlist_duration,
            timestamp::now_seconds() + allowlist_duration + public_duration
        ];
        let mint_fees_per_nft = vector[allowlist_mint_fee, public_mint_fee];
        let mint_limits_per_addr = vector[option::none(), option::some(public_mint_limit)];

        create_test_collection(
            sender,
            royalty_user,
            stage_names,
            stage_types,
            allowlist_addresses_vec,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            premint_amount
        )
    }

    #[
        test(
            aptos_framework = @0x1,
            sender = @deployment_addr,
            user1 = @0x200,
            user2 = @0x201,
            royalty_user = @0x300
        )
    ]
    fun test_happy_path(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);

        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);

        let stage_names = vector[
            string::utf8(STAGE_NAME_GUARANTEED_ALLOWLIST),
            string::utf8(STAGE_NAME_ALLOWLIST),
            string::utf8(STAGE_NAME_PUBLIC)
        ];
        let stage_types = vector[STAGE_TYPE_ALLOWLIST, STAGE_TYPE_ALLOWLIST, STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[
            option::some(vector[user1_addr]),
            option::some(vector[user2_addr]),
            option::none()
        ];
        let allowlist_mint_limit_per_addr = vector[
            option::some(vector[MINT_LIMIT_SMALL]),
            option::some(vector[MINT_LIMIT_SMALL]),
            option::none()
        ];

        let start_times = vector[
            timestamp::now_seconds(),
            timestamp::now_seconds() + DURATION_MEDIUM,
            timestamp::now_seconds() + DURATION_LONG
        ];
        let end_times = vector[
            timestamp::now_seconds() + DURATION_SHORT,
            timestamp::now_seconds() + DURATION_MEDIUM + DURATION_SHORT,
            timestamp::now_seconds() + DURATION_LONG + DURATION_SHORT
        ];
        let mint_fees_per_nft = vector[MINT_FEE_MEDIUM, MINT_FEE_MEDIUM, MINT_FEE_LARGE];
        let mint_limits_per_addr = vector[option::none(), option::none(), option::some(
            MINT_LIMIT_MEDIUM
        )];

        nft_launchpad::create_collection(
            sender,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(royalty_user),
            signer::address_of(sender),
            option::some(ROYALTY_PERCENTAGE),
            option::some(PREMINT_AMOUNT_MEDIUM),
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            LP_WALLET,
            timestamp::now_seconds() + SALE_DEADLINE_OFFSET,
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );
        let registry = nft_launchpad::get_registry();
        let collection_1 = registry[vector::length(&registry) - 1];
        assert!(collection::count(collection_1) == option::some(3), 1);

        let total_fee = get_total_mint_fee(collection_1, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        mint(user1_addr, total_fee);

        nft_launchpad::mint_nft(user1, collection_1, 1, vector[]);

        let active_or_next_stage = nft_launchpad::get_active_or_next_mint_stage(collection_1);
        assert!(
            active_or_next_stage == option::some(string::utf8(STAGE_NAME_GUARANTEED_ALLOWLIST)),
            3
        );
        let (start_time, end_time) =
            nft_launchpad::get_mint_stage_start_and_end_time(
                collection_1, string::utf8(STAGE_NAME_GUARANTEED_ALLOWLIST)
            );
        assert!(start_time == 0, 4);
        assert!(end_time == DURATION_SHORT, 5);

        // bump global timestamp to 150 so allowlist stage is over but public mint stage is not started yet
        timestamp::update_global_time_for_test_secs(350);
        let active_or_next_stage = nft_launchpad::get_active_or_next_mint_stage(collection_1);
        assert!(active_or_next_stage == option::some(string::utf8(STAGE_NAME_PUBLIC)), 6);
        let (start_time, end_time) =
            nft_launchpad::get_mint_stage_start_and_end_time(
                collection_1, string::utf8(STAGE_NAME_PUBLIC)
            );
        assert!(start_time == DURATION_LONG, 7);
        assert!(end_time == DURATION_LONG + DURATION_SHORT, 8);

        // bump global timestamp to 550 so public mint stage is active
        timestamp::update_global_time_for_test_secs(550);
        let active_or_next_stage = nft_launchpad::get_active_or_next_mint_stage(collection_1);
        assert!(active_or_next_stage == option::some(string::utf8(STAGE_NAME_PUBLIC)), 9);
        let (start_time, end_time) =
            nft_launchpad::get_mint_stage_start_and_end_time(
                collection_1, string::utf8(STAGE_NAME_PUBLIC)
            );
        assert!(start_time == DURATION_LONG, 10);
        assert!(end_time == DURATION_LONG + DURATION_SHORT, 11);

        let total_fee = get_total_mint_fee(collection_1, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        nft_launchpad::mint_nft(user1, collection_1, 1, vector[]);

        // bump global timestamp to 650 so public mint stage is over
        timestamp::update_global_time_for_test_secs(650);
        let active_or_next_stage = nft_launchpad::get_active_or_next_mint_stage(collection_1);
        assert!(active_or_next_stage == option::none(), 12);

    }

    #[test(
        aptos_framework = @0x1, sender = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 12, location = nft_launchpad)]
    fun test_mint_disabled(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);

        let collection_1 =
            create_allowlist_then_public_collection(
                sender,
                royalty_user,
                vector[user1_addr], // allowlist_addresses
                vector[MINT_LIMIT_SMALL], // allowlist_mint_limits
                MINT_FEE_MEDIUM, // allowlist_mint_fee
                MINT_FEE_LARGE, // public_mint_fee
                MINT_LIMIT_MEDIUM, // public_mint_limit
                DURATION_SHORT, // allowlist_duration
                DURATION_SHORT, // public_duration
                PREMINT_AMOUNT_MEDIUM // premint_amount
            );

        assert!(nft_launchpad::is_mint_enabled(collection_1), 1);

        let total_fee = get_total_mint_fee(collection_1, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        mint(user1_addr, total_fee);

        nft_launchpad::mint_nft(user1, collection_1, 1, vector[]);

        nft_launchpad::update_mint_enabled(sender, collection_1, false);
        assert!(!nft_launchpad::is_mint_enabled(collection_1), 2);

        nft_launchpad::mint_nft(user1, collection_1, 1, vector[]);

    }

    #[test(
        aptos_framework = @0x1, sender = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_should_reveal_nft(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);

        let collection_1 =
            create_allowlist_then_public_collection(
                sender,
                royalty_user,
                vector[user1_addr], // allowlist_addresses
                vector[MINT_LIMIT_SMALL], // allowlist_mint_limits
                MINT_FEE_MEDIUM, // allowlist_mint_fee
                MINT_FEE_LARGE, // public_mint_fee
                MINT_LIMIT_MEDIUM, // public_mint_limit
                DURATION_SHORT, // allowlist_duration
                DURATION_SHORT, // public_duration
                PREMINT_AMOUNT_MEDIUM // premint_amount
            );

        assert!(nft_launchpad::is_mint_enabled(collection_1), 1);

        let total_fee = get_total_mint_fee(collection_1, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        mint(user1_addr, total_fee);

        let nft_obj = nft_launchpad::test_mint_nft(user1_addr, collection_1);

        // Prepare batch vectors for reveal_nfts
        let nft_objs = vector[nft_obj];
        let names = vector[string::utf8(REVEALED_NAME)];
        let descriptions = vector[string::utf8(REVEALED_DESCRIPTION)];
        let uris = vector[string::utf8(REVEALED_URI)];
        let prop_names_vec = vector[vector[string::utf8(PROPERTY_NAME)]];
        let prop_values_vec = vector[vector[string::utf8(PROPERTY_VALUE)]];

        nft_launchpad::reveal_nfts(
            sender,
            collection_1,
            nft_objs,
            names,
            descriptions,
            uris,
            prop_names_vec,
            prop_values_vec
        );

        // Re-fetch the NFT object from storage to get updated metadata
        let nft_addr = object::object_address(&nft_obj);
        let refreshed_nft_obj =
            object::address_to_object<aptos_token_objects::token::Token>(nft_addr);

        let token_name = &aptos_token_objects::token::name(refreshed_nft_obj);
        debug::print(token_name);

        assert!(
            aptos_token_objects::token::name(refreshed_nft_obj) == string::utf8(REVEALED_NAME),
            2
        );
        assert!(
            aptos_token_objects::token::description(refreshed_nft_obj)
                == string::utf8(REVEALED_DESCRIPTION),
            3
        );
        assert!(
            aptos_token_objects::token::uri(refreshed_nft_obj) == string::utf8(REVEALED_URI),
            4
        );

    }

    #[
        test(
            aptos_framework = @0x1,
            sender = @deployment_addr,
            user1 = @0x200,
            user2 = @0x201,
            royalty_user = @0x300
        )
    ]
    fun test_mint_stages_transition(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);
        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);
        coin::register<AptosCoin>(user2);

        let stage_names = vector[string::utf8(STAGE_NAME_ALLOWLIST), string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_ALLOWLIST, STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::some(vector[user1_addr]), option::none()];
        let allowlist_mint_limit_per_addr = vector[option::some(vector[MINT_LIMIT_SMALL]), option::none()];
        let start_times = vector[timestamp::now_seconds(), timestamp::now_seconds()
            + DURATION_MEDIUM];
        let end_times = vector[
            timestamp::now_seconds() + DURATION_SHORT,
            timestamp::now_seconds() + DURATION_MEDIUM + DURATION_SHORT
        ];
        let mint_fees_per_nft = vector[MINT_FEE_SMALL, MINT_FEE_MEDIUM];
        let mint_limits_per_addr = vector[option::none(), option::some(MINT_LIMIT_XLARGE)];

        nft_launchpad::create_collection(
            sender,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(royalty_user),
            signer::address_of(sender),
            option::some(ROYALTY_PERCENTAGE),
            option::some(PREMINT_AMOUNT_MEDIUM),
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            LP_WALLET,
            timestamp::now_seconds() + SALE_DEADLINE_OFFSET,
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        let collection = registry[vector::length(&registry) - 1];

        // Test FCFS allowlist stage
        let total_fee = get_total_mint_fee(collection, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        mint(user1_addr, total_fee);
        nft_launchpad::mint_nft(user1, collection, 1, vector[]);
        assert!(collection::count(collection) == option::some(4), 1);

        // Move to public stage
        timestamp::update_global_time_for_test_secs(250);
        let total_fee = get_total_mint_fee(collection, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user2_addr, total_fee);
        nft_launchpad::mint_nft(user2, collection, 1, vector[]);
        debug::print(&collection::count(collection));
        assert!(collection::count(collection) == option::some(5), 2);

    }

    public fun mint(addr: address, amount: u64) {
        primary_fungible_store::deposit(addr, mint_apt_fa_for_test(amount));
    }

    #[test(
        aptos_framework = @0x1, sender = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_mint_fee(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);

        let collection_1 =
            create_allowlist_then_public_collection(
                sender,
                royalty_user,
                vector[user1_addr], // allowlist_addresses
                vector[MINT_LIMIT_SMALL], // allowlist_mint_limits
                MINT_FEE_MEDIUM, // allowlist_mint_fee
                MINT_FEE_SMALL, // public_mint_fee
                MINT_FEE_LARGE, // public_mint_limit
                DURATION_SHORT, // allowlist_duration
                DURATION_SHORT, // public_duration
                PREMINT_AMOUNT_MEDIUM // premint_amount
            );

        // Verify initial mint fee
        let initial_mint_fee =
            nft_launchpad::get_mint_fee(collection_1, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        assert!(initial_mint_fee == MINT_FEE_MEDIUM, 1);

        // Update mint fee to 5
        nft_launchpad::update_mint_fee(
            sender,
            collection_1,
            string::utf8(STAGE_NAME_ALLOWLIST),
            PROTOCOL_BASE_FEE
        );

        // Verify updated mint fee
        let updated_mint_fee =
            nft_launchpad::get_mint_fee(collection_1, string::utf8(STAGE_NAME_ALLOWLIST), 1);
        assert!(updated_mint_fee == PROTOCOL_BASE_FEE, 2);

    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr, user = @0x123)]
    fun test_update_mint_times(
        aptos_framework: &signer, admin: &signer, user: &signer
    ) {
        let (user_addr) = setup_test_env(aptos_framework, user, admin);

        let collection_obj =
            create_allowlist_then_public_collection(
                admin,
                admin, // royalty_user (using admin as royalty user)
                vector[user_addr], // allowlist_addresses
                vector[MINT_LIMIT_SMALL], // allowlist_mint_limits
                MINT_LIMIT_SMALL, // allowlist_mint_fee
                MINT_FEE_SMALL, // public_mint_fee
                MINT_FEE_LARGE, // public_mint_limit
                DURATION_XLONG, // allowlist_duration (1000 - 100)
                DURATION_XXLONG, // public_duration (2000 - 1000)
                PREMINT_AMOUNT_ZERO // premint_amount
            );

        // Verify initial mint times
        let (start_time, end_time) =
            nft_launchpad::get_mint_stage_start_and_end_time(
                collection_obj, string::utf8(STAGE_NAME_ALLOWLIST)
            );
        assert!(start_time == 0, 0); // Helper function starts at now_seconds() which is 0
        assert!(end_time == DURATION_XLONG, 0); // allowlist_duration

        // Update mint times as admin
        nft_launchpad::update_mint_times(
            admin,
            collection_obj,
            string::utf8(STAGE_NAME_ALLOWLIST),
            200, // new start time
            1500 // new end time
        );

        // Verify updated mint times
        let (new_start_time, new_end_time) =
            nft_launchpad::get_mint_stage_start_and_end_time(
                collection_obj, string::utf8(STAGE_NAME_ALLOWLIST)
            );
        assert!(new_start_time == 200, 0);
        assert!(new_end_time == 1500, 0);

        // Get next mint stage
        let next_mint_stage = nft_launchpad::get_active_or_next_mint_stage(collection_obj);
        assert!(next_mint_stage == option::some(string::utf8(STAGE_NAME_ALLOWLIST)), 0);

        // Update test time
        timestamp::update_global_time_for_test_secs(1600);

        next_mint_stage = nft_launchpad::get_active_or_next_mint_stage(collection_obj);
        assert!(next_mint_stage == option::some(string::utf8(STAGE_NAME_PUBLIC)), 0);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr, user = @0x123)]
    #[expected_failure(abort_code = 21, location = nft_launchpad)]
    fun test_update_mint_times_non_admin(
        aptos_framework: &signer, admin: &signer, user: &signer
    ) {
        let (user_addr) = setup_test_env(aptos_framework, user, admin);

        let collection_obj =
            create_allowlist_then_public_collection(
                admin,
                admin, // royalty_user (using admin as royalty user)
                vector[user_addr], // allowlist_addresses
                vector[MINT_LIMIT_SMALL], // allowlist_mint_limits
                MINT_LIMIT_SMALL, // allowlist_mint_fee
                MINT_FEE_SMALL, // public_mint_fee
                MINT_FEE_LARGE, // public_mint_limit
                DURATION_XXLONG, // allowlist_duration
                DURATION_XXLONG, // public_duration
                PREMINT_AMOUNT_ZERO // premint_amount
            );

        // Try to update mint times as non-admin (should fail)
        nft_launchpad::update_mint_times(
            user,
            collection_obj,
            string::utf8(STAGE_NAME_PUBLIC),
            1500, // new start time
            2500 // new end time
        );

    }

    #[test_only]
    public fun setup_test_env(
        aptos_framework: &signer, user1: &signer, admin: &signer
    ): address {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let user1_addr = signer::address_of(user1);

        primary_fungible_store::deposit(user1_addr, mint_apt_fa_for_test(1000000000));

        timestamp::set_time_has_started_for_testing(aptos_framework);
        account::create_account_for_test(user1_addr);
        coin::register<AptosCoin>(user1);

        nft_reduction_manager::init_module_for_test(admin);
        nft_launchpad::init_module_for_test(admin);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        (user1_addr)
    }

    /// Helper to get the total mint fee (mint + protocol base + protocol percentage)
    public fun get_total_mint_fee(
        collection_obj: object::Object<collection::Collection>,
        stage_name: string::String,
        amount: u64
    ): u64 {
        let mint_fee = nft_launchpad::get_mint_fee(collection_obj, stage_name, amount);
        // Protocol fee calculation is now handled internally by get_protocol_fee
        nft_launchpad::get_protocol_fee(collection_obj, mint_fee, amount) + mint_fee
    }

    #[test(
        aptos_framework = @0x1, sender = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_public_only_mint(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, sender);

        let collection_obj =
            create_public_only_collection(
                sender,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Mint coins for the user to cover mint fees
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 2);
        mint(user1_addr, total_fee);

        // Mint 2 NFTs
        nft_launchpad::mint_nft(user1, collection_obj, 2, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 3, 0); // 5 - 2 = 3 remaining
    }

    #[test(
        aptos_framework = @0x1, sender = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_single_allowlist_mint(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let (user1_addr) = setup_test_env(aptos_framework, user1, sender);

        let collection_obj =
            create_allowlist_only_collection(
                sender,
                royalty_user,
                vector[user1_addr], // allowlist_addresses
                vector[MINT_FEE_MEDIUM], // allowlist_mint_limits
                MINT_FEE_SMALL, // mint_fee
                DURATION_SHORT // duration
            );

        // Verify user is allowlisted
        assert!(
            nft_launchpad::is_allowlisted(
                collection_obj, string::utf8(STAGE_NAME_ALLOWLIST_ONLY), user1_addr
            ),
            0
        );

        // Mint coins for the user to cover mint fees
        let total_fee =
            get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_ALLOWLIST_ONLY), 2);
        mint(user1_addr, total_fee);

        // Mint 2 NFTs
        nft_launchpad::mint_nft(user1, collection_obj, 2, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_ALLOWLIST_ONLY), user1_addr
            );
        assert!(mint_balance == 1, 0); // 3 - 2 = 1 remaining
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_protocol_base_fee_mint(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify initial protocol base fee is 0 (default)
        let initial_protocol_base_fee = nft_launchpad::get_protocol_base_fee(collection_obj);
        assert!(initial_protocol_base_fee == 0, 0);

        // Update protocol base fee to 5
        nft_launchpad::update_protocol_base_fee_for_collection(
            admin, collection_obj, PROTOCOL_BASE_FEE
        );

        // Verify updated protocol base fee
        let updated_protocol_base_fee = nft_launchpad::get_protocol_base_fee(collection_obj);
        assert!(updated_protocol_base_fee == PROTOCOL_BASE_FEE, 1);

        // Mint coins for the user to cover mint fees + protocol base fee
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        // Mint 1 NFT
        nft_launchpad::mint_nft(user1, collection_obj, 1, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 4, 2); // 5 - 1 = 4 remaining
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 4, location = nft_launchpad)]
    fun test_update_protocol_base_fee_non_admin(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to update protocol base fee as non-admin (should fail)
        nft_launchpad::update_protocol_base_fee_for_collection(
            user1, collection_obj, PROTOCOL_BASE_FEE
        );
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_protocol_base_fee_zero(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify protocol base fee is 0
        let protocol_base_fee = nft_launchpad::get_protocol_base_fee(collection_obj);
        assert!(protocol_base_fee == 0, 0);

        // Mint coins for the user to cover only mint fees (no protocol base fee)
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        // Mint 1 NFT (should work without protocol base fee)
        nft_launchpad::mint_nft(user1, collection_obj, 1, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 4, 1); // 5 - 1 = 4 remaining
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_default_protocol_base_fee(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        // Verify initial default protocol base fee is 0
        let initial_default_fee = nft_launchpad::get_default_protocol_base_fee();
        assert!(initial_default_fee == 0, 0);

        // Update default protocol base fee to 10
        nft_launchpad::update_default_protocol_base_fee(admin, PROTOCOL_BASE_FEE_LARGE);

        // Verify updated default protocol base fee
        let updated_default_fee = nft_launchpad::get_default_protocol_base_fee();
        assert!(updated_default_fee == PROTOCOL_BASE_FEE_LARGE, 1);

        // Create a new collection and verify it inherits the new default fee
        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify the new collection has the updated default protocol base fee
        let collection_protocol_fee = nft_launchpad::get_protocol_base_fee(collection_obj);
        assert!(collection_protocol_fee == PROTOCOL_BASE_FEE_LARGE, 2);
    }

    #[test(aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200)]
    #[expected_failure(abort_code = 4, location = nft_launchpad)]
    fun test_update_default_protocol_base_fee_non_admin(
        aptos_framework: &signer, admin: &signer, user1: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        // Try to update default protocol base fee as non-admin (should fail)
        nft_launchpad::update_default_protocol_base_fee(user1, PROTOCOL_BASE_FEE_LARGE);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_premint_nft_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify initial collection count (should be 0 since no pre-mint during creation)
        assert!(collection::count(collection_obj) == option::some(0), 0);

        // Premint 3 NFTs as the collection creator
        nft_launchpad::premint_nft(admin, collection_obj, PREMINT_AMOUNT_MEDIUM);

        // Verify collection count increased by 3
        assert!(collection::count(collection_obj) == option::some(PREMINT_AMOUNT_MEDIUM), 1);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 24, location = nft_launchpad)]
    fun test_premint_nft_non_creator(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to premint as non-creator (should fail)
        nft_launchpad::premint_nft(user1, collection_obj, MINT_LIMIT_SMALL);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 13, location = nft_launchpad)]
    fun test_premint_nft_zero_amount(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to premint 0 NFTs (should fail)
        nft_launchpad::premint_nft(admin, collection_obj, 0);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 12, location = nft_launchpad)]
    fun test_premint_nft_mint_disabled(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Disable minting
        nft_launchpad::update_mint_enabled(admin, collection_obj, false);

        // Try to premint when mint is disabled (should fail)
        nft_launchpad::premint_nft(admin, collection_obj, MINT_LIMIT_SMALL);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_protocol_percentage_fee_mint(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_XLARGE, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify initial protocol percentage fee is 0 (default)
        let initial_protocol_percentage_fee =
            nft_launchpad::get_protocol_percentage_fee(collection_obj);
        assert!(initial_protocol_percentage_fee == 0, 0);

        // Update protocol percentage fee to 250 (2.5%)
        nft_launchpad::update_protocol_percentage_fee_for_collection(
            admin, collection_obj, PROTOCOL_PERCENTAGE_FEE_SMALL
        );

        // Verify updated protocol percentage fee
        let updated_protocol_percentage_fee =
            nft_launchpad::get_protocol_percentage_fee(collection_obj);
        assert!(updated_protocol_percentage_fee == PROTOCOL_PERCENTAGE_FEE_SMALL, 1);

        // Mint coins for the user to cover mint fees + protocol percentage fee
        // mint_fee = 100, protocol_percentage_fee = 2.5% => 2.5 APT (rounded down to 2)
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        // Mint 1 NFT
        nft_launchpad::mint_nft(user1, collection_obj, 1, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 4, 2); // 5 - 1 = 4 remaining
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_default_protocol_percentage_fee(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        // Verify initial default protocol percentage fee is 0
        let initial_default_fee = nft_launchpad::get_default_protocol_percentage_fee();
        assert!(initial_default_fee == 0, 0);

        // Update default protocol percentage fee to 500 (5%)
        nft_launchpad::update_default_protocol_percentage_fee(
            admin, PROTOCOL_PERCENTAGE_FEE_MEDIUM
        );

        // Verify updated default protocol percentage fee
        let updated_default_fee = nft_launchpad::get_default_protocol_percentage_fee();
        assert!(updated_default_fee == PROTOCOL_PERCENTAGE_FEE_MEDIUM, 1);

        // Create a new collection and verify it inherits the new default fee
        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_XLARGE, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify the new collection has the updated default protocol percentage fee
        let collection_protocol_fee = nft_launchpad::get_protocol_percentage_fee(collection_obj);
        assert!(collection_protocol_fee == PROTOCOL_PERCENTAGE_FEE_MEDIUM, 2);

        // Mint coins for the user to cover mint fees + protocol percentage fee
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        // Mint 1 NFT
        nft_launchpad::mint_nft(user1, collection_obj, 1, vector[]);

        // Verify mint balance
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 4, 3); // 5 - 1 = 4 remaining
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_protocol_base_and_percentage_fee(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_XLARGE, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Set both base and percentage fee
        nft_launchpad::update_protocol_base_fee_for_collection(
            admin, collection_obj, PROTOCOL_BASE_FEE_LARGE
        );
        nft_launchpad::update_protocol_percentage_fee_for_collection(
            admin, collection_obj, PROTOCOL_PERCENTAGE_FEE_LARGE
        ); // 10%

        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user1_addr, total_fee);

        nft_launchpad::mint_nft(user1, collection_obj, 1, vector[]);
        let mint_balance =
            nft_launchpad::get_mint_balance(
                collection_obj, string::utf8(STAGE_NAME_PUBLIC), user1_addr
            );
        assert!(mint_balance == 4, 4);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 4, location = nft_launchpad)]
    fun test_update_protocol_percentage_fee_non_admin(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_XLARGE, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to update protocol percentage fee as non-admin (should fail)
        nft_launchpad::update_protocol_percentage_fee_for_collection(
            user1, collection_obj, PROTOCOL_PERCENTAGE_FEE_SMALL
        );
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_premint_tracking(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Initially, premint_amount should be 0
        let premint_amt = nft_launchpad::get_premint_amount(collection_obj);
        assert!(premint_amt == 0, 0);

        // Premint 2 NFTs
        nft_launchpad::premint_nft(admin, collection_obj, PREMINT_AMOUNT_SMALL);
        let premint_amt = nft_launchpad::get_premint_amount(collection_obj);
        assert!(premint_amt == PREMINT_AMOUNT_SMALL, 1);

        // Premint 3 more NFTs
        nft_launchpad::premint_nft(admin, collection_obj, PREMINT_AMOUNT_MEDIUM);
        let premint_amt = nft_launchpad::get_premint_amount(collection_obj);
        assert!(premint_amt == PREMINT_AMOUNT_LARGE, 2);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_listing_enabled_and_get_listed_collections(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        // Create first collection
        let collection_1 =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Create second collection
        let collection_2 =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_MEDIUM, // mint_fee
                MINT_LIMIT_MEDIUM, // mint_limit
                DURATION_MEDIUM // duration
            );

        // Initially, both collections should have listing disabled (default)
        assert!(!nft_launchpad::is_listing_enabled(collection_1), 0);
        assert!(!nft_launchpad::is_listing_enabled(collection_2), 1);

        // Initially, get_listed_collections should return empty vector
        let listed_collections = nft_launchpad::get_listed_collections();
        assert!(vector::length(&listed_collections) == 0, 2);

        // Enable listing for first collection
        nft_launchpad::update_listing_enabled(admin, collection_1, true);
        assert!(nft_launchpad::is_listing_enabled(collection_1), 3);
        assert!(!nft_launchpad::is_listing_enabled(collection_2), 4);

        // get_listed_collections should now return only collection_1
        let listed_collections = nft_launchpad::get_listed_collections();
        assert!(vector::length(&listed_collections) == 1, 5);
        let first_listed = listed_collections[0];
        assert!(first_listed == collection_1, 6);

        // Enable listing for second collection
        nft_launchpad::update_listing_enabled(admin, collection_2, true);
        assert!(nft_launchpad::is_listing_enabled(collection_1), 7);
        assert!(nft_launchpad::is_listing_enabled(collection_2), 8);

        // get_listed_collections should now return both collections
        let listed_collections = nft_launchpad::get_listed_collections();
        assert!(vector::length(&listed_collections) == 2, 9);

        // Disable listing for first collection
        nft_launchpad::update_listing_enabled(admin, collection_1, false);
        assert!(!nft_launchpad::is_listing_enabled(collection_1), 10);
        assert!(nft_launchpad::is_listing_enabled(collection_2), 11);

        // get_listed_collections should now return only collection_2
        let listed_collections = nft_launchpad::get_listed_collections();
        assert!(vector::length(&listed_collections) == 1, 12);
        let first_listed = listed_collections[0];
        assert!(first_listed == collection_2, 13);

        // Disable listing for second collection
        nft_launchpad::update_listing_enabled(admin, collection_2, false);
        assert!(!nft_launchpad::is_listing_enabled(collection_1), 14);
        assert!(!nft_launchpad::is_listing_enabled(collection_2), 15);

        // get_listed_collections should now return empty vector again
        let listed_collections = nft_launchpad::get_listed_collections();
        assert!(vector::length(&listed_collections) == 0, 16);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 25, location = nft_launchpad)]
    fun test_update_listing_enabled_non_creator(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to update listing enabled as non-creator (should fail)
        nft_launchpad::update_listing_enabled(user1, collection_obj, true);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_collection_mint_fee_collector(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify initial mint fee collector is the creator address
        let initial_mint_fee_collector =
            nft_launchpad::get_collection_mint_fee_collector_addr(collection_obj);
        assert!(initial_mint_fee_collector == signer::address_of(admin), 0);

        // Update mint fee collector to a different address
        let new_mint_fee_collector = @0x999;
        nft_launchpad::update_collection_mint_fee_collector(
            admin, collection_obj, new_mint_fee_collector
        );

        // Verify updated mint fee collector
        let updated_mint_fee_collector =
            nft_launchpad::get_collection_mint_fee_collector_addr(collection_obj);
        assert!(updated_mint_fee_collector == new_mint_fee_collector, 1);

        // Verify creator address remains unchanged
        let creator_addr = nft_launchpad::get_collection_creator_addr(collection_obj);
        assert!(creator_addr == signer::address_of(admin), 2);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 11, location = nft_launchpad)]
    fun test_update_collection_mint_fee_collector_non_creator(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to update mint fee collector as non-creator (should fail)
        nft_launchpad::update_collection_mint_fee_collector(user1, collection_obj, @0x999);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_max_supply_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_XLARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Update max supply to 20
        nft_launchpad::update_max_supply(admin, collection_obj, 20);

        // Mint some NFTs to verify the new max supply works
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 5);
        mint(signer::address_of(user1), total_fee);
        nft_launchpad::mint_nft(user1, collection_obj, 5, vector[]);

        // Verify we can mint up to the new max supply
        let updated_count = collection::count(collection_obj);
        assert!(updated_count == option::some(5), 1);

        // Try to mint more (should still work within new limit)
        let total_fee_2 = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 10);
        mint(signer::address_of(user1), total_fee_2);
        nft_launchpad::mint_nft(user1, collection_obj, 10, vector[]);

        let final_count = collection::count(collection_obj);
        assert!(final_count == option::some(15), 2); // 5 + 10 = 15
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 26, location = nft_launchpad)]
    fun test_update_max_supply_non_creator(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Try to update max supply as non-creator (should fail)
        nft_launchpad::update_max_supply(user1, collection_obj, 20);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 27, location = nft_launchpad)]
    fun test_update_max_supply_invalid_value(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Mint some NFTs first to test the validation
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 5);
        mint(signer::address_of(user1), total_fee);
        nft_launchpad::mint_nft(user1, collection_obj, 5, vector[]);

        // Try to set max supply to 3 when 5 NFTs are already minted (should fail)
        nft_launchpad::update_max_supply(admin, collection_obj, 3);
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    fun test_update_collection_settings(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        nft_launchpad::update_collection_settings(
            admin, collection_obj, vector[string::utf8(b"soulbound")]
        );
    }

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    #[expected_failure(abort_code = 1003, location = nft_launchpad)]
    fun test_update_invalid_collection_settings(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        nft_launchpad::update_collection_settings(
            admin, collection_obj, vector[string::utf8(b"soulboundx")]
        );
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
    #[expected_failure(abort_code = 327683, location = object)]
    fun test_transfer_soulbound_nft(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Ensure the NFT is not soulbound
        let nft1 = nft_launchpad::test_mint_nft(signer::address_of(user1), collection_obj);
        object::transfer(user1, nft1, signer::address_of(user2));

        nft_launchpad::update_collection_settings(
            admin, collection_obj, vector[string::utf8(b"soulbound")]
        );

        let nft2 = nft_launchpad::test_mint_nft(signer::address_of(user1), collection_obj);
        object::transfer(user1, nft2, signer::address_of(user2));
    }

    // ================================= Fund Management Tests ================================= //

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    fun test_fund_collection_in_object(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        account::create_account_for_test(signer::address_of(lp_wallet));

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify initial collected funds is 0
        let initial_funds = nft_launchpad::get_collected_funds(collection_obj);
        assert!(initial_funds == 0, 0);

        // Mint coins for the user to cover mint fees
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 2);
        mint(user1_addr, total_fee);

        // Mint 2 NFTs with payment tracking
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, 2, vector[]);
        let nft1 = nfts[0];

        // Verify funds are now collected
        let collected_funds = nft_launchpad::get_collected_funds(collection_obj);
        assert!(collected_funds > 0, 1);

        // Verify refund amount is stored per NFT
        let refund_amount = nft_launchpad::get_nft_refund_amount(nft1);
        assert!(refund_amount == MINT_FEE_SMALL, 2);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    fun test_sale_completion_success(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        // Create collection with max_supply of 10
        let stage_names = vector[string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::none()];
        let allowlist_mint_limit_per_addr = vector[option::none()];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + DURATION_SHORT];
        let mint_fees_per_nft = vector[MINT_FEE_SMALL];
        let mint_limits_per_addr = vector[option::some(MINT_LIMIT_XLARGE)];

        nft_launchpad::create_collection(
            admin,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(admin),
            signer::address_of(royalty_user),
            option::some(ROYALTY_PERCENTAGE),
            option::none(), // no premint
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            lp_wallet_addr,
            timestamp::now_seconds() + DURATION_MEDIUM, // deadline
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        let collection_obj = registry[vector::length(&registry) - 1];

        // Mint all NFTs to reach max_supply
        let total_fee =
            get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), MAX_SUPPLY);
        mint(user1_addr, total_fee);
        nft_launchpad::mint_nft(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Verify sale is not completed yet
        assert!(!nft_launchpad::is_sale_completed(collection_obj), 0);

        // Move time past deadline
        timestamp::update_global_time_for_test_secs(DURATION_MEDIUM + 1);

        // Complete the sale
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Verify sale is completed
        assert!(nft_launchpad::is_sale_completed(collection_obj), 1);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    #[expected_failure(abort_code = 1010, location = nft_launchpad)]
    // ESALE_THRESHOLD_NOT_MET
    fun test_sale_completion_failure_threshold_not_met(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        // Create collection with max_supply of 10
        let stage_names = vector[string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::none()];
        let allowlist_mint_limit_per_addr = vector[option::none()];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + DURATION_SHORT];
        let mint_fees_per_nft = vector[MINT_FEE_SMALL];
        let mint_limits_per_addr = vector[option::some(MINT_LIMIT_XLARGE)];

        nft_launchpad::create_collection(
            admin,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(admin),
            signer::address_of(royalty_user),
            option::some(ROYALTY_PERCENTAGE),
            option::none(), // no premint
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            lp_wallet_addr,
            timestamp::now_seconds() + DURATION_MEDIUM, // deadline
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        let collection_obj = registry[vector::length(&registry) - 1];

        // Mint only 3 NFTs (below max_supply of 10)
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 3);
        mint(user1_addr, total_fee);
        nft_launchpad::mint_nft(user1, collection_obj, 3, vector[]);

        // Move time past deadline
        timestamp::update_global_time_for_test_secs(DURATION_MEDIUM + 1);

        // Try to complete the sale (should fail because threshold not met)
        nft_launchpad::check_and_complete_sale(collection_obj);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    fun test_reclaim_after_deadline(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        // Create collection with max_supply of 10
        let stage_names = vector[string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::none()];
        let allowlist_mint_limit_per_addr = vector[option::none()];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + DURATION_SHORT];
        let mint_fees_per_nft = vector[MINT_FEE_SMALL];
        let mint_limits_per_addr = vector[option::some(MINT_LIMIT_XLARGE)];

        nft_launchpad::create_collection(
            admin,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(admin),
            signer::address_of(royalty_user),
            option::some(ROYALTY_PERCENTAGE),
            option::none(), // no premint
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            lp_wallet_addr,
            timestamp::now_seconds() + DURATION_MEDIUM, // deadline
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        let collection_obj = registry[vector::length(&registry) - 1];

        // Mint 3 NFTs (below max_supply of 10) and track them
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 3);
        mint(user1_addr, total_fee);

        // Mint NFTs (with payment for refund testing)
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, 3, vector[]);
        let nft1 = nfts[0];
        let nft2 = nfts[1];
        let nft3 = nfts[2];

        // Verify refund amount is stored per NFT
        let refund_amount = nft_launchpad::get_nft_refund_amount(nft1);
        assert!(refund_amount == MINT_FEE_SMALL, 0);

        // Move time past deadline
        timestamp::update_global_time_for_test_secs(DURATION_MEDIUM + 1);

        // User can now reclaim (sale failed because threshold not met)
        assert!(nft_launchpad::can_reclaim(collection_obj, user1_addr), 1);

        // Reclaim funds by returning NFT1
        nft_launchpad::reclaim_funds(user1, collection_obj, nft1);

        // User can still reclaim with remaining NFTs
        assert!(nft_launchpad::can_reclaim(collection_obj, user1_addr), 2);

        // Reclaim with NFT2 and NFT3
        nft_launchpad::reclaim_funds(user1, collection_obj, nft2);
        nft_launchpad::reclaim_funds(user1, collection_obj, nft3);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    #[expected_failure(abort_code = 1007, location = nft_launchpad)]
    // EDEADLINE_NOT_PASSED
    fun test_reclaim_before_deadline(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Mint 2 NFTs (with payment for refund testing)
        let total_fee = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 2);
        mint(user1_addr, total_fee);
        let nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, 2, vector[]);
        let nft1 = nfts[0];

        // Try to reclaim before deadline (should fail)
        nft_launchpad::reclaim_funds(user1, collection_obj, nft1);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            user2 = @0x201,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    fun test_multiple_users_reclaim(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        user2: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);
        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);
        coin::register<AptosCoin>(user2);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        // Create collection with max_supply of 10
        let stage_names = vector[string::utf8(STAGE_NAME_PUBLIC)];
        let stage_types = vector[STAGE_TYPE_PUBLIC];
        let allowlist_addresses = vector[option::none()];
        let allowlist_mint_limit_per_addr = vector[option::none()];
        let start_times = vector[timestamp::now_seconds()];
        let end_times = vector[timestamp::now_seconds() + DURATION_SHORT];
        let mint_fees_per_nft = vector[MINT_FEE_SMALL];
        let mint_limits_per_addr = vector[option::some(MINT_LIMIT_XLARGE)];

        nft_launchpad::create_collection(
            admin,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_URI),
            MAX_SUPPLY,
            string::utf8(PLACEHOLDER_URI),
            signer::address_of(admin),
            signer::address_of(royalty_user),
            option::some(ROYALTY_PERCENTAGE),
            option::none(), // no premint
            stage_names,
            stage_types,
            allowlist_addresses,
            allowlist_mint_limit_per_addr,
            start_times,
            end_times,
            mint_fees_per_nft,
            mint_limits_per_addr,
            vector[],
            lp_wallet_addr,
            timestamp::now_seconds() + DURATION_MEDIUM, // deadline
            FA_SYMBOL,
            FA_NAME,
            FA_ICON_URI,
            FA_PROJECT_URI,
            VESTING_CLIFF,
            VESTING_DURATION
        );

        let registry = nft_launchpad::get_registry();
        let collection_obj = registry[vector::length(&registry) - 1];

        // User1 mints 2 NFTs (with payment for refund testing)
        let total_fee_1 = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 2);
        mint(user1_addr, total_fee_1);
        let user1_nfts = nft_launchpad::mint_nft_internal(user1, collection_obj, 2, vector[]);
        let user1_nft1 = user1_nfts[0];
        let user1_nft2 = user1_nfts[1];

        // User2 mints 1 NFT (with payment for refund testing)
        let total_fee_2 = get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), 1);
        mint(user2_addr, total_fee_2);
        let user2_nfts = nft_launchpad::mint_nft_internal(user2, collection_obj, 1, vector[]);
        let user2_nft1 = user2_nfts[0];

        // Verify refund amount is stored per NFT
        let refund_amount = nft_launchpad::get_nft_refund_amount(user1_nft1);
        assert!(refund_amount == MINT_FEE_SMALL, 0);

        // Move time past deadline
        timestamp::update_global_time_for_test_secs(DURATION_MEDIUM + 1);

        // Both users can reclaim (sale failed)
        assert!(nft_launchpad::can_reclaim(collection_obj, user1_addr), 1);
        assert!(nft_launchpad::can_reclaim(collection_obj, user2_addr), 2);

        // User1 reclaims with first NFT
        nft_launchpad::reclaim_funds(user1, collection_obj, user1_nft1);
        // User1 can still reclaim with second NFT
        assert!(nft_launchpad::can_reclaim(collection_obj, user1_addr), 3);

        // User1 reclaims with second NFT
        nft_launchpad::reclaim_funds(user1, collection_obj, user1_nft2);

        // User2 reclaims
        nft_launchpad::reclaim_funds(user2, collection_obj, user2_nft1);
    }

    #[
        test(
            aptos_framework = @0x1,
            admin = @deployment_addr,
            user1 = @0x200,
            royalty_user = @0x300,
            lp_wallet = @0x400
        )
    ]
    fun test_get_sale_info(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer,
        lp_wallet: &signer
    ) {
        setup_test_env(aptos_framework, user1, admin);
        let lp_wallet_addr = signer::address_of(lp_wallet);
        account::create_account_for_test(lp_wallet_addr);

        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL, // mint_fee
                MINT_LIMIT_LARGE, // mint_limit
                DURATION_SHORT // duration
            );

        // Verify sale info
        let sale_deadline = nft_launchpad::get_sale_deadline(collection_obj);
        let lp_wallet_from_contract = nft_launchpad::get_lp_wallet_addr(collection_obj);
        let is_completed = nft_launchpad::is_sale_completed(collection_obj);

        assert!(sale_deadline == SALE_DEADLINE_OFFSET, 0);
        assert!(lp_wallet_from_contract == LP_WALLET, 1);
        assert!(!is_completed, 2);
    }

    // ================================= Fungible Asset Creation Tests ================================= //

    #[test(
        aptos_framework = @0x1, admin = @deployment_addr, user1 = @0x200, royalty_user = @0x300
    )]
    /// Test that completing a sale creates a fungible asset and distributes it correctly:
    /// - 10% goes to LP wallet
    /// - 90% stays in the contract (collection owner)
    fun test_sale_completion_creates_fungible_asset(
        aptos_framework: &signer,
        admin: &signer,
        user1: &signer,
        royalty_user: &signer
    ) {
        let user1_addr = setup_test_env(aptos_framework, user1, admin);

        // Create collection using helper (uses LP_WALLET = @0x400)
        let collection_obj =
            create_public_only_collection(
                admin,
                royalty_user,
                MINT_FEE_SMALL,
                MINT_LIMIT_XLARGE,
                DURATION_MEDIUM
            );

        // Mint all NFTs to reach max_supply
        let total_fee =
            get_total_mint_fee(collection_obj, string::utf8(STAGE_NAME_PUBLIC), MAX_SUPPLY);
        mint(user1_addr, total_fee);
        nft_launchpad::mint_nft(user1, collection_obj, MAX_SUPPLY, vector[]);

        // Verify sale is not completed yet
        assert!(!nft_launchpad::is_sale_completed(collection_obj), 0);

        // Move time past deadline (helper uses SALE_DEADLINE_OFFSET)
        timestamp::update_global_time_for_test_secs(SALE_DEADLINE_OFFSET + 1);

        // Complete the sale - this should create the fungible asset
        nft_launchpad::check_and_complete_sale(collection_obj);

        // Verify sale is completed
        assert!(nft_launchpad::is_sale_completed(collection_obj), 1);

        // Get the FA metadata object address (it's created as a named object under collection owner)
        let collection_owner_obj = nft_launchpad::get_collection_owner_obj(collection_obj);
        let collection_owner_addr = object::object_address(&collection_owner_obj);
        let fa_obj_addr = object::create_object_address(&collection_owner_addr, FA_SYMBOL);
        let fa_metadata = object::address_to_object<fungible_asset::Metadata>(fa_obj_addr);

        // Verify FA metadata
        let fa_name = fungible_asset::name(fa_metadata);
        let fa_symbol = fungible_asset::symbol(fa_metadata);
        assert!(fa_name == string::utf8(FA_NAME), 2);
        assert!(fa_symbol == string::utf8(FA_SYMBOL), 3);

        // Constants from launchpad (10% LP, 10% vesting, 80% contract)
        let total_supply: u64 = 1_000_000_000_000_000_000; // 1B * 10^9
        let lp_percentage: u64 = 10;
        let vesting_percentage: u64 = 10;
        let expected_lp_amount = total_supply * lp_percentage / 100;
        let expected_vesting_amount = total_supply * vesting_percentage / 100;
        let expected_contract_amount = total_supply - expected_lp_amount
            - expected_vesting_amount;

        // Verify LP wallet received 10% of the FA
        let lp_fa_balance = primary_fungible_store::balance(LP_WALLET, fa_metadata);
        debug::print(&lp_fa_balance);
        assert!(lp_fa_balance == expected_lp_amount, 4);

        // Verify collection owner (contract) holds 80% of the FA
        let contract_fa_balance =
            primary_fungible_store::balance(collection_owner_addr, fa_metadata);
        debug::print(&contract_fa_balance);
        assert!(contract_fa_balance == expected_contract_amount, 5);

        // Verify vesting is initialized
        assert!(vesting::is_vesting_initialized(collection_obj), 6);

        // Verify vesting pool has 10% of FA
        let vesting_balance = vesting::get_remaining_vesting_tokens(collection_obj);
        debug::print(&vesting_balance);
        assert!(vesting_balance == expected_vesting_amount, 7);
    }
}

