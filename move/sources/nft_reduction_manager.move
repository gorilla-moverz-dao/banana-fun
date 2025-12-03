module deployment_addr::nft_reduction_manager {
    use std::signer;
    use std::vector;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection::Collection;
    use aptos_token_objects::token::{Self, Token};

    /// Only admin can update reduction configurations
    const EONLY_ADMIN_CAN_UPDATE_REDUCTION: u64 = 1;
    /// Invalid reduction percentage (must be between 0 and 100)
    const EINVALID_REDUCTION_PERCENTAGE: u64 = 2;
    /// Collection not found in reduction config
    const ECOLLECTION_NOT_FOUND: u64 = 3;
    /// NFT not owned by sender
    const ENFT_NOT_OWNED: u64 = 4;
    /// Duplicate collection in reduction NFTs
    const EDUPLICATE_COLLECTION: u64 = 5;

    /// Global configuration for NFT-based protocol fee reductions
    struct ProtocolFeeReductionConfig has key {
        // admin can update reduction configurations
        admin_addr: address,
        // Collection address -> reduction percentage (0-100)
        collection_reductions: SimpleMap<address, u64>,
        // Whether reduction system is enabled
        enabled: bool
    }

    #[event]
    /// Event emitted when protocol fee reduction is applied
    struct ProtocolFeeReductionAppliedEvent has store, drop {
        collection_obj: Object<Collection>,
        user_addr: address,
        original_protocol_fee: u64,
        reduced_protocol_fee: u64,
        reduction_percentage: u64,
        reduction_nfts: vector<Object<Token>>
    }

    #[event]
    /// Event emitted when protocol fee reduction configuration is updated
    struct ProtocolFeeReductionConfigUpdatedEvent has store, drop {
        collection_address: address,
        reduction_percentage: u64,
        updated_by: address
    }

    /// Initialize the protocol fee reduction manager module
    fun init_module(sender: &signer) {
        move_to(
            sender,
            ProtocolFeeReductionConfig {
                admin_addr: signer::address_of(sender),
                collection_reductions: simple_map::new(),
                enabled: true
            }
        );
    }

    /// Check if sender is admin
    fun is_admin(config: &ProtocolFeeReductionConfig, sender: address): bool {
        sender == config.admin_addr
    }

    /// Get collection address from NFT
    fun get_collection_address(nft: Object<Token>): address {
        object::object_address(&token::collection_object(nft))
    }

    /// Verify that NFT is owned by the sender
    fun verify_nft_ownership(nft: Object<Token>, sender: address): bool {
        object::owner(nft) == sender
    }

    /// Calculate the total reduction percentage from multiple NFTs
    /// Returns the sum of reduction percentages from different collections (stacks up to 100%)
    fun calculate_total_reduction(
        reduction_nfts: &vector<Object<Token>>, sender: address, config: &ProtocolFeeReductionConfig
    ): u64 {
        let total_reduction = 0u64;
        let collection_addresses = vector::empty<address>();

        let nfts_len = reduction_nfts.length();
        for (i in 0..nfts_len) {
            let nft = reduction_nfts[i];

            // Verify ownership
            assert!(verify_nft_ownership(nft, sender), ENFT_NOT_OWNED);

            let collection_addr = get_collection_address(nft);

            // Check for duplicates
            assert!(
                !collection_addresses.contains(&collection_addr),
                EDUPLICATE_COLLECTION
            );
            collection_addresses.push_back(collection_addr);

            // Get reduction percentage for this collection
            if (config.collection_reductions.contains_key(&collection_addr)) {
                let reduction = *config.collection_reductions.borrow(&collection_addr);
                total_reduction += reduction;
            };
        };

        // Cap at 100% maximum reduction
        if (total_reduction > 100) {
            total_reduction = 100
        };
        total_reduction
    }

    /// Apply reduction to a protocol fee amount
    public fun apply_protocol_fee_reduction(
        original_protocol_fee: u64, reduction_percentage: u64
    ): u64 {
        if (reduction_percentage == 0) {
            return original_protocol_fee
        };
        if (reduction_percentage >= 100) {
            return 0
        };
        original_protocol_fee - (original_protocol_fee * reduction_percentage / 100)
    }

    /// Calculate reduced protocol fee for minting (only applies to protocol fees, not NFT fees)
    public fun calculate_reduced_protocol_fee(
        original_protocol_fee: u64, reduction_nfts: vector<Object<Token>>, sender: address
    ): (u64, u64, vector<Object<Token>>) acquires ProtocolFeeReductionConfig {
        let config = borrow_global<ProtocolFeeReductionConfig>(@deployment_addr);

        if (!config.enabled || reduction_nfts.length() == 0) {
            return (original_protocol_fee, 0, reduction_nfts)
        };

        let reduction_percentage = calculate_total_reduction(&reduction_nfts, sender, config);
        let reduced_protocol_fee =
            apply_protocol_fee_reduction(original_protocol_fee, reduction_percentage);

        (reduced_protocol_fee, reduction_percentage, reduction_nfts)
    }

    // ================================= Admin Functions ================================= //

    /// Set protocol fee reduction percentage for a collection (admin only)
    public entry fun set_collection_protocol_fee_reduction(
        sender: &signer, collection_address: address, reduction_percentage: u64
    ) acquires ProtocolFeeReductionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<ProtocolFeeReductionConfig>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_REDUCTION);
        assert!(reduction_percentage <= 100, EINVALID_REDUCTION_PERCENTAGE);

        config.collection_reductions.upsert(collection_address, reduction_percentage);

        event::emit(
            ProtocolFeeReductionConfigUpdatedEvent {
                collection_address,
                reduction_percentage,
                updated_by: sender_addr
            }
        );
    }

    /// Remove protocol fee reduction for a collection (admin only)
    public entry fun remove_collection_protocol_fee_reduction(
        sender: &signer, collection_address: address
    ) acquires ProtocolFeeReductionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<ProtocolFeeReductionConfig>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_REDUCTION);
        assert!(
            config.collection_reductions.contains_key(&collection_address),
            ECOLLECTION_NOT_FOUND
        );

        config.collection_reductions.remove(&collection_address);

        event::emit(
            ProtocolFeeReductionConfigUpdatedEvent {
                collection_address,
                reduction_percentage: 0,
                updated_by: sender_addr
            }
        );
    }

    /// Enable or disable the protocol fee reduction system (admin only)
    public entry fun set_protocol_fee_reduction_enabled(
        sender: &signer, enabled: bool
    ) acquires ProtocolFeeReductionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<ProtocolFeeReductionConfig>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_REDUCTION);

        config.enabled = enabled;
    }

    /// Update admin address (admin only)
    public entry fun update_admin(sender: &signer, new_admin: address) acquires ProtocolFeeReductionConfig {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<ProtocolFeeReductionConfig>(@deployment_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_REDUCTION);

        config.admin_addr = new_admin;
    }

    // ================================= View Functions ================================= //

    #[view]
    /// Get protocol fee reduction percentage for a collection
    public fun get_collection_protocol_fee_reduction(
        collection_address: address
    ): u64 acquires ProtocolFeeReductionConfig {
        let config = borrow_global<ProtocolFeeReductionConfig>(@deployment_addr);
        if (config.collection_reductions.contains_key(&collection_address)) {
            *config.collection_reductions.borrow(&collection_address)
        } else { 0 }
    }

    #[view]
    /// Check if protocol fee reduction system is enabled
    public fun is_protocol_fee_reduction_enabled(): bool acquires ProtocolFeeReductionConfig {
        let config = borrow_global<ProtocolFeeReductionConfig>(@deployment_addr);
        config.enabled
    }

    #[view]
    /// Get admin address
    public fun get_admin(): address acquires ProtocolFeeReductionConfig {
        let config = borrow_global<ProtocolFeeReductionConfig>(@deployment_addr);
        config.admin_addr
    }

    #[view]
    /// Get all collection protocol fee reductions
    public fun get_all_collection_protocol_fee_reductions(): vector<address> acquires ProtocolFeeReductionConfig {
        let config = borrow_global<ProtocolFeeReductionConfig>(@deployment_addr);
        config.collection_reductions.keys()
    }

    // ================================= Test Functions ================================= //

    #[test_only]
    public fun init_module_for_test(sender: &signer) {
        init_module(sender);
    }

    #[test_only]
    public fun test_calculate_protocol_fee_reduction(
        original_protocol_fee: u64, reduction_percentage: u64
    ): u64 {
        apply_protocol_fee_reduction(original_protocol_fee, reduction_percentage)
    }
}

