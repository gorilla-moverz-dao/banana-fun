module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::reward_manager {
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::primary_fungible_store;
    use 0x1::smart_table;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::coin_helper;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::config;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_pool;
    struct Config has key {
        whitelisted_reward_tokens: smart_table::SmartTable<object::Object<fungible_asset::Metadata>, bool>,
    }
    public entry fun add_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u64) {
        let _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p4);
        liquidity_pool::add_reward(p0, p1, p3, _v0);
    }
    public entry fun add_reward_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64) {
        let _v0 = coin_helper::withdraw_fa<T0>(p0, p3);
        liquidity_pool::add_reward(p0, p1, p2, _v0);
    }
    fun assert_whitelisted_reward_token(p0: object::Object<fungible_asset::Metadata>)
        acquires Config
    {
        assert!(smart_table::contains<object::Object<fungible_asset::Metadata>,bool>(&borrow_global<Config>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).whitelisted_reward_tokens, p0), 501);
    }
    public fun get_whitelisted_reward_tokens(): vector<object::Object<fungible_asset::Metadata>>
        acquires Config
    {
        smart_table::keys<object::Object<fungible_asset::Metadata>,bool>(&borrow_global<Config>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).whitelisted_reward_tokens)
    }
    fun init_module(p0: &signer) {
        let _v0 = Config{whitelisted_reward_tokens: smart_table::new<object::Object<fungible_asset::Metadata>,bool>()};
        move_to<Config>(p0, _v0);
    }
    public entry fun initialize_pool_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: object::Object<fungible_asset::Metadata>, p3: address)
        acquires Config
    {
        config::assert_reward_admin(p0);
        assert_whitelisted_reward_token(p2);
        liquidity_pool::initialize_reward(p0, p1, p2, p3);
    }
    public entry fun initialize_pool_reward_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: address)
        acquires Config
    {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        initialize_pool_reward(p0, p1, _v0, p2);
    }
    public entry fun remove_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: address) {
        let _v0 = liquidity_pool::remove_reward(p0, p1, p2, p3);
        primary_fungible_store::deposit(p4, _v0);
    }
    public entry fun unwhitelist_reward_token(p0: &signer, p1: object::Object<fungible_asset::Metadata>)
        acquires Config
    {
        config::assert_reward_admin(p0);
        assert_whitelisted_reward_token(p1);
        let _v0 = smart_table::remove<object::Object<fungible_asset::Metadata>,bool>(&mut borrow_global_mut<Config>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).whitelisted_reward_tokens, p1);
    }
    public entry fun unwhitelist_reward_token_by_coin<T0>(p0: &signer)
        acquires Config
    {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        unwhitelist_reward_token(p0, _v0);
    }
    public entry fun update_reward_emissions(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64) {
        liquidity_pool::update_reward_emissions(p0, p1, p2, p3);
    }
    public entry fun update_reward_manager(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: address) {
        liquidity_pool::update_reward_manager(p0, p1, p2, p3);
    }
    public entry fun whitelist_reward_token(p0: &signer, p1: object::Object<fungible_asset::Metadata>)
        acquires Config
    {
        config::assert_reward_admin(p0);
        smart_table::upsert<object::Object<fungible_asset::Metadata>,bool>(&mut borrow_global_mut<Config>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).whitelisted_reward_tokens, p1, true);
    }
    public entry fun whitelist_reward_token_by_coin<T0>(p0: &signer)
        acquires Config
    {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        whitelist_reward_token(p0, _v0);
    }
}
