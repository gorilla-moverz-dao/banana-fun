module deployment_addr::vesting {
    use std::signer;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset};
    use aptos_std::simple_map::{Self, SimpleMap};

    use aptos_token_objects::collection::Collection;
    use aptos_token_objects::token::{Self, Token};

    // ================================= Errors ================================= //

    /// Cliff period has not passed yet
    const ECLIFF_NOT_PASSED: u64 = 1;
    /// No tokens available to claim
    const ENOTHING_TO_CLAIM: u64 = 2;
    /// Sender does not own the NFT
    const ENOT_NFT_OWNER: u64 = 3;
    /// NFT does not belong to this collection
    const EINVALID_NFT_COLLECTION: u64 = 4;
    /// Vesting not initialized for this collection
    const EVESTING_NOT_INITIALIZED: u64 = 5;
    /// Vesting already initialized for this collection
    const EVESTING_ALREADY_INITIALIZED: u64 = 6;

    // ================================= Structs ================================= //

    /// Object that holds the vesting FA tokens
    struct VestingVault has key {
        extend_ref: ExtendRef
    }

    /// Per-collection vesting configuration (stored at collection address)
    struct VestingConfig has key {
        fa_metadata: Object<Metadata>,
        vault_obj: Object<VestingVault>,
        total_pool: u64,
        amount_per_nft: u64,
        cliff: u64,
        duration: u64,
        start_time: u64,
        /// Tracks claimed amount per NFT address
        claimed_amounts: SimpleMap<address, u64>
    }

    // ================================= Events ================================= //

    #[event]
    struct VestingInitializedEvent has store, drop {
        collection_obj: Object<Collection>,
        fa_metadata: Object<Metadata>,
        total_pool: u64,
        amount_per_nft: u64,
        cliff: u64,
        duration: u64,
        start_time: u64
    }

    #[event]
    struct TokensClaimedEvent has store, drop {
        collection_obj: Object<Collection>,
        nft_obj: Object<Token>,
        claimer: address,
        amount: u64,
        total_claimed: u64
    }

    // ================================= Package Functions ================================= //

    /// Initialize vesting for a collection (called by launchpad on sale completion)
    /// The FA tokens are transferred to this module's vault and held until claimed
    public(package) fun init_vesting(
        collection_signer: &signer,
        collection_obj: Object<Collection>,
        fa_metadata: Object<Metadata>,
        vesting_tokens: FungibleAsset,
        max_supply: u64,
        cliff: u64,
        duration: u64
    ) {
        let collection_addr = object::object_address(&collection_obj);
        assert!(!exists<VestingConfig>(collection_addr), EVESTING_ALREADY_INITIALIZED);

        let total_pool = fungible_asset::amount(&vesting_tokens);
        let amount_per_nft = total_pool / max_supply;
        let start_time = timestamp::now_seconds();

        // Create a vault object to hold the vesting tokens
        let vault_constructor_ref = object::create_object(collection_addr);
        let vault_signer = object::generate_signer(&vault_constructor_ref);
        let vault_extend_ref = object::generate_extend_ref(&vault_constructor_ref);

        // Store extend_ref in the vault BEFORE getting the Object<VestingVault>
        move_to(&vault_signer, VestingVault { extend_ref: vault_extend_ref });

        // Now we can get the Object<VestingVault> since the struct exists
        let vault_obj = object::object_from_constructor_ref<VestingVault>(&vault_constructor_ref);

        // Deposit vesting tokens to the vault's primary fungible store
        let vault_addr = signer::address_of(&vault_signer);
        primary_fungible_store::deposit(vault_addr, vesting_tokens);

        // Store vesting config at the collection address
        move_to(
            collection_signer,
            VestingConfig {
                fa_metadata,
                vault_obj,
                total_pool,
                amount_per_nft,
                cliff,
                duration,
                start_time,
                claimed_amounts: simple_map::new()
            }
        );

        aptos_framework::event::emit(
            VestingInitializedEvent {
                collection_obj,
                fa_metadata,
                total_pool,
                amount_per_nft,
                cliff,
                duration,
                start_time
            }
        );
    }

    // ================================= Public Entry Functions ================================= //

    /// Claim vested tokens for an NFT
    /// Sender must own the NFT to claim
    public entry fun claim(
        sender: &signer, collection_obj: Object<Collection>, nft_obj: Object<Token>
    ) acquires VestingConfig, VestingVault {
        let sender_addr = signer::address_of(sender);
        let collection_addr = object::object_address(&collection_obj);

        // Verify vesting is initialized
        assert!(exists<VestingConfig>(collection_addr), EVESTING_NOT_INITIALIZED);

        // Verify sender owns the NFT
        assert!(object::is_owner(nft_obj, sender_addr), ENOT_NFT_OWNER);

        // Verify NFT belongs to this collection
        let nft_collection = token::collection_object(nft_obj);
        assert!(nft_collection == collection_obj, EINVALID_NFT_COLLECTION);

        let vesting_config = borrow_global_mut<VestingConfig>(collection_addr);
        let current_time = timestamp::now_seconds();

        // Check cliff period
        assert!(
            current_time >= vesting_config.start_time + vesting_config.cliff,
            ECLIFF_NOT_PASSED
        );

        // Calculate vested amount
        let vested =
            calculate_vested_amount(
                vesting_config.amount_per_nft,
                vesting_config.start_time,
                vesting_config.cliff,
                vesting_config.duration,
                current_time
            );

        // Get claimed amount for this NFT
        let nft_addr = object::object_address(&nft_obj);
        let claimed_amount =
            if (vesting_config.claimed_amounts.contains_key(&nft_addr)) {
                *vesting_config.claimed_amounts.borrow(&nft_addr)
            } else { 0 };

        // Calculate claimable amount
        let claimable = vested - claimed_amount;
        assert!(claimable > 0, ENOTHING_TO_CLAIM);

        // Update claimed amount in the map
        let new_claimed = claimed_amount + claimable;
        if (vesting_config.claimed_amounts.contains_key(&nft_addr)) {
            *vesting_config.claimed_amounts.borrow_mut(&nft_addr) = new_claimed;
        } else {
            vesting_config.claimed_amounts.add(nft_addr, new_claimed);
        };

        // Get vault signer to withdraw tokens
        let vault_obj = vesting_config.vault_obj;
        let vault_addr = object::object_address(&vault_obj);
        let vault_config = borrow_global<VestingVault>(vault_addr);
        let vault_signer = object::generate_signer_for_extending(&vault_config.extend_ref);
        let fa_metadata = vesting_config.fa_metadata;

        // Withdraw from vault and deposit to claimer
        let fa_to_transfer = primary_fungible_store::withdraw(
            &vault_signer, fa_metadata, claimable
        );
        primary_fungible_store::deposit(sender_addr, fa_to_transfer);

        aptos_framework::event::emit(
            TokensClaimedEvent {
                collection_obj,
                nft_obj,
                claimer: sender_addr,
                amount: claimable,
                total_claimed: new_claimed
            }
        );
    }

    // ================================= View Functions ================================= //

    #[view]
    /// Get the total vested amount for an NFT (based on time elapsed)
    public fun get_vested_amount(
        collection_obj: Object<Collection>, _nft_obj: Object<Token>
    ): u64 acquires VestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<VestingConfig>(collection_addr)) {
            return 0
        };

        let vesting_config = borrow_global<VestingConfig>(collection_addr);
        let current_time = timestamp::now_seconds();

        calculate_vested_amount(
            vesting_config.amount_per_nft,
            vesting_config.start_time,
            vesting_config.cliff,
            vesting_config.duration,
            current_time
        )
    }

    #[view]
    /// Get the amount already claimed for an NFT
    public fun get_claimed_amount(
        collection_obj: Object<Collection>, nft_obj: Object<Token>
    ): u64 acquires VestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<VestingConfig>(collection_addr)) {
            return 0
        };

        let vesting_config = borrow_global<VestingConfig>(collection_addr);
        let nft_addr = object::object_address(&nft_obj);

        if (vesting_config.claimed_amounts.contains_key(&nft_addr)) {
            *vesting_config.claimed_amounts.borrow(&nft_addr)
        } else { 0 }
    }

    #[view]
    /// Get the claimable amount for an NFT (vested - claimed)
    public fun get_claimable_amount(
        collection_obj: Object<Collection>, nft_obj: Object<Token>
    ): u64 acquires VestingConfig {
        let vested = get_vested_amount(collection_obj, nft_obj);
        let claimed = get_claimed_amount(collection_obj, nft_obj);
        if (vested > claimed) {
            vested - claimed
        } else { 0 }
    }

    #[view]
    /// Get vesting config for a collection
    public fun get_vesting_config(
        collection_obj: Object<Collection>
    ): (u64, u64, u64, u64, u64) acquires VestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        assert!(exists<VestingConfig>(collection_addr), EVESTING_NOT_INITIALIZED);

        let config = borrow_global<VestingConfig>(collection_addr);
        (
            config.total_pool,
            config.amount_per_nft,
            config.cliff,
            config.duration,
            config.start_time
        )
    }

    #[view]
    /// Check if vesting is initialized for a collection
    public fun is_vesting_initialized(collection_obj: Object<Collection>): bool {
        let collection_addr = object::object_address(&collection_obj);
        exists<VestingConfig>(collection_addr)
    }

    #[view]
    /// Get remaining tokens in vesting pool
    public fun get_remaining_vesting_tokens(collection_obj: Object<Collection>): u64 acquires VestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<VestingConfig>(collection_addr)) {
            return 0
        };

        let config = borrow_global<VestingConfig>(collection_addr);
        let vault_addr = object::object_address(&config.vault_obj);
        primary_fungible_store::balance(vault_addr, config.fa_metadata)
    }

    // ================================= Internal Functions ================================= //

    /// Calculate vested amount based on linear vesting after cliff
    fun calculate_vested_amount(
        amount_per_nft: u64,
        start_time: u64,
        cliff: u64,
        duration: u64,
        current_time: u64
    ): u64 {
        // Before cliff: nothing vested
        if (current_time < start_time + cliff) {
            return 0
        };

        // After full duration: everything vested
        if (current_time >= start_time + duration) {
            return amount_per_nft
        };

        // Linear vesting between cliff and end
        let elapsed = current_time - start_time;
        (amount_per_nft * elapsed) / duration
    }
}

