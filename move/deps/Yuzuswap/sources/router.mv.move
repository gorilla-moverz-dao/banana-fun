module yuzuswap::router {
    use 0x1::coin;
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::option;
    use 0x1::string;
    use yuzuswap::coin_helper;
    use yuzuswap::fa_helper;
    use yuzuswap::liquidity_pool;
    use yuzuswap::position_nft_manager;
    use yuzuswap::tick_math;
    friend yuzuswap::scripts;
    public fun add_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: fungible_asset::FungibleAsset, p6: fungible_asset::FungibleAsset, p7: u64, p8: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let (_v0,_v1,_v2) = add_liquidity_with_position_id(p0, p1, p2, p3, p4, p5, p6, p7, p8);
        (_v1, _v2)
    }
    public fun add_liquidity_both_coins<T0, T1>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: coin::Coin<T0>, p6: coin::Coin<T1>, p7: u64, p8: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p5);
        let _v1 = coin::coin_to_fungible_asset<T1>(p6);
        let (_v2,_v3) = add_liquidity(p0, p1, p2, p3, p4, _v0, _v1, p7, p8);
        (_v2, _v3)
    }
    fun add_liquidity_internal(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: fungible_asset::FungibleAsset, p6: fungible_asset::FungibleAsset, p7: u64, p8: u64): (u64, fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0;
        if (p2 > 0) {
            let _v1 = &mut p5;
            let _v2 = &mut p6;
            position_nft_manager::increase_liquidity(p0, p1, p2, _v1, _v2, p7, p8);
            _v0 = p2
        } else {
            let _v3 = &mut p5;
            let _v4 = &mut p6;
            _v0 = position_nft_manager::mint(p0, p1, p3, p4, _v3, _v4, p7, p8)
        };
        (_v0, p5, p6)
    }
    public fun add_liquidity_one_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: coin::Coin<T0>, p6: fungible_asset::FungibleAsset, p7: u64, p8: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p5);
        let (_v1,_v2) = add_liquidity(p0, p1, p2, p3, p4, _v0, p6, p7, p8);
        (_v1, _v2)
    }
    public fun add_liquidity_with_position_id(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u32, p4: u32, p5: fungible_asset::FungibleAsset, p6: fungible_asset::FungibleAsset, p7: u64, p8: u64): (u64, fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0;
        let _v1;
        let _v2 = fungible_asset::asset_metadata(&p5);
        let _v3 = fungible_asset::asset_metadata(&p6);
        if (fa_helper::is_sorted(_v2, _v3)) {
            let (_v4,_v5,_v6) = add_liquidity_internal(p0, p1, p2, p3, p4, p5, p6, p7, p8);
            _v1 = _v6;
            _v0 = _v5;
            p2 = _v4
        } else {
            let (_v7,_v8,_v9) = add_liquidity_internal(p0, p1, p2, p3, p4, p6, p5, p8, p7);
            _v0 = _v9;
            _v1 = _v8;
            p2 = _v7
        };
        (p2, _v0, _v1)
    }
    public fun collect_fee(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let (_v0,_v1) = position_nft_manager::collect_fee(p0, p1, p2, p3, p4);
        (_v0, _v1)
    }
    public fun collect_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64): fungible_asset::FungibleAsset {
        position_nft_manager::collect_reward(p0, p1, p2, p3, p4)
    }
    public fun create_pool(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u128): object::Object<liquidity_pool::LiquidityPool> {
        abort 408
    }
    public fun create_pool_both_coins<T0, T1>(p0: &signer, p1: u64, p2: u128): object::Object<liquidity_pool::LiquidityPool> {
        abort 408
    }
    friend fun create_pool_internal(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u128): object::Object<liquidity_pool::LiquidityPool> {
        let _v0;
        if (fa_helper::is_sorted(p1, p2)) _v0 = liquidity_pool::create_pool(p0, p1, p2, p3, p4) else _v0 = liquidity_pool::create_pool(p0, p2, p1, p3, p4);
        let _v1 = _v0;
        let _v2 = string::utf8(vector[]);
        let _v3 = position_nft_manager::create_collection(_v1, _v2);
        _v1
    }
    public fun create_pool_one_coin<T0>(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: u64, p3: u128): object::Object<liquidity_pool::LiquidityPool> {
        abort 408
    }
    public fun get_pool(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>, p2: u64): object::Object<liquidity_pool::LiquidityPool> {
        let _v0;
        if (fa_helper::is_sorted(p0, p1)) _v0 = liquidity_pool::get_pool(p0, p1, p2) else _v0 = liquidity_pool::get_pool(p1, p0, p2);
        _v0
    }
    public fun get_pool_both_coins<T0, T1>(p0: u64): object::Object<liquidity_pool::LiquidityPool> {
        let _v0 = coin_helper::paired_metadata_unchecked<T0>();
        let _v1 = coin_helper::paired_metadata_unchecked<T1>();
        get_pool(_v0, _v1, p0)
    }
    public fun get_pool_one_coin<T0>(p0: object::Object<fungible_asset::Metadata>, p1: u64): object::Object<liquidity_pool::LiquidityPool> {
        get_pool(coin_helper::paired_metadata_unchecked<T0>(), p0, p1)
    }
    fun internal_swap_partial_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: bool, p4: u64, p5: u64, p6: u128): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let (_v0,_v1) = liquidity_pool::get_tokens(p1);
        let _v2 = fungible_asset::asset_metadata(&p2);
        let (_v3,_v4) = liquidity_pool::swap(p0, p1, _v2 == _v0, p3, p4, p6);
        let _v5 = _v4;
        let _v6 = _v3;
        loop {
            if (p3) {
                if (fungible_asset::amount(&_v6) >= p5) break;
                abort 403
            };
            if (fungible_asset::amount(&_v6) == p4) break;
            abort 402
        };
        let _v7 = liquidity_pool::get_swap_receipt_amount(&_v5);
        assert!(fungible_asset::amount(&p2) >= _v7, 404);
        liquidity_pool::pay_swap(fungible_asset::extract(&mut p2, _v7), _v5);
        (p2, _v6)
    }
    public fun is_pool_both_coins_exists<T0, T1>(p0: u64): bool {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        let _v1 = coin_helper::ensure_paired_metadata<T1>();
        is_pool_exists(_v0, _v1, p0)
    }
    public fun is_pool_exists(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>, p2: u64): bool {
        let _v0;
        if (fa_helper::is_sorted(p0, p1)) _v0 = liquidity_pool::is_pool_exists(p0, p1, p2) else _v0 = liquidity_pool::is_pool_exists(p1, p0, p2);
        _v0
    }
    public fun is_pool_one_coin_exists<T0>(p0: object::Object<fungible_asset::Metadata>, p1: u64): bool {
        is_pool_exists(coin_helper::ensure_paired_metadata<T0>(), p0, p1)
    }
    public fun is_sorted_both_coins<T0, T1>(): bool {
        let _v0 = coin_helper::ensure_paired_metadata<T0>();
        let _v1 = coin_helper::ensure_paired_metadata<T1>();
        fa_helper::is_sorted(_v0, _v1)
    }
    public fun is_sorted_one_coin<T0>(p0: object::Object<fungible_asset::Metadata>): bool {
        fa_helper::is_sorted(coin_helper::ensure_paired_metadata<T0>(), p0)
    }
    public fun is_sorted_tokens(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>): bool {
        fa_helper::is_sorted(p0, p1)
    }
    public fun quote_swap_exact_in_multi_hops(p0: address, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: object::Object<fungible_asset::Metadata>, p3: u64): u64 {
        let _v0 = 0x1::vector::length<object::Object<liquidity_pool::LiquidityPool>>(&p1);
        assert!(_v0 > 0, 406);
        let _v1 = p2;
        let _v2 = p3;
        let _v3 = 0;
        let _v4 = false;
        loop {
            let _v5;
            if (_v4) _v3 = _v3 + 1 else _v4 = true;
            if (!(_v3 < _v0)) break;
            let _v6 = *0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v3);
            let (_v7,_v8) = liquidity_pool::get_tokens(_v6);
            let _v9 = _v7;
            let _v10 = _v1 == _v9;
            if (_v10) _v5 = tick_math::min_sqrt_price() else _v5 = tick_math::max_sqrt_price();
            let (_v11,_v12,_v13) = liquidity_pool::quote_swap(p0, _v6, _v10, true, _v2, _v5);
            if (_v10) _v1 = _v8 else _v1 = _v9;
            _v2 = _v12;
            continue
        };
        _v2
    }
    public fun quote_swap_exact_out_multi_hops(p0: address, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: object::Object<fungible_asset::Metadata>, p3: u64): u64 {
        let _v0 = 0x1::vector::length<object::Object<liquidity_pool::LiquidityPool>>(&p1);
        assert!(_v0 > 0, 406);
        let _v1 = p2;
        let _v2 = p3;
        let _v3 = _v0;
        loop {
            let _v4;
            if (!(_v3 > 0)) break;
            _v3 = _v3 - 1;
            let _v5 = *0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v3);
            let (_v6,_v7) = liquidity_pool::get_tokens(_v5);
            let _v8 = _v7;
            let _v9 = _v1 == _v8;
            if (_v9) _v4 = tick_math::min_sqrt_price() else _v4 = tick_math::max_sqrt_price();
            let (_v10,_v11,_v12) = liquidity_pool::quote_swap(p0, _v5, _v9, false, _v2, _v4);
            if (_v9) _v1 = _v6 else _v1 = _v8;
            _v2 = _v10;
            continue
        };
        _v2
    }
    public fun remove_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u128, p4: u64, p5: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let (_v0,_v1) = position_nft_manager::decrease_liquidity(p0, p1, p2, p3, p4, p5);
        (_v0, _v1)
    }
    public fun swap_coin_for_exact_coin<T0, T1>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): (coin::Coin<T0>, coin::Coin<T1>) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        let (_v1,_v2) = swap_fa_for_exact_fa(p0, p1, _v0, p3, p4);
        let _v3 = coin_helper::fungible_asset_to_coin<T0>(_v1);
        let _v4 = coin_helper::fungible_asset_to_coin<T1>(_v2);
        (_v3, _v4)
    }
    public fun swap_coin_for_exact_fa<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): (coin::Coin<T0>, fungible_asset::FungibleAsset) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        let (_v1,_v2) = swap_fa_for_exact_fa(p0, p1, _v0, p3, p4);
        (coin_helper::fungible_asset_to_coin<T0>(_v1), _v2)
    }
    public fun swap_coin_for_exact_fa_multi_hops<T0>(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: coin::Coin<T0>, p3: u64): (coin::Coin<T0>, fungible_asset::FungibleAsset) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        let (_v1,_v2) = swap_fa_for_exact_fa_multi_hops(p0, p1, _v0, p3);
        (coin_helper::fungible_asset_to_coin<T0>(_v1), _v2)
    }
    public fun swap_exact_coin_for_coin<T0, T1>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): coin::Coin<T1> {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        coin_helper::fungible_asset_to_coin<T1>(swap_exact_fa_for_fa(p0, p1, _v0, p3, p4))
    }
    public fun swap_exact_coin_for_fa<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): fungible_asset::FungibleAsset {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        swap_exact_fa_for_fa(p0, p1, _v0, p3, p4)
    }
    public fun swap_exact_coin_for_fa_multi_hops<T0>(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: coin::Coin<T0>, p3: u64): fungible_asset::FungibleAsset {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        swap_exact_fa_for_fa_multi_hops(p0, p1, _v0, p3)
    }
    public fun swap_exact_fa_for_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): coin::Coin<T0> {
        coin_helper::fungible_asset_to_coin<T0>(swap_exact_fa_for_fa(p0, p1, p2, p3, p4))
    }
    public fun swap_exact_fa_for_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): fungible_asset::FungibleAsset {
        let (_v0,_v1) = liquidity_pool::get_tokens(p1);
        let _v2 = fungible_asset::asset_metadata(&p2);
        let _v3 = fungible_asset::amount(&p2);
        let (_v4,_v5) = liquidity_pool::swap(p0, p1, _v2 == _v0, true, _v3, p4);
        let _v6 = _v5;
        let _v7 = _v4;
        assert!(fungible_asset::amount(&_v7) >= p3, 403);
        let _v8 = liquidity_pool::get_swap_receipt_amount(&_v6);
        assert!(fungible_asset::amount(&p2) == _v8, 405);
        liquidity_pool::pay_swap(p2, _v6);
        _v7
    }
    public fun swap_exact_fa_for_fa_multi_hops(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: fungible_asset::FungibleAsset, p3: u64): fungible_asset::FungibleAsset {
        let _v0 = option::none<fungible_asset::FungibleAsset>();
        let _v1 = option::some<fungible_asset::FungibleAsset>(p2);
        let _v2 = 0x1::vector::length<object::Object<liquidity_pool::LiquidityPool>>(&p1);
        let _v3 = 0;
        let _v4 = false;
        loop {
            let _v5;
            let _v6;
            if (_v4) _v3 = _v3 + 1 else _v4 = true;
            if (!(_v3 < _v2)) break;
            let _v7 = _v2 - 1;
            let _v8 = _v3 == _v7;
            let _v9 = *0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v3);
            let _v10 = option::extract<fungible_asset::FungibleAsset>(&mut _v1);
            let (_v11,_v12) = liquidity_pool::get_tokens(_v9);
            let _v13 = fungible_asset::asset_metadata(&_v10);
            if (_v8) _v6 = p3 else _v6 = 0;
            if (_v13 == _v11) _v5 = tick_math::min_sqrt_price() else _v5 = tick_math::max_sqrt_price();
            let _v14 = swap_exact_fa_for_fa(p0, _v9, _v10, _v6, _v5);
            if (!_v8) {
                option::fill<fungible_asset::FungibleAsset>(&mut _v1, _v14);
                continue
            };
            option::fill<fungible_asset::FungibleAsset>(&mut _v0, _v14);
            continue
        };
        option::destroy_none<fungible_asset::FungibleAsset>(_v1);
        option::destroy_some<fungible_asset::FungibleAsset>(_v0)
    }
    public fun swap_fa_for_exact_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): (fungible_asset::FungibleAsset, coin::Coin<T0>) {
        let (_v0,_v1) = swap_fa_for_exact_fa(p0, p1, p2, p3, p4);
        let _v2 = coin_helper::fungible_asset_to_coin<T0>(_v1);
        (_v0, _v2)
    }
    public fun swap_fa_for_exact_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let (_v0,_v1) = liquidity_pool::get_tokens(p1);
        let _v2 = fungible_asset::asset_metadata(&p2);
        let (_v3,_v4) = liquidity_pool::swap(p0, p1, _v2 == _v0, false, p3, p4);
        let _v5 = _v4;
        let _v6 = _v3;
        assert!(fungible_asset::amount(&_v6) == p3, 402);
        let _v7 = liquidity_pool::get_swap_receipt_amount(&_v5);
        assert!(fungible_asset::amount(&p2) >= _v7, 404);
        liquidity_pool::pay_swap(fungible_asset::extract(&mut p2, _v7), _v5);
        (p2, _v6)
    }
    public fun swap_fa_for_exact_fa_multi_hops(p0: &signer, p1: vector<object::Object<liquidity_pool::LiquidityPool>>, p2: fungible_asset::FungibleAsset, p3: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0 = 0x1::vector::length<object::Object<liquidity_pool::LiquidityPool>>(&p1);
        assert!(_v0 > 0, 406);
        let _v1 = fungible_asset::asset_metadata(&p2);
        let _v2 = 0;
        let _v3 = false;
        'l0: loop {
            loop {
                if (_v3) _v2 = _v2 + 1 else _v3 = true;
                if (!(_v2 < _v0)) break 'l0;
                let (_v4,_v5) = liquidity_pool::get_tokens(*0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v2));
                let _v6 = _v5;
                let _v7 = _v4;
                if (_v1 == _v7) {
                    _v1 = _v6;
                    continue
                };
                if (!(_v1 == _v6)) break;
                _v1 = _v7;
                continue
            };
            abort 407
        };
        let _v8 = option::none<fungible_asset::FungibleAsset>();
        let _v9 = option::none<liquidity_pool::SwapReciept>();
        let _v10 = _v0;
        'l1: loop {
            loop {
                let _v11;
                let _v12;
                let _v13;
                if (!(_v10 > 0)) break 'l1;
                _v10 = _v10 - 1;
                let _v14 = _v0 - 1;
                let _v15 = _v10 == _v14;
                let _v16 = *0x1::vector::borrow<object::Object<liquidity_pool::LiquidityPool>>(&p1, _v10);
                let (_v17,_v18) = liquidity_pool::get_tokens(_v16);
                let _v19 = _v18;
                if (_v15) _v13 = _v1 == _v19 else _v13 = liquidity_pool::get_swap_receipt_token_metadata(option::borrow<liquidity_pool::SwapReciept>(&_v9)) == _v19;
                let _v20 = _v13;
                if (_v15) _v12 = p3 else _v12 = liquidity_pool::get_swap_receipt_amount(option::borrow<liquidity_pool::SwapReciept>(&_v9));
                if (_v20) _v11 = tick_math::min_sqrt_price() else _v11 = tick_math::max_sqrt_price();
                let (_v21,_v22) = liquidity_pool::swap(p0, _v16, _v20, false, _v12, _v11);
                let _v23 = _v21;
                if (_v15) if (fungible_asset::amount(&_v23) == p3) option::fill<fungible_asset::FungibleAsset>(&mut _v8, _v23) else break else {
                    let _v24 = option::extract<liquidity_pool::SwapReciept>(&mut _v9);
                    liquidity_pool::pay_swap(_v23, _v24)
                };
                option::fill<liquidity_pool::SwapReciept>(&mut _v9, _v22);
                continue
            };
            abort 402
        };
        assert!(option::is_some<liquidity_pool::SwapReciept>(&_v9), 401);
        let _v25 = option::destroy_some<liquidity_pool::SwapReciept>(_v9);
        let _v26 = liquidity_pool::get_swap_receipt_amount(&_v25);
        assert!(fungible_asset::amount(&p2) >= _v26, 404);
        liquidity_pool::pay_swap(fungible_asset::extract(&mut p2, _v26), _v25);
        let _v27 = option::destroy_some<fungible_asset::FungibleAsset>(_v8);
        (p2, _v27)
    }
    public fun swap_partial_coin_for_coin<T0, T1>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): (coin::Coin<T0>, coin::Coin<T1>) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        let _v1 = fungible_asset::amount(&_v0);
        let (_v2,_v3) = internal_swap_partial_fa(p0, p1, _v0, true, _v1, p3, p4);
        let _v4 = coin_helper::fungible_asset_to_coin<T0>(_v2);
        let _v5 = coin_helper::fungible_asset_to_coin<T1>(_v3);
        (_v4, _v5)
    }
    public fun swap_partial_coin_for_fa<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: coin::Coin<T0>, p3: u64, p4: u128): (coin::Coin<T0>, fungible_asset::FungibleAsset) {
        let _v0 = coin::coin_to_fungible_asset<T0>(p2);
        let _v1 = fungible_asset::amount(&_v0);
        let (_v2,_v3) = internal_swap_partial_fa(p0, p1, _v0, true, _v1, p3, p4);
        (coin_helper::fungible_asset_to_coin<T0>(_v2), _v3)
    }
    public fun swap_partial_fa_for_coin<T0>(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): (fungible_asset::FungibleAsset, coin::Coin<T0>) {
        let _v0 = fungible_asset::amount(&p2);
        let (_v1,_v2) = internal_swap_partial_fa(p0, p1, p2, true, _v0, p3, p4);
        let _v3 = coin_helper::fungible_asset_to_coin<T0>(_v2);
        (_v1, _v3)
    }
    public fun swap_partial_fa_for_fa(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: fungible_asset::FungibleAsset, p3: u64, p4: u128): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset) {
        let _v0 = fungible_asset::amount(&p2);
        let (_v1,_v2) = internal_swap_partial_fa(p0, p1, p2, true, _v0, p3, p4);
        (_v1, _v2)
    }
}
