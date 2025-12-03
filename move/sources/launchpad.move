module deployment_addr::nft_launchpad {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{String, utf8};
    use std::vector;
    use aptos_std::debug;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::string_utils;

    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ObjectCore};
    use aptos_framework::timestamp;

    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::royalty::{Self, Royalty};
    use aptos_token_objects::token::{Self, Token};

    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset;

    use minter::token_components;
    use minter::mint_stage;
    use minter::collection_components;
    use deployment_addr::nft_reduction_manager;
    use deployment_addr::vesting;

    /// Only collection creator can update creator
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_CREATOR: u64 = 1;
    /// Only admin can set pending admin
    const EONLY_ADMIN_CAN_SET_PENDING_ADMIN: u64 = 2;
    /// Sender is not pending admin
    const ENOT_PENDING_ADMIN: u64 = 3;
    /// Only admin can update protocol fee config
    const EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG: u64 = 4;
    /// Only collection creator can update mint enabled
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_ENABLED: u64 = 11;
    /// Only collection creator can update listing enabled
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_LISTING_ENABLED: u64 = 25;
    /// No active mint stages
    const ENO_ACTIVE_STAGES: u64 = 6;
    /// Creator must set at least one mint stage
    const EAT_LEAST_ONE_STAGE_IS_REQUIRED: u64 = 7;
    /// Start time must be set for stage
    const ESTART_TIME_MUST_BE_SET_FOR_STAGE: u64 = 8;
    /// End time must be set for stage
    const EEND_TIME_MUST_BE_SET_FOR_STAGE: u64 = 9;
    /// Mint limit per address must be set for stage
    const EMINT_LIMIT_PER_ADDR_MUST_BE_SET_FOR_STAGE: u64 = 10;

    /// Mint is disabled
    const EMINT_IS_DISABLED: u64 = 12;
    /// Cannot mint 0 amount
    const ECANNOT_MINT_ZERO: u64 = 13;
    /// Allowlist and mint limit per address must be same length
    const EALLOWLIST_AND_MINT_LIMIT_PER_ADDR_MUST_BE_SAME_LENGTH: u64 = 14;
    /// Allowlist not found
    const EALLOWLIST_NOT_FOUND: u64 = 15;

    /// Invalid collection URI
    const EINVALID_COLLECTION_URI: u64 = 19;
    /// Only collection creator can update mint fee
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_FEE: u64 = 20;
    /// Only collection creator can update mint times
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_TIMES: u64 = 21;
    /// Only admin can recover funds
    const EONLY_ADMIN_CAN_RECOVER_FUNDS: u64 = 22;
    /// Only collection creator can reveal collection
    const EONLY_COLLECTION_CREATOR_CAN_REVEAL_COLLECTION: u64 = 18;
    /// Only collection creator can modify allowlist
    const EONLY_COLLECTION_CREATOR_CAN_MODIFY_ALLOWLIST: u64 = 17;
    /// Only collection creator can update max supply
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_MAX_SUPPLY: u64 = 26;
    /// Invalid max supply
    const EINVALID_MAX_SUPPLY: u64 = 27;
    /// Invalid stage type
    const EINVALID_STAGE_TYPE: u64 = 23;
    /// Invalid reveal data
    const EINVALID_REVEAL_DATA: u64 = 1001;
    /// Only collection creator can update settings
    const EONLY_COLLECTION_CREATOR_CAN_UPDATE_SETTINGS: u64 = 1002;
    /// Invalid settings
    const EINVALID_SETTINGS: u64 = 1003;
    /// Sale already completed
    const ESALE_ALREADY_COMPLETED: u64 = 1004;
    /// Sale not completed yet
    const ESALE_NOT_COMPLETED: u64 = 1005;
    /// User has no contribution to reclaim
    const ENO_CONTRIBUTION: u64 = 1006;
    /// Deadline has not passed yet
    const EDEADLINE_NOT_PASSED: u64 = 1007;
    /// Invalid threshold value
    const EINVALID_THRESHOLD: u64 = 1008;
    /// Invalid deadline value
    const EINVALID_DEADLINE: u64 = 1009;
    /// Sale threshold not met
    const ESALE_THRESHOLD_NOT_MET: u64 = 1010;

    /// 100 years in seconds, we consider mint end time to be infinite when it is set to 100 years after start time
    const ONE_HUNDRED_YEARS_IN_SECONDS: u64 = 100 * 365 * 24 * 60 * 60;

    /// Stage type for allowlist mint stage
    const STAGE_TYPE_ALLOWLIST: u8 = 1;
    /// Stage type for public mint stage
    const STAGE_TYPE_PUBLIC: u8 = 2;

    /// Soulbound setting
    const SETTING_SOULBOUND: vector<u8> = b"soulbound";

    /// Info for a mint stage
    struct MintStageInfo has copy, drop, store {
        name: String,
        mint_fee: u64,
        mint_fee_with_reduction: u64,
        start_time: u64,
        end_time: u64,
        stage_type: u8
    }

    #[event]
    struct CreateCollectionEvent has store, drop {
        creator_addr: address,
        collection_owner_obj: Object<CollectionOwnerObjConfig>,
        collection_obj: Object<Collection>,
        max_supply: u64,
        name: String,
        description: String,
        uri: String,
        stage_names: vector<String>,
        stage_types: vector<u8>,
        allowlist_addresses: vector<Option<vector<address>>>,
        allowlist_mint_limit_per_addr: vector<Option<vector<u64>>>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        mint_fees_per_nft: vector<u64>,
        mint_limits_per_addr: vector<Option<u64>>
    }

    #[event]
    struct BatchMintNftsEvent has store, drop {
        collection_obj: Object<Collection>,
        nft_objs: vector<Object<Token>>,
        recipient_addr: address,
        total_mint_fee: u64
    }

    #[event]
    struct SaleCompletedEvent has store, drop {
        collection_obj: Object<Collection>,
        total_funds: u64,
        lp_wallet_addr: address,
        minted_count: u64,
        // Fungible asset info
        fa_metadata_addr: address,
        fa_total_minted: u64,
        fa_lp_amount: u64,
        fa_vesting_amount: u64,
        fa_contract_amount: u64
    }

    #[event]
    struct FundsReclaimedEvent has store, drop {
        collection_obj: Object<Collection>,
        user_addr: address,
        nft_obj: Object<Token>,
        reclaimed_amount: u64
    }

    /// Stores the mint fee paid and burn reference for each NFT
    /// burn_ref allows the contract to burn the NFT during refund
    struct TokenMintInfo has key {
        mint_fee_paid: u64,
        burn_ref: token::BurnRef
    }

    /// Unique per collection
    /// We need this object to own the collection object instead of contract directly owns the collection object
    /// This helps us avoid address collision when we create multiple collections with same name
    struct CollectionOwnerObjConfig has key {
        collection_obj: Object<Collection>,
        extend_ref: object::ExtendRef
    }

    /// Unique per collection
    struct CollectionConfig has key {
        // creator can create collection
        creator_addr: address,
        // mint fee collector address for this collection
        mint_fee_collector_addr: address,
        // Key is stage, value is mint fee denomination
        mint_fee_per_nft_by_stages: SimpleMap<String, u64>,
        mint_enabled: bool,
        listing_enabled: bool,
        placeholder_uri: String,
        collection_owner_obj: Object<CollectionOwnerObjConfig>,
        extend_ref: object::ExtendRef,
        protocol_base_fee: u64,
        protocol_percentage_fee: u64,
        max_supply: u64,
        // Extensible collection settings stored as string array
        // This allows for future extensibility without changing the struct
        collection_settings: vector<String>,
        // LP wallet address for fund transfer after successful sale
        lp_wallet_addr: address,
        // Sale deadline timestamp
        sale_deadline: u64,
        // Whether sale has been completed
        sale_completed: bool,
        // Total funds collected in this sale
        total_funds_collected: u64,
        // Fungible asset configuration (created on successful sale)
        fa_symbol: vector<u8>,
        fa_name: vector<u8>,
        fa_icon_uri: vector<u8>,
        fa_project_uri: vector<u8>,
        // Vesting configuration
        vesting_cliff: u64, // Cliff period in seconds before claims allowed
        vesting_duration: u64 // Total vesting duration in seconds
    }

    /// Global per contract
    struct Registry has key {
        collection_objects: vector<Object<Collection>>
    }

    /// Global per contract
    struct Config has key {
        // admin can set pending admin, accept admin, update protocol fee collector, create FA and update creator
        admin_addr: address,
        pending_admin_addr: Option<address>,
        protocol_fee_collector_addr: address,
        default_protocol_base_fee: u64,
        default_protocol_percentage_fee: u64
    }

    /// If you deploy the module under an object, sender is the object's signer
    /// If you deploy the module under your own account, sender is your account's signer
    fun init_module(sender: &signer) {
        move_to(sender, Registry { collection_objects: vector::empty() });
        move_to(
            sender,
            Config {
                admin_addr: signer::address_of(sender),
                pending_admin_addr: option::none(),
                protocol_fee_collector_addr: signer::address_of(sender),
                default_protocol_base_fee: 0,
                default_protocol_percentage_fee: 0
            }
        );
    }

    #[view]
    fun get_all_settings(): vector<String> {
        vector[utf8(SETTING_SOULBOUND)]
    }

    fun validate_settings(settings: vector<String>) {
        let i = 0;
        let len = settings.length();
        let all_settings = get_all_settings();
        while (i < len) {
            let setting = settings.borrow(i);
            let contains = all_settings.contains(setting);
            assert!(contains, EINVALID_SETTINGS);
            i += 1;
        };
    }

    // ================================= Entry Functions ================================= //

    /// Update creator address for a specific collection
    public entry fun update_creator(
        sender: &signer, collection_obj: Object<Collection>, new_creator: address
    ) acquires CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        assert!(
            is_collection_creator(collection_config, sender_addr),
            EONLY_COLLECTION_CREATOR_CAN_UPDATE_CREATOR
        );
        collection_config.creator_addr = new_creator;
    }

    /// Set pending admin of the contract, then pending admin can call accept_admin to become admin
    public entry fun set_pending_admin(sender: &signer, new_admin: address) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_SET_PENDING_ADMIN);
        config.pending_admin_addr = option::some(new_admin);
    }

    /// Accept admin of the contract
    public entry fun accept_admin(sender: &signer) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@deployment_addr);
        assert!(config.pending_admin_addr == option::some(sender_addr), ENOT_PENDING_ADMIN);
        config.admin_addr = sender_addr;
        config.pending_admin_addr = option::none();
    }

    /// Update mint enabled
    public entry fun update_mint_enabled(
        sender: &signer, collection_obj: Object<Collection>, enabled: bool
    ) acquires CollectionConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_ENABLED
        );
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.mint_enabled = enabled;
    }

    /// Update listing enabled
    public entry fun update_listing_enabled(
        sender: &signer, collection_obj: Object<Collection>, enabled: bool
    ) acquires CollectionConfig {
        verify_collection_creator(
            sender,
            &collection_obj,
            EONLY_COLLECTION_CREATOR_CAN_UPDATE_LISTING_ENABLED
        );
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.listing_enabled = enabled;
    }

    /// Update max supply for a collection
    public entry fun update_max_supply(
        sender: &signer, collection_obj: Object<Collection>, new_max_supply: u64
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_UPDATE_MAX_SUPPLY
        );

        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);

        // Get current supply to ensure new max supply is not less than current supply
        let current_supply = collection::count(collection_obj);
        assert!(new_max_supply >= *current_supply.borrow(), EINVALID_MAX_SUPPLY);

        collection_config.max_supply = new_max_supply;

        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);
        collection_components::set_collection_max_supply(
            collection_owner_obj_signer, collection_obj, new_max_supply
        );
    }

    /// Update mint fee collector address for a specific collection
    public entry fun update_collection_mint_fee_collector(
        sender: &signer, collection_obj: Object<Collection>, new_mint_fee_collector: address
    ) acquires CollectionConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_ENABLED
        );
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.mint_fee_collector_addr = new_mint_fee_collector;
    }

    /// Update protocol fee collector address
    public entry fun update_protocol_fee_collector(
        sender: &signer, new_protocol_fee_collector: address
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG);
        config.protocol_fee_collector_addr = new_protocol_fee_collector;
    }

    /// Update mint fee for a specific stage
    public entry fun update_mint_fee(
        sender: &signer,
        collection_obj: Object<Collection>,
        stage_name: String,
        new_mint_fee: u64
    ) acquires CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        assert!(
            is_collection_creator(collection_config, sender_addr),
            EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_FEE
        );

        // Update the mint fee for the specified stage
        collection_config.mint_fee_per_nft_by_stages.upsert(stage_name, new_mint_fee);
    }

    /// Update protocol base fee for a specific collection (admin only)
    public entry fun update_protocol_base_fee_for_collection(
        sender: &signer, collection_obj: Object<Collection>, new_protocol_base_fee: u64
    ) acquires Config, CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG);

        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.protocol_base_fee = new_protocol_base_fee;
    }

    /// Update default protocol base fee (admin only)
    public entry fun update_default_protocol_base_fee(
        sender: &signer, new_default_protocol_base_fee: u64
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG);

        config.default_protocol_base_fee = new_default_protocol_base_fee;
    }

    /// Update protocol percentage fee for a specific collection (admin only)
    public entry fun update_protocol_percentage_fee_for_collection(
        sender: &signer, collection_obj: Object<Collection>, new_protocol_percentage_fee: u64
    ) acquires Config, CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG);
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.protocol_percentage_fee = new_protocol_percentage_fee;
    }

    /// Update default protocol percentage fee (admin only)
    public entry fun update_default_protocol_percentage_fee(
        sender: &signer, new_default_protocol_percentage_fee: u64
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_PROTOCOL_FEE_CONFIG);
        config.default_protocol_percentage_fee = new_default_protocol_percentage_fee;
    }

    /// Update collection settings after deployment (creator only)
    /// This allows updating settings like soulbound token, reveal type, etc.
    public entry fun update_collection_settings(
        sender: &signer, collection_obj: Object<Collection>, new_settings: vector<String>
    ) acquires CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);

        // Only the collection creator can update settings
        assert!(
            is_collection_creator(collection_config, sender_addr),
            EONLY_COLLECTION_CREATOR_CAN_UPDATE_SETTINGS
        );

        validate_settings(new_settings);

        collection_config.collection_settings = new_settings;
    }

    /// Create a collection, anyone can create collection
    public entry fun create_collection(
        sender: &signer,
        description: String,
        name: String,
        uri: String,
        max_supply: u64,
        placeholder_uri: String,
        mint_fee_collector_addr: address,
        royalty_address: address,
        royalty_percentage: Option<u64>,
        // Stage configurations
        stage_names: vector<String>,
        stage_types: vector<u8>,
        allowlist_addresses: vector<Option<vector<address>>>,
        allowlist_mint_limit_per_addr: vector<Option<vector<u64>>>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        mint_fees_per_nft: vector<u64>,
        mint_limits_per_addr: vector<Option<u64>>,
        // Extensible collection settings (e.g., soulbound token, reveal type, etc.)
        collection_settings: vector<String>,
        // LP wallet address for fund transfer after successful sale
        lp_wallet_addr: address,
        // Sale deadline timestamp
        sale_deadline: u64,
        // Fungible asset configuration
        fa_symbol: vector<u8>,
        fa_name: vector<u8>,
        fa_icon_uri: vector<u8>,
        fa_project_uri: vector<u8>,
        // Vesting configuration
        vesting_cliff: u64, // Cliff period in seconds before claims allowed
        vesting_duration: u64 // Total vesting duration in seconds
    ) acquires Config, Registry, CollectionConfig {
        let sender_addr = signer::address_of(sender);

        let royalty = royalty(&mut royalty_percentage, royalty_address);

        let collection_owner_obj_constructor_ref = &object::create_object(sender_addr);
        let collection_owner_obj_signer =
            &object::generate_signer(collection_owner_obj_constructor_ref);

        let collection_obj_constructor_ref =
            &collection::create_fixed_collection(
                collection_owner_obj_signer,
                description,
                max_supply,
                name,
                royalty,
                uri
            );
        let collection_obj_signer = &object::generate_signer(collection_obj_constructor_ref);
        let collection_obj_addr = signer::address_of(collection_obj_signer);
        let collection_obj = object::object_from_constructor_ref(collection_obj_constructor_ref);

        collection_components::create_refs_and_properties(collection_obj_constructor_ref);

        move_to(
            collection_owner_obj_signer,
            CollectionOwnerObjConfig {
                extend_ref: object::generate_extend_ref(collection_owner_obj_constructor_ref),
                collection_obj
            }
        );
        let collection_owner_obj =
            object::object_from_constructor_ref(collection_owner_obj_constructor_ref);
        let config = borrow_global<Config>(@deployment_addr);

        // Validate sale parameters
        assert!(max_supply > 0, EINVALID_THRESHOLD);
        assert!(sale_deadline > timestamp::now_seconds(), EINVALID_DEADLINE);

        move_to(
            collection_obj_signer,
            CollectionConfig {
                creator_addr: sender_addr,
                mint_fee_collector_addr,
                mint_fee_per_nft_by_stages: simple_map::new(),
                mint_enabled: true,
                listing_enabled: false,
                placeholder_uri,
                extend_ref: object::generate_extend_ref(collection_obj_constructor_ref),
                collection_owner_obj,
                protocol_base_fee: config.default_protocol_base_fee,
                protocol_percentage_fee: config.default_protocol_percentage_fee,
                max_supply,
                collection_settings,
                lp_wallet_addr,
                sale_deadline,
                sale_completed: false,
                total_funds_collected: 0,
                fa_symbol,
                fa_name,
                fa_icon_uri,
                fa_project_uri,
                vesting_cliff,
                vesting_duration
            }
        );

        let num_stages = stage_names.length();
        assert!(num_stages > 0, EAT_LEAST_ONE_STAGE_IS_REQUIRED);
        assert!(num_stages == stage_types.length(), EINVALID_STAGE_TYPE);
        assert!(num_stages == allowlist_addresses.length(), EINVALID_STAGE_TYPE);
        assert!(
            num_stages == allowlist_mint_limit_per_addr.length(),
            EINVALID_STAGE_TYPE
        );
        assert!(num_stages == start_times.length(), EINVALID_STAGE_TYPE);
        assert!(num_stages == end_times.length(), EINVALID_STAGE_TYPE);
        assert!(num_stages == mint_fees_per_nft.length(), EINVALID_STAGE_TYPE);
        assert!(num_stages == mint_limits_per_addr.length(), EINVALID_STAGE_TYPE);

        validate_settings(collection_settings);

        for (i in 0..num_stages) {
            let stage_name = stage_names[i];
            let stage_type = stage_types[i];
            let allowlist = allowlist_addresses[i];
            let allowlist_mint_limit = allowlist_mint_limit_per_addr[i];
            let start_time = start_times[i];
            let end_time = end_times[i];
            let mint_fee = mint_fees_per_nft[i];
            let mint_limit = mint_limits_per_addr[i];

            if (stage_type == STAGE_TYPE_ALLOWLIST) {
                assert!(allowlist.is_some(), EALLOWLIST_NOT_FOUND);
                assert!(allowlist_mint_limit.is_some(), EALLOWLIST_NOT_FOUND);
                add_mint_stage(
                    collection_obj,
                    collection_obj_addr,
                    collection_obj_signer,
                    collection_owner_obj_signer,
                    stage_name,
                    *allowlist.borrow(),
                    *allowlist_mint_limit.borrow(),
                    start_time,
                    end_time,
                    mint_fee
                );
            } else if (stage_type == STAGE_TYPE_PUBLIC) {
                assert!(
                    mint_limit.is_some(),
                    EMINT_LIMIT_PER_ADDR_MUST_BE_SET_FOR_STAGE
                );
                add_public_mint_stage(
                    collection_obj,
                    collection_obj_addr,
                    collection_obj_signer,
                    collection_owner_obj_signer,
                    stage_name,
                    start_time,
                    end_time,
                    *mint_limit.borrow(),
                    mint_fee
                );
            } else {
                abort EINVALID_STAGE_TYPE
            };
        };

        let registry = borrow_global_mut<Registry>(@deployment_addr);
        registry.collection_objects.push_back(collection_obj);

        event::emit(
            CreateCollectionEvent {
                creator_addr: sender_addr,
                collection_owner_obj,
                collection_obj,
                max_supply,
                name,
                description,
                uri,
                stage_names,
                stage_types,
                allowlist_addresses,
                allowlist_mint_limit_per_addr,
                start_times,
                end_times,
                mint_fees_per_nft,
                mint_limits_per_addr
            }
        );
    }

    /// Mint NFT, anyone with enough mint fee and has not reached mint limit can mint FA
    /// If we are in allowlist stage, only addresses in allowlist can mint FA
    /// Optional reduction_nfts can be provided to reduce the mint fee
    public entry fun mint_nft(
        sender: &signer,
        collection_obj: Object<Collection>,
        amount: u64,
        reduction_nfts: vector<Object<Token>>
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        mint_nft_internal(sender, collection_obj, amount, reduction_nfts);
    }

    /// Internal mint logic that returns the minted NFTs
    /// Can be called from other modules or tests that need the NFT objects
    public fun mint_nft_internal(
        sender: &signer,
        collection_obj: Object<Collection>,
        amount: u64,
        reduction_nfts: vector<Object<Token>>
    ): vector<Object<Token>> acquires CollectionConfig, CollectionOwnerObjConfig {
        assert!(amount > 0, ECANNOT_MINT_ZERO);
        assert!(is_mint_enabled(collection_obj), EMINT_IS_DISABLED);
        let sender_addr = signer::address_of(sender);

        let stage_idx = &mint_stage::execute_earliest_stage(sender, collection_obj, amount);
        assert!(stage_idx.is_some(), ENO_ACTIVE_STAGES);

        debug::print(stage_idx);

        let stage_obj = mint_stage::find_mint_stage_by_index(collection_obj, 0);
        let stage_name = mint_stage::mint_stage_name(stage_obj);
        let nft_mint_fee = get_mint_fee(collection_obj, stage_name, amount);

        // Calculate and pay fees with NFT-based reductions
        let total_fee = pay_for_mint(
            sender,
            nft_mint_fee,
            collection_obj,
            amount,
            reduction_nfts
        );

        // Calculate refundable fee per NFT (only NFT cost, not protocol fees)
        let refundable_per_nft = nft_mint_fee / amount;

        let nft_objs = vector[];
        for (_i in 0..amount) {
            let nft_obj = mint_single_nft_internal(sender_addr, collection_obj, refundable_per_nft);
            nft_objs.push_back(nft_obj);
        };

        event::emit(
            BatchMintNftsEvent {
                recipient_addr: sender_addr,
                total_mint_fee: total_fee,
                collection_obj,
                nft_objs
            }
        );

        nft_objs
    }

    /// Batch reveal NFTs for performance
    public entry fun reveal_nfts(
        sender: &signer,
        collection_obj: Object<Collection>,
        nft_objs: vector<Object<Token>>,
        names: vector<String>,
        descriptions: vector<String>,
        uris: vector<String>,
        prop_names_vec: vector<vector<String>>,
        prop_values_vec: vector<vector<String>>
    ) acquires CollectionOwnerObjConfig, CollectionConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_REVEAL_COLLECTION
        );

        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);
        let n = nft_objs.length();
        assert!(n == names.length(), EINVALID_REVEAL_DATA);
        assert!(n == descriptions.length(), EINVALID_REVEAL_DATA);
        assert!(n == uris.length(), EINVALID_REVEAL_DATA);
        assert!(n == prop_names_vec.length(), EINVALID_REVEAL_DATA);
        assert!(n == prop_values_vec.length(), EINVALID_REVEAL_DATA);
        for (i in 0..n) {
            let nft_obj = nft_objs[i];
            let name = names[i];
            let description = descriptions[i];
            let uri = uris[i];
            let prop_names = prop_names_vec[i];
            let prop_values = prop_values_vec[i];
            token_components::set_name(collection_owner_obj_signer, nft_obj, name);
            token_components::set_description(collection_owner_obj_signer, nft_obj, description);
            token_components::set_uri(collection_owner_obj_signer, nft_obj, uri);
            let prop_len = prop_names.length();
            assert!(prop_len == prop_values.length(), EINVALID_REVEAL_DATA);
            for (j in 0..prop_len) {
                let prop_name = prop_names[j];
                let prop_value = prop_values[j];
                if (aptos_token_objects::property_map::contains_key(&nft_obj, &prop_name)) {
                    token_components::update_typed_property(
                        collection_owner_obj_signer,
                        nft_obj,
                        prop_name,
                        prop_value
                    );
                } else {
                    token_components::add_typed_property(
                        collection_owner_obj_signer,
                        nft_obj,
                        prop_name,
                        prop_value
                    );
                }
            }
        }
    }

    // Reveal a single NFT
    public entry fun reveal_nft(
        sender: &signer,
        collection_obj: Object<Collection>,
        nft_obj: Object<Token>,
        name: String,
        description: String,
        uri: String,
        prop_names: vector<String>,
        prop_values: vector<String>
    ) acquires CollectionOwnerObjConfig, CollectionConfig {
        let nft_objs = vector[nft_obj];
        let names = vector[name];
        let descriptions = vector[description];
        let uris = vector[uri];
        let prop_names_vec = vector[prop_names];
        let prop_values_vec = vector[prop_values];
        reveal_nfts(
            sender,
            collection_obj,
            nft_objs,
            names,
            descriptions,
            uris,
            prop_names_vec,
            prop_values_vec
        );
    }

    /// Update mint times for a specific stage
    public entry fun update_mint_times(
        sender: &signer,
        collection_obj: Object<Collection>,
        stage_name: String,
        new_start_time: u64,
        new_end_time: u64
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_UPDATE_MINT_TIMES
        );

        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);

        mint_stage::update(
            collection_owner_obj_signer,
            collection_obj,
            stage_idx,
            stage_name,
            new_start_time,
            new_end_time
        );
    }

    // Total supply of fungible asset to mint (1 billion with 9 decimals)
    const FA_TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_000; // 1B * 10^9
    // Percentage to send to LP wallet (10%)
    const FA_LP_PERCENTAGE: u64 = 10;
    // Percentage reserved for NFT holder vesting (10%)
    const FA_VESTING_PERCENTAGE: u64 = 10;
    // Remaining 80% stays in contract

    /// Check and complete sale if conditions are met
    /// Conditions: deadline reached AND threshold met
    /// Anyone can call this function to trigger the completion
    public entry fun check_and_complete_sale(
        collection_obj: Object<Collection>
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);

        // Ensure sale is not already completed
        assert!(!collection_config.sale_completed, ESALE_ALREADY_COMPLETED);

        // Check if deadline has passed
        assert!(
            timestamp::now_seconds() >= collection_config.sale_deadline,
            EDEADLINE_NOT_PASSED
        );

        // Check if all NFTs are sold (max_supply reached)
        let minted_count = *collection::count(collection_obj).borrow();
        assert!(minted_count >= collection_config.max_supply, ESALE_THRESHOLD_NOT_MET);

        // Mark sale as completed
        collection_config.sale_completed = true;

        let total_funds = collection_config.total_funds_collected;
        let lp_wallet_addr = collection_config.lp_wallet_addr;

        // Get FA config from collection
        let fa_symbol = collection_config.fa_symbol;
        let fa_name = collection_config.fa_name;
        let fa_icon_uri = collection_config.fa_icon_uri;
        let fa_project_uri = collection_config.fa_project_uri;

        let collection_owner_obj = collection_config.collection_owner_obj;
        let collection_owner_config =
            borrow_global<CollectionOwnerObjConfig>(
                object::object_address(&collection_owner_obj)
            );
        let collection_owner_signer =
            object::generate_signer_for_extending(&collection_owner_config.extend_ref);

        // Create the fungible asset with max supply set to total supply (no more can ever be minted)
        let constructor_ref = &object::create_named_object(&collection_owner_signer, fa_symbol);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(FA_TOTAL_SUPPLY as u128), // Hard cap - no more tokens can ever be minted
            utf8(fa_name),
            utf8(fa_symbol),
            9, // decimals
            utf8(fa_icon_uri),
            utf8(fa_project_uri)
        );

        // Create mint ref to mint the tokens
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let fa_metadata =
            object::object_from_constructor_ref<fungible_asset::Metadata>(constructor_ref);

        // Mint the total supply
        let minted_fa = fungible_asset::mint(&mint_ref, FA_TOTAL_SUPPLY);

        // Calculate distribution: 10% LP, 10% vesting, 80% contract
        let lp_amount = FA_TOTAL_SUPPLY * FA_LP_PERCENTAGE / 100;
        let vesting_amount = FA_TOTAL_SUPPLY * FA_VESTING_PERCENTAGE / 100;
        let contract_amount = FA_TOTAL_SUPPLY - lp_amount - vesting_amount;

        // Extract LP portion and deposit to LP wallet
        let lp_fa = fungible_asset::extract(&mut minted_fa, lp_amount);
        primary_fungible_store::deposit(lp_wallet_addr, lp_fa);

        // Extract vesting portion and store in VestingPool
        let vesting_fa = fungible_asset::extract(&mut minted_fa, vesting_amount);

        // Get vesting config from collection
        let vesting_cliff = collection_config.vesting_cliff;
        let vesting_duration = collection_config.vesting_duration;
        let max_supply = collection_config.max_supply;

        // Initialize vesting in the vesting module (pass FA tokens directly)
        let collection_signer =
            object::generate_signer_for_extending(&collection_config.extend_ref);
        vesting::init_vesting(
            &collection_signer,
            collection_obj,
            fa_metadata,
            vesting_fa, // Pass FA tokens directly to vesting module
            max_supply,
            vesting_cliff,
            vesting_duration
        );

        // Store the rest in the collection owner (contract holds 80%)
        let collection_owner_addr = object::object_address(&collection_owner_obj);
        primary_fungible_store::deposit(collection_owner_addr, minted_fa);

        // Transfer APT funds to LP wallet
        if (total_funds > 0) {
            aptos_account::transfer(&collection_owner_signer, lp_wallet_addr, total_funds);
        };

        // Emit sale completed event
        event::emit(
            SaleCompletedEvent {
                collection_obj,
                total_funds,
                lp_wallet_addr,
                minted_count,
                fa_metadata_addr: object::object_address(&fa_metadata),
                fa_total_minted: FA_TOTAL_SUPPLY,
                fa_lp_amount: lp_amount,
                fa_vesting_amount: vesting_amount,
                fa_contract_amount: contract_amount
            }
        );
    }

    /// Reclaim funds if sale deadline passed without meeting threshold
    /// Users can only reclaim if:
    /// 1. Sale deadline has passed
    /// 2. Sale threshold was NOT met
    /// 3. User has contributions to reclaim
    /// Reclaim funds by returning an NFT from a failed sale
    /// The NFT serves as proof of purchase - user burns the NFT to get refund
    public entry fun reclaim_funds(
        sender: &signer, collection_obj: Object<Collection>, nft_obj: Object<Token>
    ) acquires CollectionConfig, CollectionOwnerObjConfig, TokenMintInfo {
        let sender_addr = signer::address_of(sender);
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);

        // Ensure sale is not completed (threshold was met)
        assert!(!collection_config.sale_completed, ESALE_ALREADY_COMPLETED);

        // Check if deadline has passed
        assert!(
            timestamp::now_seconds() >= collection_config.sale_deadline,
            EDEADLINE_NOT_PASSED
        );

        // Check that max_supply was NOT reached (otherwise sale should be completed, not refunded)
        let minted_count = *collection::count(collection_obj).borrow();
        assert!(minted_count < collection_config.max_supply, ESALE_NOT_COMPLETED);

        // Verify the NFT belongs to this collection
        let nft_collection = token::collection_object(nft_obj);
        assert!(nft_collection == collection_obj, ENO_CONTRIBUTION);

        // Verify the sender owns the NFT
        assert!(object::is_owner(nft_obj, sender_addr), ENO_CONTRIBUTION);

        // Extract the TokenMintInfo to get refund amount and burn_ref
        let nft_addr = object::object_address(&nft_obj);
        let TokenMintInfo { mint_fee_paid: refund_amount, burn_ref } =
            move_from<TokenMintInfo>(nft_addr);

        // Only process refund if there's an amount to refund
        if (refund_amount > 0) {
            // Update total funds collected
            collection_config.total_funds_collected -= refund_amount;

            // Transfer funds back to user from collection owner
            let collection_owner_obj = collection_config.collection_owner_obj;
            let collection_owner_config =
                borrow_global<CollectionOwnerObjConfig>(
                    object::object_address(&collection_owner_obj)
                );
            let collection_owner_signer =
                object::generate_signer_for_extending(&collection_owner_config.extend_ref);

            aptos_account::transfer(&collection_owner_signer, sender_addr, refund_amount);
        };

        // Burn the NFT using the stored burn_ref
        token::burn(burn_ref);

        // Emit funds reclaimed event
        event::emit(
            FundsReclaimedEvent {
                collection_obj,
                user_addr: sender_addr,
                nft_obj,
                reclaimed_amount: refund_amount
            }
        );
    }

    // ================================= View  ================================= //

    #[view]
    /// Get creator for a specific collection
    public fun get_creator(collection_obj: Object<Collection>): address acquires CollectionConfig {
        let collection_obj_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_obj_addr);
        collection_config.creator_addr
    }

    #[view]
    /// Get contract admin
    public fun get_admin(): address acquires Config {
        let config = borrow_global<Config>(@deployment_addr);
        config.admin_addr
    }

    #[view]
    /// Get contract pending admin
    public fun get_pending_admin(): Option<address> acquires Config {
        let config = borrow_global<Config>(@deployment_addr);
        config.pending_admin_addr
    }

    #[view]
    /// Get protocol fee collector address
    public fun get_protocol_fee_collector(): address acquires Config {
        let config = borrow_global<Config>(@deployment_addr);
        config.protocol_fee_collector_addr
    }

    #[view]
    /// Get collection creator address
    public fun get_collection_creator_addr(
        collection_obj: Object<Collection>
    ): address acquires CollectionConfig {
        let collection_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_addr);
        collection_config.creator_addr
    }

    #[view]
    /// Get collection mint fee collector address
    public fun get_collection_mint_fee_collector_addr(
        collection_obj: Object<Collection>
    ): address acquires CollectionConfig {
        let collection_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_addr);
        collection_config.mint_fee_collector_addr
    }

    #[view]
    /// Get all collections created using this contract where mint is enabled
    public fun get_registry(): vector<Object<Collection>> acquires Registry, CollectionConfig {
        let registry = borrow_global<Registry>(@deployment_addr);
        let collections = vector[];
        for (i in 0..registry.collection_objects.length()) {
            let collection_obj = registry.collection_objects[i];
            if (is_mint_enabled(collection_obj)) {
                collections.push_back(collection_obj);
            }
        };
        collections
    }

    #[view]
    /// Get all collections created using this contract where listing is enabled
    public fun get_listed_collections(): vector<Object<Collection>> acquires Registry, CollectionConfig {
        let registry = borrow_global<Registry>(@deployment_addr);
        let collections = vector[];
        for (i in 0..registry.collection_objects.length()) {
            let collection_obj = registry.collection_objects[i];
            if (is_listing_enabled(collection_obj)) {
                collections.push_back(collection_obj);
            }
        };
        collections
    }

    #[view]
    /// Is mint enabled for the collection
    public fun is_mint_enabled(collection_obj: Object<Collection>): bool acquires CollectionConfig {
        let collection_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_addr);
        collection_config.mint_enabled
    }

    #[view]
    /// Is listing enabled for the collection
    public fun is_listing_enabled(collection_obj: Object<Collection>): bool acquires CollectionConfig {
        let collection_addr = object::object_address(&collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_addr);
        collection_config.listing_enabled
    }

    #[view]
    /// Get mint fee for a specific stage, denominated in oapt (smallest unit of APT, i.e. 1e-8 APT)
    public fun get_mint_fee(
        collection_obj: Object<Collection>, stage_name: String, amount: u64
    ): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        let fee = *collection_config.mint_fee_per_nft_by_stages.borrow(&stage_name);
        amount * fee
    }

    #[view]
    /// Get protocol base fee for a specific collection
    public fun get_protocol_base_fee(collection_obj: Object<Collection>): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.protocol_base_fee
    }

    #[view]
    /// Get default protocol base fee
    public fun get_default_protocol_base_fee(): u64 acquires Config {
        let config = borrow_global<Config>(@deployment_addr);
        config.default_protocol_base_fee
    }

    /// Get the stage type for allowlist mint stage
    public fun get_stage_type_allowlist(): u8 {
        STAGE_TYPE_ALLOWLIST
    }

    /// Get the stage type for public mint stage
    public fun get_stage_type_public(): u8 {
        STAGE_TYPE_PUBLIC
    }

    #[view]
    /// Get mint balance for the stage, i.e. how many NFT user can mint
    /// e.g. If the mint limit is 1, user has already minted 1, balance is 0
    public fun get_mint_balance(
        collection_obj: Object<Collection>, stage_name: String, user_addr: address
    ): u64 {
        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        let stage_obj = mint_stage::find_mint_stage_by_index(collection_obj, stage_idx);
        if (mint_stage::allowlist_exists(stage_obj)) {
            if (mint_stage::is_allowlisted(collection_obj, stage_idx, user_addr)) {
                mint_stage::allowlist_balance(collection_obj, stage_idx, user_addr)
            } else { 0 }
        } else {
            mint_stage::public_stage_with_limit_user_balance(collection_obj, stage_idx, user_addr)
        }
    }

    #[view]
    /// Get the name of the current active mint stage or the next mint stage if there is no active mint stage
    public fun get_active_or_next_mint_stage(collection_obj: Object<Collection>): Option<String> {
        let active_stage_idx = mint_stage::ccurent_active_stage(collection_obj);
        if (active_stage_idx.is_some()) {
            let stage_obj =
                mint_stage::find_mint_stage_by_index(collection_obj, *active_stage_idx.borrow());
            let stage_name = mint_stage::mint_stage_name(stage_obj);
            option::some(stage_name)
        } else {
            let stages = mint_stage::stages(collection_obj);
            for (i in 0..stages.length()) {
                let stage_name = stages[i];
                let stage_idx =
                    mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
                if (mint_stage::start_time(collection_obj, stage_idx) > timestamp::now_seconds()) {
                    return option::some(stage_name)
                }
            };
            option::none()
        }
    }

    #[view]
    /// Get the start and end time of a mint stage
    public fun get_mint_stage_start_and_end_time(
        collection_obj: Object<Collection>, stage_name: String
    ): (u64, u64) {
        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        let stage_obj = mint_stage::find_mint_stage_by_index(collection_obj, stage_idx);
        let start_time = mint_stage::mint_stage_start_time(stage_obj);
        let end_time = mint_stage::mint_stage_end_time(stage_obj);
        (start_time, end_time)
    }

    #[view]
    /// Get total funds collected for a collection
    public fun get_collected_funds(collection_obj: Object<Collection>): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.total_funds_collected
    }

    #[view]
    /// Get the refund amount for a specific NFT
    /// Returns the actual mint fee paid for this NFT
    public fun get_nft_refund_amount(nft_obj: Object<Token>): u64 acquires TokenMintInfo {
        let nft_addr = object::object_address(&nft_obj);
        if (exists<TokenMintInfo>(nft_addr)) {
            let token_mint_info = borrow_global<TokenMintInfo>(nft_addr);
            token_mint_info.mint_fee_paid
        } else { 0 }
    }

    #[view]
    /// Check if sale is completed for a collection
    public fun is_sale_completed(collection_obj: Object<Collection>): bool acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.sale_completed
    }

    #[view]
    /// Check if reclaim is possible for a collection
    /// Returns true if deadline passed and threshold not met
    /// Users can reclaim by providing an NFT they own from this collection
    public fun can_reclaim(
        collection_obj: Object<Collection>, _user_addr: address
    ): bool acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));

        // Cannot reclaim if sale is completed
        if (collection_config.sale_completed) {
            return false
        };

        // Cannot reclaim if deadline hasn't passed
        if (timestamp::now_seconds() < collection_config.sale_deadline) {
            return false
        };

        // Cannot reclaim if max_supply was reached
        let minted_count = *collection::count(collection_obj).borrow();
        if (minted_count >= collection_config.max_supply) {
            return false
        };

        // Reclaim is possible - user needs to provide an NFT they own from this collection
        true
    }

    #[view]
    /// Get sale deadline for a collection
    public fun get_sale_deadline(collection_obj: Object<Collection>): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.sale_deadline
    }

    #[view]
    /// Get LP wallet address for a collection
    public fun get_lp_wallet_addr(collection_obj: Object<Collection>): address acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.lp_wallet_addr
    }

    #[view]
    /// Get collection owner object for a collection
    public fun get_collection_owner_obj(
        collection_obj: Object<Collection>
    ): Object<CollectionOwnerObjConfig> acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.collection_owner_obj
    }

    // ================================= Helpers ================================= //

    /// Check if sender is admin or owner of the object when package is published to object
    fun is_admin(config: &Config, sender: address): bool {
        if (sender == config.admin_addr) { true }
        else {
            if (object::is_object(@deployment_addr)) {
                let obj = object::address_to_object<ObjectCore>(@deployment_addr);
                object::is_owner(obj, sender)
            } else { false }
        }
    }

    /// Check if sender is the creator of a specific collection
    fun is_collection_creator(
        collection_config: &CollectionConfig, sender: address
    ): bool {
        sender == collection_config.creator_addr
    }

    /// Helper function to verify creator permissions
    fun verify_collection_creator(
        sender: &signer, collection_obj: &Object<Collection>, error_code: u64
    ) acquires CollectionConfig {
        let sender_addr = signer::address_of(sender);
        let collection_obj_addr = object::object_address(collection_obj);
        let collection_config = borrow_global<CollectionConfig>(collection_obj_addr);
        assert!(is_collection_creator(collection_config, sender_addr), error_code);
    }

    /// Gets the collection owner signer from a collection object
    fun get_collection_owner_signer(
        collection_obj: &Object<Collection>
    ): signer acquires CollectionConfig, CollectionOwnerObjConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(collection_obj));
        let collection_owner_obj = collection_config.collection_owner_obj;
        let collection_owner_config =
            borrow_global<CollectionOwnerObjConfig>(
                object::object_address(&collection_owner_obj)
            );
        object::generate_signer_for_extending(&collection_owner_config.extend_ref)
    }

    /// Add mint stage
    fun add_mint_stage(
        collection_obj: Object<Collection>,
        collection_obj_addr: address,
        collection_obj_signer: &signer,
        collection_owner_obj_signer: &signer,
        stage_name: String,
        allowlist: vector<address>,
        allowlist_mint_limit_per_addr: vector<u64>,
        start_time: u64,
        end_time: u64,
        mint_fee_per_nft: u64
    ) acquires CollectionConfig {
        assert!(
            allowlist.length() == allowlist_mint_limit_per_addr.length(),
            EALLOWLIST_AND_MINT_LIMIT_PER_ADDR_MUST_BE_SAME_LENGTH
        );

        mint_stage::create(
            collection_obj_signer,
            stage_name,
            start_time,
            end_time
        );

        for (i in 0..allowlist.length()) {
            mint_stage::upsert_allowlist(
                collection_owner_obj_signer,
                collection_obj,
                mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name),
                allowlist[i],
                allowlist_mint_limit_per_addr[i]
            );
        };

        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.mint_fee_per_nft_by_stages.upsert(stage_name, mint_fee_per_nft);
    }

    /// Add public mint stage
    fun add_public_mint_stage(
        collection_obj: Object<Collection>,
        collection_obj_addr: address,
        collection_obj_signer: &signer,
        collection_owner_obj_signer: &signer,
        stage_name: String,
        start_time: u64,
        end_time: u64,
        mint_limit_per_addr: u64,
        mint_fee_per_nft: u64
    ) acquires CollectionConfig {
        mint_stage::create(
            collection_obj_signer,
            stage_name,
            start_time,
            end_time
        );

        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        mint_stage::upsert_public_stage_max_per_user(
            collection_owner_obj_signer,
            collection_obj,
            stage_idx,
            mint_limit_per_addr
        );

        let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);
        collection_config.mint_fee_per_nft_by_stages.upsert(stage_name, mint_fee_per_nft);
    }

    /// Calculate and pay fees with NFT-based reductions
    /// Funds are stored in the collection's fund store until sale completion
    /// The NFT itself serves as proof of purchase for refunds
    /// Returns total_fee for events (caller already has nft_mint_fee for refunds)
    fun pay_for_mint(
        sender: &signer,
        nft_mint_fee: u64,
        collection_obj: Object<Collection>,
        amount: u64,
        reduction_nfts: vector<Object<Token>>
    ): u64 acquires CollectionConfig {
        let sender_addr = signer::address_of(sender);

        // Calculate protocol fees separately
        let original_protocol_fee = get_protocol_fee(collection_obj, nft_mint_fee, amount);

        // Apply NFT-based reduction only to protocol fees
        let (reduced_protocol_fee, _reduction_percentage, _) =
            nft_reduction_manager::calculate_reduced_protocol_fee(
                original_protocol_fee, reduction_nfts, sender_addr
            );

        let total_fee = nft_mint_fee + reduced_protocol_fee;

        // Transfer funds to the collection's fund store (held until sale completion)
        if (total_fee > 0) {
            // Get collection config to store funds
            let collection_obj_addr = object::object_address(&collection_obj);
            let collection_config = borrow_global_mut<CollectionConfig>(collection_obj_addr);

            // Ensure sale is not already completed
            assert!(!collection_config.sale_completed, ESALE_ALREADY_COMPLETED);

            // Transfer funds to the collection owner object address (acts as escrow)
            let collection_owner_addr =
                object::object_address(&collection_config.collection_owner_obj);
            aptos_account::transfer(sender, collection_owner_addr, total_fee);

            // Update total funds collected (only NFT cost, not protocol fees)
            collection_config.total_funds_collected += nft_mint_fee;
        };

        total_fee
    }

    /// Helper to calculate the final mint price (mint_fee + base + percentage)
    public fun get_protocol_fee(
        collection_obj: Object<Collection>, mint_fee: u64, amount: u64
    ): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        let protocol_base_fee = collection_config.protocol_base_fee;
        let protocol_percentage_fee = collection_config.protocol_percentage_fee;

        let base_fee =
            if (protocol_base_fee > 0) {
                protocol_base_fee * amount
            } else { 0u64 };
        let percentage_fee =
            if (protocol_percentage_fee > 0 && mint_fee > 0) {
                (mint_fee * protocol_percentage_fee) / 10000
            } else { 0u64 };
        base_fee + percentage_fee
    }

    /// Create royalty object
    fun royalty(royalty_numerator: &mut Option<u64>, admin_addr: address): Option<Royalty> {
        if (royalty_numerator.is_some()) {
            let num = royalty_numerator.extract();
            option::some(royalty::create(num, 100, admin_addr))
        } else {
            option::none()
        }
    }

    /// Helper function to pad a number with zeros to a specified length
    fun pad_number_with_zeros(num: u64, target_length: u64): String {
        let num_str = string_utils::to_string(&num);
        let current_length = num_str.length();

        if (current_length >= target_length) {
            num_str
        } else {
            let padding_needed = target_length - current_length;
            let padded_str = &mut utf8(b"");

            // Add leading zeros
            let i = 0;
            while (i < padding_needed) {
                padded_str.append(utf8(b"0"));
                i += 1;
            };

            // Add the original number
            padded_str.append(num_str);
            *padded_str
        }
    }

    /// Actual implementation of minting a single NFT
    /// mint_fee_paid is stored with the NFT for refund calculation
    fun mint_single_nft_internal(
        sender_addr: address, collection_obj: Object<Collection>, mint_fee_paid: u64
    ): Object<Token> acquires CollectionConfig, CollectionOwnerObjConfig {
        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));

        let next_nft_id = *collection::count(collection_obj).borrow() + 1;

        let name = &mut collection::name(collection_obj);
        let max_supply = collection_config.max_supply;
        let target_length = string_utils::to_string(&max_supply).length();

        name.append(utf8(b" #"));
        name.append(pad_number_with_zeros(next_nft_id, target_length));

        let placeholder_uri = collection_config.placeholder_uri;

        let nft_obj_constructor_ref =
            &token::create(
                collection_owner_obj_signer,
                collection::name(collection_obj),
                // placeholder value, please read description from json metadata in offchain storage
                *name,
                // placeholder value, please read name from json metadata in offchain storage
                *name,
                royalty::get(collection_obj),
                placeholder_uri
            );
        token_components::create_refs(nft_obj_constructor_ref);
        let nft_obj = object::object_from_constructor_ref(nft_obj_constructor_ref);

        // Generate burn_ref so we can burn the NFT during refund
        let burn_ref = token::generate_burn_ref(nft_obj_constructor_ref);

        // Store the mint fee paid and burn_ref with the NFT for refund
        let nft_signer = object::generate_signer(nft_obj_constructor_ref);
        move_to(&nft_signer, TokenMintInfo { mint_fee_paid, burn_ref });

        object::transfer(collection_owner_obj_signer, nft_obj, sender_addr);

        if (is_soulbound(collection_obj)) {
            debug::print(&utf8(b"Freezing transfer"));
            token_components::freeze_transfer(collection_owner_obj_signer, nft_obj);
        };

        nft_obj
    }

    /// Construct NFT metadata URI
    fun construct_nft_metadata_uri(collection_uri: &String, _next_nft_id: u64): String {
        let nft_metadata_uri =
            &mut collection_uri.sub_string(
                0, collection_uri.length() - utf8(b"collection.json").length()
            );
        let nft_metadata_filename = utf8(b"placeholder.png");
        nft_metadata_uri.append(nft_metadata_filename);
        *nft_metadata_uri
    }

    // ================================= Allowlist admin functions ================================== //

    fun allowlist_exists(collection_obj: Object<Collection>, stage_name: String): bool {
        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        mint_stage::allowlist_exists_with_index(collection_obj, stage_idx)
    }

    /// Clear allowlist
    entry fun clear_allowlist(
        sender: &signer, collection_obj: Object<Collection>, stage_name: String
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_MODIFY_ALLOWLIST
        );
        assert!(allowlist_exists(collection_obj, stage_name), EALLOWLIST_NOT_FOUND);

        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);

        mint_stage::clear_allowlist(
            collection_owner_obj_signer,
            collection_obj,
            mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name)
        );
    }

    /// Adds the addresses to the allowlist, and updates the mint limit for addresses that already exist in the allowlist
    entry fun update_allowlist(
        sender: &signer,
        collection_obj: Object<Collection>,
        stage_name: String,
        allowlist_addresses: vector<address>,
        allowlist_mint_limit_per_addr: vector<u64>
    ) acquires CollectionConfig, CollectionOwnerObjConfig {
        verify_collection_creator(
            sender, &collection_obj, EONLY_COLLECTION_CREATOR_CAN_MODIFY_ALLOWLIST
        );
        assert!(allowlist_exists(collection_obj, stage_name), EALLOWLIST_NOT_FOUND);
        assert!(
            allowlist_addresses.length() == allowlist_mint_limit_per_addr.length(),
            EALLOWLIST_AND_MINT_LIMIT_PER_ADDR_MUST_BE_SAME_LENGTH
        );

        let collection_owner_obj_signer = &get_collection_owner_signer(&collection_obj);

        for (i in 0..allowlist_addresses.length()) {
            let mint_limit = allowlist_mint_limit_per_addr[i];
            if (mint_limit > 0) {
                mint_stage::upsert_allowlist(
                    collection_owner_obj_signer,
                    collection_obj,
                    mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name),
                    allowlist_addresses[i],
                    mint_limit
                );
            } else {
                mint_stage::remove_from_allowlist(
                    collection_owner_obj_signer,
                    collection_obj,
                    mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name),
                    allowlist_addresses[i]
                );
            }
        };
    }

    // ================================= Allowlist checker ================================== //

    #[view]
    /// Check if user is allowlisted for a specific stage
    public fun is_allowlisted(
        collection_obj: Object<Collection>, stage_name: String, user_addr: address
    ): bool {
        let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
        mint_stage::is_allowlisted(collection_obj, stage_idx, user_addr)
    }

    #[view]
    /// Get all mint stages info for a collection (name, mint_fee, start_time, end_time, stage_type)
    public fun get_mint_stages_info(
        sender: address, collection_obj: Object<Collection>, redction_nfts: vector<Object<Token>>
    ): vector<MintStageInfo> acquires CollectionConfig {
        let stages = mint_stage::stages(collection_obj);
        let infos = vector::empty<MintStageInfo>();

        for (i in 0..stages.length()) {
            let stage_name = stages[i];
            let stage_idx = mint_stage::find_mint_stage_index_by_name(collection_obj, stage_name);
            let stage_obj = mint_stage::find_mint_stage_by_index(collection_obj, stage_idx);
            let (start_time, end_time) =
                get_mint_stage_start_and_end_time(collection_obj, stage_name);
            let mint_fee = get_mint_fee(collection_obj, stage_name, 1);
            let protocol_fee = get_protocol_fee(collection_obj, mint_fee, 1);
            let (reduced_protocol_fee, _reduction_percentage, _) =
                nft_reduction_manager::calculate_reduced_protocol_fee(
                    protocol_fee, redction_nfts, sender
                );
            let stage_type =
                if (mint_stage::allowlist_exists(stage_obj)) {
                    STAGE_TYPE_ALLOWLIST
                } else {
                    STAGE_TYPE_PUBLIC
                };
            let info = MintStageInfo {
                name: stage_name,
                mint_fee: mint_fee + protocol_fee,
                mint_fee_with_reduction: mint_fee + reduced_protocol_fee,
                start_time,
                end_time,
                stage_type
            };
            infos.push_back(info);
        };
        infos
    }

    // ================================= Uint Tests ================================== //

    #[test_only]
    public fun init_module_for_test(sender: &signer) {
        init_module(sender);
    }

    #[test_only]
    /// Mint an NFT for testing without payment (for tests that don't need refund functionality)
    public fun test_mint_nft(
        sender_addr: address, collection_obj: Object<Collection>
    ): Object<Token> acquires CollectionConfig, CollectionOwnerObjConfig {
        // Test mint with 0 fee (not eligible for refund)
        let nft = mint_single_nft_internal(sender_addr, collection_obj, 0);
        nft
    }

    #[view]
    /// Get protocol percentage fee for a specific collection
    public fun get_protocol_percentage_fee(collection_obj: Object<Collection>): u64 acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.protocol_percentage_fee
    }

    #[view]
    /// Get default protocol percentage fee
    public fun get_default_protocol_percentage_fee(): u64 acquires Config {
        let config = borrow_global<Config>(@deployment_addr);
        config.default_protocol_percentage_fee
    }

    #[view]
    /// Get collection settings for a specific collection
    public fun get_collection_settings(
        collection_obj: Object<Collection>
    ): vector<String> acquires CollectionConfig {
        let collection_config =
            borrow_global<CollectionConfig>(object::object_address(&collection_obj));
        collection_config.collection_settings
    }

    #[view]
    /// Check if a collection is soulbound (contains "soulbound" setting)
    public fun is_soulbound(collection_obj: Object<Collection>): bool acquires CollectionConfig {
        has_setting(collection_obj, utf8(SETTING_SOULBOUND))
    }

    #[view]
    /// Check if a collection has a specific setting
    public fun has_setting(
        collection_obj: Object<Collection>, setting_name: String
    ): bool acquires CollectionConfig {
        let settings = get_collection_settings(collection_obj);
        let i = 0;
        let len = settings.length();

        while (i < len) {
            let setting = settings.borrow(i);
            if (*setting == setting_name) {
                return true
            };
            i += 1;
        };
        false
    }
}

