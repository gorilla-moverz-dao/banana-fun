module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::scripts {
    use 0x1::coin;
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::primary_fungible_store;
    use 0x1::signer;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::coin_helper;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_pool;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::position_nft_manager;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::router;
    public entry fun add_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: u64, p6: u64, p7: u64, p8: u64) {
        let (_v0,_v1) = liquidity_pool::get_tokens(p1);
        let _v2 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, _v0, p5);
        let _v3 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, _v1, p6);
        let (_v4,_v5) = router::add_liquidity(p0, p1, p2, p3, p4, _v2, _v3, p7, p8);
        primary_fungible_store::deposit(signer::address_of(p0), _v4);
        primary_fungible_store::deposit(signer::address_of(p0), _v5);
    }
    public entry fun add_liquidity_both_coins<T0, T1>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: u64, p6: u64, p7: u64, p8: u64) {
        let _v0 = coin::withdraw<T0>(p0, p5);
        let _v1 = coin::withdraw<T1>(p0, p6);
        let (_v2,_v3) = router::add_liquidity_both_coins<T0,T1>(p0, p1, p2, p3, p4, _v0, _v1, p7, p8);
        primary_fungible_store::deposit(signer::address_of(p0), _v2);
        primary_fungible_store::deposit(signer::address_of(p0), _v3);
    }
    public entry fun add_liquidity_one_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: u64, p6: u64, p7: u64, p8: u64) {
        let _v0;
        let (_v1,_v2) = liquidity_pool::get_tokens(p1);
        let _v3 = _v1;
        let _v4 = coin_helper::paired_metadata_unchecked<T0>();
        if (_v3 == _v4) _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, _v2, p6) else _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, _v3, p6);
        let _v5 = coin::withdraw<T0>(p0, p5);
        let (_v6,_v7) = router::add_liquidity_one_coin<T0>(p0, p1, p2, p3, p4, _v5, _v0, p7, p8);
        primary_fungible_store::deposit(signer::address_of(p0), _v6);
        primary_fungible_store::deposit(signer::address_of(p0), _v7);
    }
    public entry fun burn_position(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: address) {
        let _v0 = position_nft_manager::burn(p0, p1, p2);
        while (0x1::vector::length<fungible_asset::FungibleAsset>(&_v0) > 0) {
            let _v1 = 0x1::vector::pop_back<fungible_asset::FungibleAsset>(&mut _v0);
            primary_fungible_store::deposit(p3, _v1);
            continue
        };
        0x1::vector::destroy_empty<fungible_asset::FungibleAsset>(_v0);
    }
    public entry fun collect_fee(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64, p5: address) {
        let (_v0,_v1) = router::collect_fee(p0, p1, p2, p3, p4);
        primary_fungible_store::deposit(p5, _v0);
        primary_fungible_store::deposit(p5, _v1);
    }
    public entry fun collect_multi_rewards(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: vector<u64>, p3: vector<u64>, p4: vector<u64>, p5: address) {
        let _v0 = 0x1::vector::length<object::Object<liquidity_pool::LiquidityPool>>(&p1);
        assert!(0x1::vector::length<u64>(&p2) == _v0, 0);
        assert!(0x1::vector::length<u64>(&p3) == _v0, 0);
        assert!(0x1::vector::length<u64>(&p4) == _v0, 0);
        let _v1 = 0;
        let _v2 = false;
        loop {
            if (_v2) _v1 = _v1 + 1 else _v2 = true;
            if (!(_v1 < _v0)) break;
            let _v3 = *0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v1);
            let _v4 = *0x1::vector::borrow<u64>(&p2, _v1);
            let _v5 = *0x1::vector::borrow<u64>(&p3, _v1);
            let _v6 = *0x1::vector::borrow<u64>(&p4, _v1);
            let _v7 = router::collect_reward(p0, _v3, _v4, _v5, _v6);
            primary_fungible_store::deposit(p5, _v7);
            continue
        };
    }
    public entry fun collect_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64, p5: address) {
        let _v0 = router::collect_reward(p0, p1, p2, p3, p4);
        primary_fungible_store::deposit(p5, _v0);
    }
    public entry fun create_pool(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u128) {
        abort 1
    }
    public entry fun create_pool_both_coins<T0, T1>(p0: &signer, p1: u64, p2: u128) {
        abort 1
    }
    public entry fun create_pool_one_coin<T0>(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: u64, p3: u128) {
        abort 1
    }
    public entry fun create_pool_with_liquidity(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u128, p5: u32, p6: u32, p7: u64, p8: u64) {
        let _v0 = router::create_pool_internal(p0, p1, p2, p3, p4);
        let _v1 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p1, p7);
        let _v2 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p8);
        let (_v3,_v4) = router::add_liquidity(p0, _v0, 0, p5, p6, _v1, _v2, 0, 0);
        let _v5 = signer::address_of(p0);
        primary_fungible_store::deposit(_v5, _v3);
        primary_fungible_store::deposit(_v5, _v4);
    }
    public entry fun create_pool_with_liquidity_both_coins<T0, T1>(p0: &signer, p1: u64, p2: u128, p3: u32, p4: u32, p5: u64, p6: u64) {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        let _v1 = coin_helper::ensure_paired_metadata<T1>();
        let _v2 = router::create_pool_internal(p0, _v0, _v1, p1, p2);
        add_liquidity_both_coins<T0,T1>(p0, _v2, 0, p3, p4, p5, p6, 0, 0);
    }
    public entry fun create_pool_with_liquidity_one_coin<T0>(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: u64, p3: u128, p4: u32, p5: u32, p6: u64, p7: u64) {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        let _v1 = router::create_pool_internal(p0, _v0, p1, p2, p3);
        add_liquidity_one_coin<T0>(p0, _v1, 0, p4, p5, p6, p7, 0, 0);
    }
    public entry fun remove_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u128, p4: u64, p5: u64) {
        let (_v0,_v1) = router::remove_liquidity(p0, p1, p2, p3, p4, p5);
        primary_fungible_store::deposit(signer::address_of(p0), _v0);
        primary_fungible_store::deposit(signer::address_of(p0), _v1);
    }
    public entry fun swap_coin_for_exact_fa<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u128, p5: address) {
        let _v0 = coin::withdraw<T0>(p0, p2);
        let (_v1,_v2) = router::swap_coin_for_exact_fa<T0>(p0, p1, _v0, p3, p4);
        coin::deposit<T0>(signer::address_of(p0), _v1);
        primary_fungible_store::deposit(p5, _v2);
    }
    public entry fun swap_coin_for_exact_fa_multi_hops<T0>(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: u64, p3: u64, p4: address) {
        let _v0 = coin::withdraw<T0>(p0, p2);
        let (_v1,_v2) = router::swap_coin_for_exact_fa_multi_hops<T0>(p0, p1, _v0, p3);
        coin::deposit<T0>(signer::address_of(p0), _v1);
        primary_fungible_store::deposit(p4, _v2);
    }
    public entry fun swap_exact_coin_for_fa<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u128, p5: address) {
        let _v0 = coin::withdraw<T0>(p0, p2);
        let _v1 = router::swap_exact_coin_for_fa<T0>(p0, p1, _v0, p3, p4);
        primary_fungible_store::deposit(p5, _v1);
    }
    public entry fun swap_exact_coin_for_fa_multi_hops<T0>(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: u64, p3: u64, p4: address) {
        let _v0 = coin::withdraw<T0>(p0, p2);
        let _v1 = router::swap_exact_coin_for_fa_multi_hops<T0>(p0, p1, _v0, p3);
        primary_fungible_store::deposit(p4, _v1);
    }
    public entry fun swap_exact_fa_for_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u64, p5: u128, p6: address) {
        let _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p3);
        let _v1 = router::swap_exact_fa_for_fa(p0, p1, _v0, p4, p5);
        primary_fungible_store::deposit(p6, _v1);
    }
    public entry fun swap_exact_fa_for_fa_multi_hops(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u64, p5: address) {
        let _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p3);
        let _v1 = router::swap_exact_fa_for_fa_multi_hops(p0, p1, _v0, p4);
        primary_fungible_store::deposit(p5, _v1);
    }
    public entry fun swap_fa_for_exact_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u64, p5: u128, p6: address) {
        let _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p3);
        let (_v1,_v2) = router::swap_fa_for_exact_fa(p0, p1, _v0, p4, p5);
        primary_fungible_store::deposit(signer::address_of(p0), _v1);
        primary_fungible_store::deposit(p6, _v2);
    }
    public entry fun swap_fa_for_exact_fa_multi_hops(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u64, p5: address) {
        let _v0 = primary_fungible_store::withdraw<fungible_asset::Metadata>(p0, p2, p3);
        let (_v1,_v2) = router::swap_fa_for_exact_fa_multi_hops(p0, p1, _v0, p4);
        primary_fungible_store::deposit(signer::address_of(p0), _v1);
        primary_fungible_store::deposit(p5, _v2);
    }
}
