module deployment_addr::vesting {
    use std::option::{Self, Option};
    use std::signer;
    use std::vector;
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
    /// NFT vesting not initialized for this collection
    const EVESTING_NOT_INITIALIZED: u64 = 5;
    /// NFT vesting already initialized for this collection
    const EVESTING_ALREADY_INITIALIZED: u64 = 6;
    /// Creator vesting not initialized for this collection
    const ECREATOR_VESTING_NOT_INITIALIZED: u64 = 7;
    /// Creator vesting already initialized for this collection
    const ECREATOR_VESTING_ALREADY_INITIALIZED: u64 = 8;
    /// Sender is not the vesting beneficiary
    const ENOT_BENEFICIARY: u64 = 9;

    // Vesting types
    const VESTING_TYPE_NFT_HOLDER: u8 = 1;
    const VESTING_TYPE_CREATOR: u8 = 2;

    // ================================= Structs ================================= //

    /// Vault that holds vesting tokens (shared by both vesting types)
    struct VestingVault has key {
        extend_ref: ExtendRef
    }

    /// NFT holder vesting - tokens distributed per NFT
    struct NftVestingConfig has key {
        fa_metadata: Object<Metadata>,
        vault_obj: Object<VestingVault>,
        total_pool: u64,
        amount_per_nft: u64,
        cliff: u64,
        duration: u64,
        start_time: u64,
        claimed_amounts: SimpleMap<address, u64>
    }

    /// Creator vesting - tokens for a single beneficiary
    struct CreatorVestingConfig has key {
        fa_metadata: Object<Metadata>,
        vault_obj: Object<VestingVault>,
        total_pool: u64,
        beneficiary: address,
        cliff: u64,
        duration: u64,
        start_time: u64,
        claimed_amount: u64
    }

    // ================================= Unified Events ================================= //

    #[event]
    struct VestingInitializedEvent has store, drop {
        collection_obj: Object<Collection>,
        vesting_type: u8,
        fa_metadata: Object<Metadata>,
        total_pool: u64,
        /// For NFT vesting: amount per NFT. For creator vesting: 0
        amount_per_nft: u64,
        /// For creator vesting: beneficiary address. For NFT vesting: none
        beneficiary: Option<address>,
        cliff: u64,
        duration: u64,
        start_time: u64
    }

    #[event]
    struct TokensClaimedEvent has store, drop {
        collection_obj: Object<Collection>,
        vesting_type: u8,
        claimer: address,
        /// For NFT vesting: the NFT used to claim. For creator vesting: none
        nft_obj: Option<Object<Token>>,
        amount: u64,
        total_claimed: u64
    }

    // ================================= Internal Helpers ================================= //

    /// Create a vault and deposit tokens, returns the vault object
    fun create_vault_with_tokens(
        collection_addr: address, tokens: FungibleAsset
    ): Object<VestingVault> {
        let vault_constructor_ref = object::create_object(collection_addr);
        let vault_signer = object::generate_signer(&vault_constructor_ref);
        let vault_extend_ref = object::generate_extend_ref(&vault_constructor_ref);

        move_to(&vault_signer, VestingVault { extend_ref: vault_extend_ref });

        let vault_obj = object::object_from_constructor_ref<VestingVault>(&vault_constructor_ref);
        let vault_addr = signer::address_of(&vault_signer);
        primary_fungible_store::deposit(vault_addr, tokens);

        vault_obj
    }

    /// Withdraw tokens from vault and deposit to recipient
    fun withdraw_and_transfer(
        vault_obj: Object<VestingVault>,
        fa_metadata: Object<Metadata>,
        amount: u64,
        recipient: address
    ) acquires VestingVault {
        let vault_addr = object::object_address(&vault_obj);
        let vault_config = borrow_global<VestingVault>(vault_addr);
        let vault_signer = object::generate_signer_for_extending(&vault_config.extend_ref);

        let fa = primary_fungible_store::withdraw(&vault_signer, fa_metadata, amount);
        primary_fungible_store::deposit(recipient, fa);
    }

    /// Calculate vested amount based on linear vesting after cliff
    fun calculate_vested_amount(
        total_amount: u64,
        start_time: u64,
        cliff: u64,
        duration: u64,
        current_time: u64
    ): u64 {
        if (current_time < start_time + cliff) {
            return 0
        };
        if (current_time >= start_time + duration) {
            return total_amount
        };
        let elapsed = current_time - start_time;
        (((total_amount as u128) * (elapsed as u128)) / (duration as u128) as u64)
    }

    // ================================= Package Functions ================================= //

    /// Initialize NFT holder vesting
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
        assert!(!exists<NftVestingConfig>(collection_addr), EVESTING_ALREADY_INITIALIZED);

        let total_pool = fungible_asset::amount(&vesting_tokens);
        let amount_per_nft = total_pool / max_supply;
        let start_time = timestamp::now_seconds();

        let vault_obj = create_vault_with_tokens(collection_addr, vesting_tokens);

        move_to(
            collection_signer,
            NftVestingConfig {
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
                vesting_type: VESTING_TYPE_NFT_HOLDER,
                fa_metadata,
                total_pool,
                amount_per_nft,
                beneficiary: option::none(),
                cliff,
                duration,
                start_time
            }
        );
    }

    /// Initialize creator vesting
    public(package) fun init_creator_vesting(
        collection_signer: &signer,
        collection_obj: Object<Collection>,
        fa_metadata: Object<Metadata>,
        vesting_tokens: FungibleAsset,
        beneficiary: address,
        cliff: u64,
        duration: u64
    ) {
        let collection_addr = object::object_address(&collection_obj);
        assert!(
            !exists<CreatorVestingConfig>(collection_addr),
            ECREATOR_VESTING_ALREADY_INITIALIZED
        );

        let total_pool = fungible_asset::amount(&vesting_tokens);
        let start_time = timestamp::now_seconds();

        let vault_obj = create_vault_with_tokens(collection_addr, vesting_tokens);

        move_to(
            collection_signer,
            CreatorVestingConfig {
                fa_metadata,
                vault_obj,
                total_pool,
                beneficiary,
                cliff,
                duration,
                start_time,
                claimed_amount: 0
            }
        );

        aptos_framework::event::emit(
            VestingInitializedEvent {
                collection_obj,
                vesting_type: VESTING_TYPE_CREATOR,
                fa_metadata,
                total_pool,
                amount_per_nft: 0,
                beneficiary: option::some(beneficiary),
                cliff,
                duration,
                start_time
            }
        );
    }

    // ================================= Public Entry Functions ================================= //

    /// Internal claim logic for a single NFT - returns the claimed amount
    fun claim_internal(
        sender_addr: address, collection_obj: Object<Collection>, nft_obj: Object<Token>
    ): u64 acquires NftVestingConfig, VestingVault {
        let collection_addr = object::object_address(&collection_obj);

        assert!(exists<NftVestingConfig>(collection_addr), EVESTING_NOT_INITIALIZED);
        assert!(object::is_owner(nft_obj, sender_addr), ENOT_NFT_OWNER);
        assert!(token::collection_object(nft_obj) == collection_obj, EINVALID_NFT_COLLECTION);

        let config = borrow_global_mut<NftVestingConfig>(collection_addr);
        let current_time = timestamp::now_seconds();

        assert!(
            current_time >= config.start_time + config.cliff,
            ECLIFF_NOT_PASSED
        );

        let vested =
            calculate_vested_amount(
                config.amount_per_nft,
                config.start_time,
                config.cliff,
                config.duration,
                current_time
            );

        let nft_addr = object::object_address(&nft_obj);
        let claimed =
            if (config.claimed_amounts.contains_key(&nft_addr)) {
                *config.claimed_amounts.borrow(&nft_addr)
            } else { 0 };

        let claimable = vested - claimed;
        assert!(claimable > 0, ENOTHING_TO_CLAIM);

        let new_claimed = claimed + claimable;
        if (config.claimed_amounts.contains_key(&nft_addr)) {
            *config.claimed_amounts.borrow_mut(&nft_addr) = new_claimed;
        } else {
            config.claimed_amounts.add(nft_addr, new_claimed);
        };

        withdraw_and_transfer(
            config.vault_obj,
            config.fa_metadata,
            claimable,
            sender_addr
        );

        aptos_framework::event::emit(
            TokensClaimedEvent {
                collection_obj,
                vesting_type: VESTING_TYPE_NFT_HOLDER,
                claimer: sender_addr,
                nft_obj: option::some(nft_obj),
                amount: claimable,
                total_claimed: new_claimed
            }
        );

        claimable
    }

    /// Claim vested tokens for an NFT (sender must own the NFT)
    public entry fun claim(
        sender: &signer, collection_obj: Object<Collection>, nft_obj: Object<Token>
    ) acquires NftVestingConfig, VestingVault {
        claim_internal(signer::address_of(sender), collection_obj, nft_obj);
    }

    /// Claim vested tokens for multiple NFTs at once (sender must own all NFTs)
    public entry fun claim_batch(
        sender: &signer, collection_obj: Object<Collection>, nft_objs: vector<Object<Token>>
    ) acquires NftVestingConfig, VestingVault {
        let sender_addr = signer::address_of(sender);
        let len = nft_objs.length();
        let i = 0;
        while (i < len) {
            claim_internal(sender_addr, collection_obj, nft_objs[i]);
            i += 1;
        };
    }

    /// Claim vested tokens for the creator (sender must be the beneficiary)
    public entry fun claim_creator_vesting(
        sender: &signer, collection_obj: Object<Collection>
    ) acquires CreatorVestingConfig, VestingVault {
        let sender_addr = signer::address_of(sender);
        let collection_addr = object::object_address(&collection_obj);

        assert!(exists<CreatorVestingConfig>(collection_addr), ECREATOR_VESTING_NOT_INITIALIZED);

        let config = borrow_global_mut<CreatorVestingConfig>(collection_addr);
        assert!(sender_addr == config.beneficiary, ENOT_BENEFICIARY);

        let current_time = timestamp::now_seconds();
        assert!(
            current_time >= config.start_time + config.cliff,
            ECLIFF_NOT_PASSED
        );

        let vested =
            calculate_vested_amount(
                config.total_pool,
                config.start_time,
                config.cliff,
                config.duration,
                current_time
            );

        let claimable = vested - config.claimed_amount;
        assert!(claimable > 0, ENOTHING_TO_CLAIM);

        config.claimed_amount += claimable;

        withdraw_and_transfer(
            config.vault_obj,
            config.fa_metadata,
            claimable,
            sender_addr
        );

        aptos_framework::event::emit(
            TokensClaimedEvent {
                collection_obj,
                vesting_type: VESTING_TYPE_CREATOR,
                claimer: sender_addr,
                nft_obj: option::none(),
                amount: claimable,
                total_claimed: config.claimed_amount
            }
        );
    }

    // ================================= View Functions ================================= //

    #[view]
    public fun is_vesting_initialized(collection_obj: Object<Collection>): bool {
        exists<NftVestingConfig>(object::object_address(&collection_obj))
    }

    #[view]
    public fun is_creator_vesting_initialized(collection_obj: Object<Collection>): bool {
        exists<CreatorVestingConfig>(object::object_address(&collection_obj))
    }

    #[view]
    public fun get_vested_amount(collection_obj: Object<Collection>): u64 acquires NftVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<NftVestingConfig>(collection_addr)) {
            return 0
        };
        let config = borrow_global<NftVestingConfig>(collection_addr);
        calculate_vested_amount(
            config.amount_per_nft,
            config.start_time,
            config.cliff,
            config.duration,
            timestamp::now_seconds()
        )
    }

    #[view]
    public fun get_claimed_amount(
        collection_obj: Object<Collection>, nft_obj: Object<Token>
    ): u64 acquires NftVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<NftVestingConfig>(collection_addr)) {
            return 0
        };
        let config = borrow_global<NftVestingConfig>(collection_addr);
        let nft_addr = object::object_address(&nft_obj);
        if (config.claimed_amounts.contains_key(&nft_addr)) {
            *config.claimed_amounts.borrow(&nft_addr)
        } else { 0 }
    }

    #[view]
    public fun get_claimable_amount(
        collection_obj: Object<Collection>, nft_obj: Object<Token>
    ): u64 acquires NftVestingConfig {
        let vested = get_vested_amount(collection_obj);
        let claimed = get_claimed_amount(collection_obj, nft_obj);
        if (vested > claimed) {
            vested - claimed
        } else { 0 }
    }

    #[view]
    /// Get claimable amounts for multiple NFTs at once
    /// Returns a vector of claimable amounts in the same order as the input NFTs
    public fun get_claimable_amount_batch(
        collection_obj: Object<Collection>, nft_objs: vector<Object<Token>>
    ): vector<u64> acquires NftVestingConfig {
        let results = vector::empty<u64>();
        let len = nft_objs.length();
        let i = 0;
        while (i < len) {
            let claimable = get_claimable_amount(collection_obj, nft_objs[i]);
            results.push_back(claimable);
            i += 1;
        };
        results
    }

    #[view]
    public fun get_vesting_config(
        collection_obj: Object<Collection>
    ): (u64, u64, u64, u64, u64) acquires NftVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        assert!(exists<NftVestingConfig>(collection_addr), EVESTING_NOT_INITIALIZED);
        let config = borrow_global<NftVestingConfig>(collection_addr);
        (
            config.total_pool,
            config.amount_per_nft,
            config.cliff,
            config.duration,
            config.start_time
        )
    }

    #[view]
    public fun get_remaining_vesting_tokens(collection_obj: Object<Collection>): u64 acquires NftVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<NftVestingConfig>(collection_addr)) {
            return 0
        };
        let config = borrow_global<NftVestingConfig>(collection_addr);
        primary_fungible_store::balance(
            object::object_address(&config.vault_obj), config.fa_metadata
        )
    }

    #[view]
    public fun get_creator_vested_amount(
        collection_obj: Object<Collection>
    ): u64 acquires CreatorVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<CreatorVestingConfig>(collection_addr)) {
            return 0
        };
        let config = borrow_global<CreatorVestingConfig>(collection_addr);
        calculate_vested_amount(
            config.total_pool,
            config.start_time,
            config.cliff,
            config.duration,
            timestamp::now_seconds()
        )
    }

    #[view]
    public fun get_creator_claimed_amount(
        collection_obj: Object<Collection>
    ): u64 acquires CreatorVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<CreatorVestingConfig>(collection_addr)) {
            return 0
        };
        borrow_global<CreatorVestingConfig>(collection_addr).claimed_amount
    }

    #[view]
    public fun get_creator_claimable_amount(
        collection_obj: Object<Collection>
    ): u64 acquires CreatorVestingConfig {
        let vested = get_creator_vested_amount(collection_obj);
        let claimed = get_creator_claimed_amount(collection_obj);
        if (vested > claimed) {
            vested - claimed
        } else { 0 }
    }

    #[view]
    public fun get_creator_vesting_config(
        collection_obj: Object<Collection>
    ): (u64, address, u64, u64, u64, u64) acquires CreatorVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        assert!(exists<CreatorVestingConfig>(collection_addr), ECREATOR_VESTING_NOT_INITIALIZED);
        let config = borrow_global<CreatorVestingConfig>(collection_addr);
        (
            config.total_pool,
            config.beneficiary,
            config.cliff,
            config.duration,
            config.start_time,
            config.claimed_amount
        )
    }

    #[view]
    public fun get_remaining_creator_vesting_tokens(
        collection_obj: Object<Collection>
    ): u64 acquires CreatorVestingConfig {
        let collection_addr = object::object_address(&collection_obj);
        if (!exists<CreatorVestingConfig>(collection_addr)) {
            return 0
        };
        let config = borrow_global<CreatorVestingConfig>(collection_addr);
        primary_fungible_store::balance(
            object::object_address(&config.vault_obj), config.fa_metadata
        )
    }
}

