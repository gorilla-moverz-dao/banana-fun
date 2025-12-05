module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_pool {
    use 0x1::account;
    use 0x1::aptos_hash;
    use 0x1::bcs;
    use 0x1::dispatchable_fungible_asset;
    use 0x1::error;
    use 0x1::event;
    use 0x1::fungible_asset;
    use 0x1::math128;
    use 0x1::math64;
    use 0x1::object;
    use 0x1::primary_fungible_store;
    use 0x1::signer;
    use 0x1::string;
    use 0x1::string_utils;
    use 0x1::table;
    use 0x1::timestamp;
    use 0x1::vector;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::config;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::emergency;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::fa_helper;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::fee_tier;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::fixed_point;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::i128;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::i64;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::oracle;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::sqrt_price_math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::swap_math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick_bitmap;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick_math;
    friend 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::position_nft_manager;
    friend 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::reward_manager;
    friend 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::router;
    struct AddLiquidityEvent has drop, store {
        user: address,
        pool: address,
        position_id: u64,
        liquidity: u128,
        amount_0: u64,
        amount_1: u64,
    }
    struct AddRewardEvent has drop, store {
        pool: address,
        reward_index: u64,
        manager: address,
        amount: u64,
    }
    struct CollectFeeEvent has drop, store {
        user: address,
        pool: address,
        position_id: u64,
        amount_0: u64,
        amount_1: u64,
    }
    struct CollectProtocolFee has drop, store {
        admin: address,
        pool: address,
        amount_0: u64,
        amount_1: u64,
    }
    struct CollectRewardEvent has drop, store {
        user: address,
        pool: address,
        position_id: u64,
        reward_index: u64,
        amount: u64,
    }
    struct CreatePoolEvent has drop, store {
        creator: address,
        pool: address,
        token_x: object::Object<fungible_asset::Metadata>,
        token_y: object::Object<fungible_asset::Metadata>,
        fee: u64,
        tick_spacing: u32,
    }
    struct IncreaseObservationCardinalityNextEvent has drop, store {
        pool: address,
        observation_cardinality_next_old: u16,
        observation_cardinality_next_new: u16,
    }
    struct InitRewardEvent has drop, store {
        pool: address,
        reward_index: u64,
        manager: address,
    }
    struct LiquidityPool has key {
        token_0_reserve: object::Object<fungible_asset::FungibleStore>,
        token_1_reserve: object::Object<fungible_asset::FungibleStore>,
        current_tick: u32,
        current_sqrt_price: u128,
        liquidity: u128,
        tick_bitmap: table::Table<u16, u256>,
        ticks: table::Table<u32, TickInfo>,
        positions: table::Table<vector<u8>, Position>,
        next_position_id: u64,
        fee_growth_global_0_x64: u256,
        fee_growth_global_1_x64: u256,
        reward_infos: vector<PoolRewardInfo>,
        reward_last_updated_at_seconds: u64,
        fee_rate: u64,
        tick_spacing: u32,
        max_liquidity_per_tick: u128,
        unlocked: bool,
        extend_ref: object::ExtendRef,
    }
    struct TickInfo has drop, store {
        liquditiy_gross: u128,
        liquidity_net: i128::I128,
        fee_growth_outside_0_x64: u256,
        fee_growth_outside_1_x64: u256,
        reward_growths_outside: vector<u256>,
        initialized: bool,
    }
    struct Position has drop, store {
        id: u64,
        tick_lower: u32,
        tick_upper: u32,
        liquidity: u128,
        fee_growth_inside_0_last_x64: u256,
        fee_growth_inside_1_last_x64: u256,
        tokens_owed_0: u64,
        tokens_owed_1: u64,
        reward_infos: vector<PositionRewardInfo>,
    }
    struct PoolRewardInfo has copy, drop, store {
        token_metadata: object::Object<fungible_asset::Metadata>,
        remaining_reward: u64,
        emissions_per_second: u64,
        growth_global: u256,
        manager: address,
    }
    struct LiquidityPoolView has drop {
        pool_addr: address,
        token_0: address,
        token_1: address,
        token_0_decimals: u8,
        token_1_decimals: u8,
        token_0_reserve: u64,
        token_1_reserve: u64,
        current_tick: u32,
        current_sqrt_price: u128,
        liquidity: u128,
        fee_growth_global_0_x64: u256,
        fee_growth_global_1_x64: u256,
        reward_infos: vector<PoolRewardInfo>,
        fee_rate: u64,
        tick_spacing: u32,
    }
    struct LiquidityPools has key {
        all_pools: vector<object::Object<LiquidityPool>>,
    }
    struct PoolAccountCap has key {
        signer_cap: account::SignerCapability,
    }
    struct PoolOracle has key {
        observation_index: u16,
        observation_cardinality: u16,
        observation_cardinality_next: u16,
        observations: vector<oracle::Observation>,
    }
    struct PositionRewardInfo has copy, drop, store {
        reward_growth_inside_last: u256,
        amount_owed: u64,
    }
    struct RemoveLiquidityEvent has drop, store {
        user: address,
        pool: address,
        position_id: u64,
        liquidity: u128,
        amount_0: u64,
        amount_1: u64,
    }
    struct RemoveRewardEvent has drop, store {
        pool: address,
        reward_index: u64,
        manager: address,
        amount: u64,
    }
    struct SwapEvent has drop, store {
        pool: address,
        zero_for_one: bool,
        is_exact_in: bool,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        sqrt_price_after: u128,
        liquidity_after: u128,
        tick_after: u32,
    }
    struct SwapReciept {
        pool: object::Object<LiquidityPool>,
        token_metadata: object::Object<fungible_asset::Metadata>,
        amount_in: u64,
        protocol_fee_amount: u64,
    }
    struct TickView has copy, drop, store {
        tick: u32,
        liquidity_gross: u128,
        liquidity_net: i128::I128,
        fee_growth_outside_0_x64: u256,
        fee_growth_outside_1_x64: u256,
        reward_growths_outside: vector<u256>,
    }
    struct UpdateRewardEmissionsEvent has drop, store {
        pool: address,
        reward_index: u64,
        manager: address,
        emissions_per_second: u64,
    }
    struct UpdateRewardManagerEvent has drop, store {
        pool: address,
        reward_index: u64,
        manager: address,
    }
    public fun swap(p0: &signer, p1: object::Object<LiquidityPool>, p2: bool, p3: bool, p4: u64, p5: u128): (fungible_asset::FungibleAsset, SwapReciept)
        acquires LiquidityPool, PoolAccountCap, PoolOracle
    {
        let _v0;
        let _v1;
        let _v2;
        let _v3;
        let _v4;
        emergency::assert_no_emergency();
        assert!(p4 > 0, 109);
        let _v5 = object::object_address<LiquidityPool>(&p1);
        let _v6 = borrow_global_mut<LiquidityPool>(_v5);
        let _v7 = freeze(_v6);
        create_oracle_if_not_exists(_v7);
        let _v8 = object::address_from_extend_ref(&_v7.extend_ref);
        let _v9 = borrow_global_mut<PoolOracle>(_v8);
        assert!(*&_v6.unlocked, 102);
        let _v10 = &mut _v6.unlocked;
        *_v10 = false;
        loop {
            let _v11;
            if (p2) {
                let _v12;
                let _v13 = *&_v6.current_sqrt_price;
                if (p5 < _v13) {
                    let _v14 = tick_math::min_sqrt_price();
                    _v12 = p5 >= _v14
                } else _v12 = false;
                if (_v12) break;
                abort 110
            };
            let _v15 = *&_v6.current_sqrt_price;
            if (p5 > _v15) {
                let _v16 = tick_math::max_sqrt_price();
                _v11 = p5 <= _v16
            } else _v11 = false;
            if (_v11) break;
            abort 110
        };
        let _v17 = update_pool_reward_infos(_v6);
        let _v18 = *&_v6.tick_spacing;
        let _v19 = *&_v6.current_sqrt_price;
        let _v20 = *&_v6.current_tick;
        let _v21 = *&_v6.liquidity;
        let _v22 = p4;
        let _v23 = 0;
        let _v24 = config::protocol_fee_rate();
        let _v25 = config::fee_scale();
        let _v26 = 0;
        let _v27 = 0;
        let _v28 = signer::address_of(p0);
        let _v29 = freeze(_v6);
        let _v30 = get_fee_rate(_v28, _v29);
        if (p2) _v4 = *&_v6.fee_growth_global_0_x64 else _v4 = *&_v6.fee_growth_global_1_x64;
        let _v31 = _v4;
        let _v32 = timestamp::now_seconds();
        'l0: loop {
            loop {
                let _v33;
                let _v34;
                if (_v22 > 0) _v34 = _v19 != p5 else _v34 = false;
                if (!_v34) break 'l0;
                let _v35 = _v19;
                let (_v36,_v37) = tick_bitmap::get_next_initialized_tick_within_one_word(&_v6.tick_bitmap, _v20, _v18, p2);
                let _v38 = _v36;
                let _v39 = tick::min_tick();
                if (_v38 < _v39) _v38 = tick::min_tick() else {
                    let _v40 = tick::max_tick();
                    if (_v38 > _v40) _v38 = tick::max_tick()
                };
                let _v41 = tick_math::get_sqrt_price_at_tick(_v38);
                if (p2) _v33 = math128::max(p5, _v41) else _v33 = math128::min(p5, _v41);
                let (_v42,_v43,_v44,_v45) = swap_math::compute_swap_step(_v19, _v33, _v21, _v22, p3, _v30);
                let _v46 = _v45;
                let _v47 = _v44;
                let _v48 = _v43;
                let _v49 = _v42;
                _v19 = _v49;
                if (p3) {
                    let _v50 = _v48 + _v46;
                    _v22 = _v22 - _v50;
                    _v23 = _v23 + _v47
                } else {
                    _v22 = _v22 - _v47;
                    let _v51 = _v48 + _v46;
                    _v23 = _v23 + _v51
                };
                _v27 = _v27 + _v46;
                if (_v24 > 0) {
                    let _v52 = _v25;
                    if (!(_v52 != 0)) break;
                    let _v53 = _v46 as u128;
                    let _v54 = _v24 as u128;
                    let _v55 = _v53 * _v54;
                    let _v56 = _v52 as u128;
                    let _v57 = (_v55 / _v56) as u64;
                    _v26 = _v26 + _v57;
                    _v46 = _v46 - _v57
                };
                if (_v21 != 0u128) {
                    let _v58 = fixed_point::u64_to_x64_u256(_v46);
                    let _v59 = _v21 as u256;
                    let _v60 = _v58 / _v59;
                    _v31 = _v31 + _v60
                };
                if (_v49 == _v41) {
                    let _v61;
                    let _v62;
                    if (_v37) {
                        let _v63;
                        let _v64;
                        let _v65 = &mut _v6.ticks;
                        if (p2) _v64 = _v31 else _v64 = *&_v6.fee_growth_global_0_x64;
                        if (p2) _v63 = *&_v6.fee_growth_global_1_x64 else _v63 = _v31;
                        let _v66 = &_v17;
                        let _v67 = cross_tick(_v65, _v38, _v64, _v63, _v66);
                        if (p2) _v67 = i128::new(i128::abs(&_v67), !i128::is_negative(&_v67));
                        let _v68 = &_v67;
                        _v21 = add_delta_liquidity(_v21, _v68)
                    };
                    if (p2) {
                        let _v69 = tick::min_tick();
                        _v62 = _v38 > _v69
                    } else _v62 = false;
                    if (_v62) _v61 = _v38 - 1u32 else _v61 = _v38;
                    _v20 = _v61;
                    continue
                };
                if (!(_v19 != _v35)) continue;
                _v20 = tick_math::get_tick_at_sqrt_price(_v49);
                continue
            };
            let _v70 = error::invalid_argument(4);
            abort _v70
        };
        let _v71 = *&_v6.current_tick;
        if (_v20 != _v71) {
            let _v72 = &mut _v9.observations;
            let _v73 = *&_v9.observation_index;
            let _v74 = *&_v6.current_tick;
            let _v75 = *&_v6.liquidity;
            let _v76 = *&_v9.observation_cardinality;
            let _v77 = *&_v9.observation_cardinality_next;
            let (_v78,_v79) = oracle::write(_v72, _v73, _v32, _v74, _v75, _v76, _v77);
            let _v80 = &mut _v9.observation_index;
            *_v80 = _v78;
            let _v81 = &mut _v9.observation_cardinality;
            *_v81 = _v79;
            let _v82 = &mut _v6.current_tick;
            *_v82 = _v20;
            let _v83 = &mut _v6.current_sqrt_price;
            *_v83 = _v19
        } else {
            let _v84 = &mut _v6.current_sqrt_price;
            *_v84 = _v19
        };
        let _v85 = &mut _v6.liquidity;
        *_v85 = _v21;
        if (p2) {
            let _v86 = &mut _v6.fee_growth_global_0_x64;
            *_v86 = _v31
        } else {
            let _v87 = &mut _v6.fee_growth_global_1_x64;
            *_v87 = _v31
        };
        if (p3) {
            let _v88 = p4 - _v22;
            _v3 = _v23;
            _v2 = _v88
        } else {
            _v3 = p4 - _v22;
            _v2 = _v23
        };
        let _v89 = _v3;
        let _v90 = _v2;
        let _v91 = object::object_address<LiquidityPool>(&p1);
        let _v92 = *&_v6.current_sqrt_price;
        let _v93 = *&_v6.liquidity;
        let _v94 = *&_v6.current_tick;
        event::emit<SwapEvent>(SwapEvent{pool: _v91, zero_for_one: p2, is_exact_in: p3, amount_in: _v90, amount_out: _v89, fee_amount: _v27, sqrt_price_after: _v92, liquidity_after: _v93, tick_after: _v94});
        let _v95 = get_pool_account_signer();
        if (p2) {
            let _v96 = &_v95;
            let _v97 = *&_v6.token_1_reserve;
            let _v98 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v96, _v97, _v89);
            let _v99 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v6.token_0_reserve);
            _v1 = SwapReciept{pool: p1, token_metadata: _v99, amount_in: _v90, protocol_fee_amount: _v26};
            _v0 = _v98
        } else {
            let _v100 = &_v95;
            let _v101 = *&_v6.token_0_reserve;
            let _v102 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v100, _v101, _v89);
            let _v103 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v6.token_1_reserve);
            _v1 = SwapReciept{pool: p1, token_metadata: _v103, amount_in: _v90, protocol_fee_amount: _v26};
            _v0 = _v102
        };
        (_v0, _v1)
    }
    public fun observations(p0: object::Object<LiquidityPool>, p1: u16): (u64, i64::I64, u256, bool)
        acquires PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = oracle::get_observation_or_empty(&borrow_global<PoolOracle>(_v0).observations, p1);
        let _v2 = oracle::timestamp(&_v1);
        let _v3 = oracle::tick_cumulative(&_v1);
        let _v4 = oracle::seconds_per_liquidity_cumulative(&_v1);
        let _v5 = oracle::initialized(&_v1);
        (_v2, _v3, _v4, _v5)
    }
    fun add_delta_liquidity(p0: u128, p1: &i128::I128): u128 {
        let _v0;
        if (i128::is_positive(p1)) {
            let _v1 = p0 as u256;
            let _v2 = i128::abs(p1) as u256;
            _v0 = _v1 + _v2
        } else {
            let _v3 = i128::abs(p1);
            if (p0 >= _v3) {
                let _v4 = p0 as u256;
                let _v5 = i128::abs(p1) as u256;
                _v0 = _v4 - _v5
            } else abort 106
        };
        let _v6 = _v0;
        assert!(_v6 <= 340282366920938463463374607431768211455u256, 1);
        _v6 as u128
    }
    public fun add_liquidity(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u128, p4: &mut fungible_asset::FungibleAsset, p5: &mut fungible_asset::FungibleAsset)
        acquires LiquidityPool, PoolOracle
    {
        let _v0;
        emergency::assert_no_emergency();
        assert!(p3 > 0u128, 122);
        let _v1 = object::object_address<LiquidityPool>(&p1);
        let _v2 = borrow_global_mut<LiquidityPool>(_v1);
        assert!(*&_v2.unlocked, 102);
        let _v3 = freeze(_v2);
        create_oracle_if_not_exists(_v3);
        let _v4 = object::address_from_extend_ref(&_v3.extend_ref);
        let _v5 = borrow_global_mut<PoolOracle>(_v4);
        let _v6 = fungible_asset::metadata_from_asset(freeze(p4));
        let _v7 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v2.token_0_reserve);
        if (_v6 == _v7) {
            let _v8 = fungible_asset::metadata_from_asset(freeze(p5));
            let _v9 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v2.token_1_reserve);
            _v0 = _v8 == _v9
        } else _v0 = false;
        assert!(_v0, 107);
        let _v10 = signer::address_of(p0);
        let _v11 = i128::new(p3, false);
        let (_v12,_v13) = modify_position(_v2, _v5, _v10, p2, _v11);
        let _v14 = _v13;
        let _v15 = _v12;
        assert!(fungible_asset::amount(freeze(p4)) >= _v15, 108);
        assert!(fungible_asset::amount(freeze(p5)) >= _v14, 108);
        let _v16 = fungible_asset::extract(p4, _v15);
        let _v17 = fungible_asset::extract(p5, _v14);
        dispatchable_fungible_asset::deposit<fungible_asset::FungibleStore>(*&_v2.token_0_reserve, _v16);
        dispatchable_fungible_asset::deposit<fungible_asset::FungibleStore>(*&_v2.token_1_reserve, _v17);
        let _v18 = object::object_address<LiquidityPool>(&p1);
        event::emit<AddLiquidityEvent>(AddLiquidityEvent{user: _v10, pool: _v18, position_id: p2, liquidity: p3, amount_0: _v15, amount_1: _v14});
    }
    public fun add_reward(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: fungible_asset::FungibleAsset)
        acquires LiquidityPool, PoolAccountCap
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = vector::borrow<PoolRewardInfo>(&_v1.reward_infos, p2);
        let _v3 = *&_v2.manager;
        let _v4 = signer::address_of(p0);
        assert!(_v3 == _v4, 118);
        let _v5 = *&_v2.token_metadata;
        let _v6 = fungible_asset::metadata_from_asset(&p3);
        assert!(_v5 == _v6, 119);
        let _v7 = update_pool_reward_infos(_v1);
        let _v8 = vector::borrow_mut<PoolRewardInfo>(&mut _v1.reward_infos, p2);
        let _v9 = fungible_asset::amount(&p3);
        let _v10 = *&_v8.remaining_reward + _v9;
        let _v11 = &mut _v8.remaining_reward;
        *_v11 = _v10;
        primary_fungible_store::deposit(get_pool_account_address(), p3);
        let _v12 = object::object_address<LiquidityPool>(&p1);
        let _v13 = *&_v8.manager;
        event::emit<AddRewardEvent>(AddRewardEvent{pool: _v12, reward_index: p2, manager: _v13, amount: _v9});
    }
    fun assert_ticks(p0: u32, p1: u32, p2: u32) {
        let _v0;
        assert!(p0 < p1, 103);
        if (tick::is_spaced_tick(p0, p2)) _v0 = tick::is_spaced_tick(p1, p2) else _v0 = false;
        assert!(_v0, 104);
        let _v1 = tick::max_tick();
        assert!(p1 <= _v1, 105);
    }
    fun clear_tick(p0: &mut table::Table<u32, TickInfo>, p1: u32) {
        let _v0 = table::remove<u32,TickInfo>(p0, p1);
    }
    public fun close_position(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64)
        acquires LiquidityPool
    {
        emergency::assert_no_emergency();
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        assert!(*&_v1.unlocked, 102);
        let _v2 = signer::address_of(p0);
        let _v3 = get_position_key(&_v2, p2);
        assert!(table::contains<vector<u8>,Position>(&_v1.positions, _v3), 113);
        let _v4 = table::borrow_mut<vector<u8>,Position>(&mut _v1.positions, _v3);
        assert!(*&_v4.liquidity == 0u128, 114);
        assert!(*&_v4.tokens_owed_0 == 0, 115);
        assert!(*&_v4.tokens_owed_1 == 0, 115);
        let _v5 = 0;
        let _v6 = false;
        let _v7 = vector::length<PositionRewardInfo>(&_v4.reward_infos);
        'l0: loop {
            loop {
                if (_v6) _v5 = _v5 + 1 else _v6 = true;
                if (!(_v5 < _v7)) break 'l0;
                if (*&vector::borrow<PositionRewardInfo>(&_v4.reward_infos, _v5).amount_owed == 0) continue;
                break
            };
            abort 116
        };
        let _v8 = table::remove<vector<u8>,Position>(&mut _v1.positions, _v3);
    }
    public fun collect_fee(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u64, p4: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset)
        acquires LiquidityPool, PoolAccountCap
    {
        emergency::assert_no_emergency();
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = signer::address_of(p0);
        let _v3 = get_position_mut(&mut _v1.positions, _v2, p2);
        if (*&_v3.liquidity > 0u128) {
            let _v4 = &_v1.ticks;
            let _v5 = *&_v3.tick_lower;
            let _v6 = *&_v3.tick_upper;
            let _v7 = *&_v1.current_tick;
            let _v8 = *&_v1.fee_growth_global_0_x64;
            let _v9 = *&_v1.fee_growth_global_1_x64;
            let (_v10,_v11) = get_fee_growth_inside_tick(_v4, _v5, _v6, _v7, _v8, _v9);
            update_position_fee(_v3, _v10, _v11)
        };
        let _v12 = *&_v3.tokens_owed_0;
        let _v13 = math64::min(p3, _v12);
        let _v14 = *&_v3.tokens_owed_0 - _v13;
        let _v15 = &mut _v3.tokens_owed_0;
        *_v15 = _v14;
        let _v16 = *&_v3.tokens_owed_1;
        let _v17 = math64::min(p4, _v16);
        let _v18 = *&_v3.tokens_owed_1 - _v17;
        let _v19 = &mut _v3.tokens_owed_1;
        *_v19 = _v18;
        let _v20 = object::object_address<LiquidityPool>(&p1);
        event::emit<CollectFeeEvent>(CollectFeeEvent{user: _v2, pool: _v20, position_id: p2, amount_0: _v13, amount_1: _v17});
        let _v21 = get_pool_account_signer();
        let _v22 = &_v21;
        let _v23 = *&_v1.token_0_reserve;
        let _v24 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v22, _v23, _v13);
        let _v25 = &_v21;
        let _v26 = *&_v1.token_1_reserve;
        let _v27 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v25, _v26, _v17);
        (_v24, _v27)
    }
    public fun collect_reward(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u64, p4: u64): fungible_asset::FungibleAsset
        acquires LiquidityPool, PoolAccountCap
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = update_pool_reward_infos(_v1);
        let _v3 = signer::address_of(p0);
        let _v4 = get_position_mut(&mut _v1.positions, _v3, p2);
        if (*&_v4.liquidity > 0u128) {
            let _v5 = &_v1.ticks;
            let _v6 = *&_v4.tick_lower;
            let _v7 = *&_v4.tick_upper;
            let _v8 = *&_v1.current_tick;
            let _v9 = &_v2;
            let _v10 = get_reward_growths_inside(_v5, _v6, _v7, _v8, _v9);
            let _v11 = &_v10;
            update_position_rewards(_v4, _v11)
        };
        let _v12 = vector::borrow_mut<PositionRewardInfo>(&mut _v4.reward_infos, p3);
        let _v13 = *&_v12.amount_owed;
        let _v14 = math64::min(p4, _v13);
        let _v15 = *&_v12.amount_owed - _v14;
        let _v16 = &mut _v12.amount_owed;
        *_v16 = _v15;
        let _v17 = object::object_address<LiquidityPool>(&p1);
        event::emit<CollectRewardEvent>(CollectRewardEvent{user: _v3, pool: _v17, position_id: p2, reward_index: p3, amount: _v14});
        let _v18 = get_pool_account_signer();
        let _v19 = vector::borrow<PoolRewardInfo>(&_v1.reward_infos, p3);
        let _v20 = &_v18;
        let _v21 = *&_v19.token_metadata;
        primary_fungible_store::withdraw<fungible_asset::Metadata>(_v20, _v21, _v14)
    }
    public fun consult(p0: object::Object<LiquidityPool>, p1: u64): (i64::I64, u128)
        acquires LiquidityPool, PoolOracle
    {
        assert!(p1 != 0, 121);
        let _v0 = vector::empty<u64>();
        vector::push_back<u64>(&mut _v0, p1);
        vector::push_back<u64>(&mut _v0, 0);
        let (_v1,_v2) = observe(p0, _v0);
        let _v3 = _v2;
        let _v4 = _v1;
        let _v5 = vector::borrow<i64::I64>(&_v4, 1);
        let _v6 = vector::borrow<i64::I64>(&_v4, 0);
        let _v7 = i64::sub(_v5, _v6);
        let _v8 = *vector::borrow<u256>(&_v3, 1);
        let _v9 = *vector::borrow<u256>(&_v3, 0);
        let _v10 = _v8 - _v9;
        let _v11 = &_v7;
        let _v12 = i64::new(p1, false);
        let _v13 = &_v12;
        let _v14 = i64::div(_v11, _v13);
        if (i64::is_negative(&_v7)) {
            let _v15 = &_v7;
            let _v16 = i64::new(p1, false);
            let _v17 = &_v16;
            let _v18 = i64::mod(_v15, _v17);
            if (!i64::is_zero(&_v18)) {
                let _v19 = &_v14;
                let _v20 = i64::new(1, false);
                let _v21 = &_v20;
                _v14 = i64::sub(_v19, _v21)
            }
        };
        let _v22 = (p1 as u256) * 1461501637330902918203684832716283019655932542975u256;
        let _v23 = _v10 << 32u8;
        let _v24 = (_v22 / _v23) as u128;
        (_v14, _v24)
    }
    public fun count_pool(): u64
        acquires LiquidityPools
    {
        vector::length<object::Object<LiquidityPool>>(&borrow_global<LiquidityPools>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).all_pools)
    }
    fun create_oracle(p0: &signer) {
        let _v0 = vector::empty<oracle::Observation>();
        let _v1 = PoolOracle{observation_index: 0u16, observation_cardinality: 0u16, observation_cardinality_next: 0u16, observations: _v0};
        let _v2 = &mut (&mut _v1).observations;
        let _v3 = timestamp::now_seconds();
        let (_v4,_v5) = oracle::initialize(_v2, _v3);
        let _v6 = &mut (&mut _v1).observation_cardinality;
        *_v6 = _v4;
        let _v7 = &mut (&mut _v1).observation_cardinality_next;
        *_v7 = _v5;
        move_to<PoolOracle>(p0, _v1);
    }
    fun create_oracle_if_not_exists(p0: &LiquidityPool) {
        let _v0 = object::address_from_extend_ref(&p0.extend_ref);
        if (exists<PoolOracle>(_v0)) return ();
        let _v1 = object::generate_signer_for_extending(&p0.extend_ref);
        create_oracle(&_v1);
    }
    friend fun create_pool(p0: &signer, p1: object::Object<fungible_asset::Metadata>, p2: object::Object<fungible_asset::Metadata>, p3: u64, p4: u128): object::Object<LiquidityPool>
        acquires LiquidityPools, PoolAccountCap
    {
        emergency::assert_no_emergency();
        assert!(fa_helper::is_sorted(p1, p2), 101);
        let _v0 = fee_tier::get_tick_spacing(p3);
        let _v1 = tick_math::get_tick_at_sqrt_price(p4);
        let _v2 = account::create_signer_with_capability(&borrow_global<PoolAccountCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap);
        let _v3 = p3;
        let _v4 = p2;
        let _v5 = p1;
        let _v6 = vector[];
        vector::append<u8>(&mut _v6, vector[112u8, 111u8, 111u8, 108u8]);
        let _v7 = &mut _v6;
        let _v8 = object::object_address<fungible_asset::Metadata>(&_v5);
        let _v9 = bcs::to_bytes<address>(&_v8);
        vector::append<u8>(_v7, _v9);
        let _v10 = &mut _v6;
        let _v11 = object::object_address<fungible_asset::Metadata>(&_v4);
        let _v12 = bcs::to_bytes<address>(&_v11);
        vector::append<u8>(_v10, _v12);
        let _v13 = &mut _v6;
        let _v14 = bcs::to_bytes<u64>(&_v3);
        vector::append<u8>(_v13, _v14);
        let _v15 = object::create_named_object(&_v2, _v6);
        let _v16 = &_v15;
        let _v17 = object::generate_signer(_v16);
        let _v18 = &_v17;
        let _v19 = object::create_object_from_object(_v18);
        let _v20 = fungible_asset::create_store<fungible_asset::Metadata>(&_v19, p1);
        let _v21 = object::create_object_from_object(_v18);
        let _v22 = fungible_asset::create_store<fungible_asset::Metadata>(&_v21, p2);
        let _v23 = table::new<u16,u256>();
        let _v24 = table::new<u32,TickInfo>();
        let _v25 = table::new<vector<u8>,Position>();
        let _v26 = vector::empty<PoolRewardInfo>();
        let _v27 = tick::tick_spacing_to_max_liquidity_per_tick(_v0);
        let _v28 = object::generate_extend_ref(_v16);
        let _v29 = LiquidityPool{token_0_reserve: _v20, token_1_reserve: _v22, current_tick: _v1, current_sqrt_price: p4, liquidity: 0u128, tick_bitmap: _v23, ticks: _v24, positions: _v25, next_position_id: 1, fee_growth_global_0_x64: 0u256, fee_growth_global_1_x64: 0u256, reward_infos: _v26, reward_last_updated_at_seconds: 0, fee_rate: p3, tick_spacing: _v0, max_liquidity_per_tick: _v27, unlocked: true, extend_ref: _v28};
        move_to<LiquidityPool>(_v18, _v29);
        create_oracle(_v18);
        let _v30 = &mut borrow_global_mut<LiquidityPools>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).all_pools;
        let _v31 = object::object_from_constructor_ref<LiquidityPool>(_v16);
        vector::push_back<object::Object<LiquidityPool>>(_v30, _v31);
        let _v32 = signer::address_of(p0);
        let _v33 = object::address_from_constructor_ref(_v16);
        event::emit<CreatePoolEvent>(CreatePoolEvent{creator: _v32, pool: _v33, token_x: p1, token_y: p2, fee: p3, tick_spacing: _v0});
        object::object_from_constructor_ref<LiquidityPool>(_v16)
    }
    fun cross_tick(p0: &mut table::Table<u32, TickInfo>, p1: u32, p2: u256, p3: u256, p4: &vector<u256>): i128::I128 {
        let _v0 = table::borrow_mut<u32,TickInfo>(p0, p1);
        let _v1 = *&_v0.fee_growth_outside_0_x64;
        let _v2 = p2 - _v1;
        let _v3 = &mut _v0.fee_growth_outside_0_x64;
        *_v3 = _v2;
        let _v4 = *&_v0.fee_growth_outside_1_x64;
        let _v5 = p3 - _v4;
        let _v6 = &mut _v0.fee_growth_outside_1_x64;
        *_v6 = _v5;
        update_reward_growths(&mut _v0.reward_growths_outside, p4);
        *&_v0.liquidity_net
    }
    public fun extract_core_position(p0: &Position): (u64, u32, u32, u128, u256, u256, u64, u64) {
        let _v0 = *&p0.id;
        let _v1 = *&p0.tick_lower;
        let _v2 = *&p0.tick_upper;
        let _v3 = *&p0.liquidity;
        let _v4 = *&p0.fee_growth_inside_0_last_x64;
        let _v5 = *&p0.fee_growth_inside_1_last_x64;
        let _v6 = *&p0.tokens_owed_0;
        let _v7 = *&p0.tokens_owed_1;
        (_v0, _v1, _v2, _v3, _v4, _v5, _v6, _v7)
    }
    public fun extract_position_rewards(p0: &Position): vector<PositionRewardInfo> {
        *&p0.reward_infos
    }
    public fun extract_reward_info(p0: &PositionRewardInfo): (u256, u64) {
        let _v0 = *&p0.reward_growth_inside_last;
        let _v1 = *&p0.amount_owed;
        (_v0, _v1)
    }
    public fun get_all_pools(): vector<object::Object<LiquidityPool>>
        acquires LiquidityPools
    {
        *&borrow_global<LiquidityPools>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).all_pools
    }
    fun get_fee_growth_inside_tick(p0: &table::Table<u32, TickInfo>, p1: u32, p2: u32, p3: u32, p4: u256, p5: u256): (u256, u256) {
        let _v0;
        let _v1;
        let _v2;
        let _v3;
        let _v4;
        let _v5;
        let _v6 = p1;
        let _v7 = p0;
        if (table::contains<u32,TickInfo>(_v7, _v6)) _v4 = table::borrow<u32,TickInfo>(_v7, _v6) else {
            let _v8 = i128::zero();
            let _v9 = TickInfo{liquditiy_gross: 0u128, liquidity_net: _v8, fee_growth_outside_0_x64: 0u256, fee_growth_outside_1_x64: 0u256, reward_growths_outside: vector[], initialized: false};
            _v4 = &_v9
        };
        let _v10 = _v4;
        let _v11 = p2;
        let _v12 = p0;
        if (table::contains<u32,TickInfo>(_v12, _v11)) _v5 = table::borrow<u32,TickInfo>(_v12, _v11) else {
            let _v13 = i128::zero();
            let _v14 = TickInfo{liquditiy_gross: 0u128, liquidity_net: _v13, fee_growth_outside_0_x64: 0u256, fee_growth_outside_1_x64: 0u256, reward_growths_outside: vector[], initialized: false};
            _v5 = &_v14
        };
        let _v15 = _v5;
        if (p3 >= p1) {
            _v0 = *&_v10.fee_growth_outside_0_x64;
            _v1 = *&_v10.fee_growth_outside_1_x64
        } else {
            let _v16 = *&_v10.fee_growth_outside_0_x64;
            _v0 = math::wrapping_sub_u256(p4, _v16);
            let _v17 = *&_v10.fee_growth_outside_1_x64;
            _v1 = math::wrapping_sub_u256(p5, _v17)
        };
        if (p3 < p2) {
            _v3 = *&_v15.fee_growth_outside_0_x64;
            _v2 = *&_v15.fee_growth_outside_1_x64
        } else {
            let _v18 = *&_v15.fee_growth_outside_0_x64;
            _v3 = math::wrapping_sub_u256(p4, _v18);
            let _v19 = *&_v15.fee_growth_outside_1_x64;
            _v2 = math::wrapping_sub_u256(p5, _v19)
        };
        let _v20 = math::wrapping_sub_u256(math::wrapping_sub_u256(p4, _v0), _v3);
        let _v21 = math::wrapping_sub_u256(math::wrapping_sub_u256(p5, _v1), _v2);
        (_v20, _v21)
    }
    fun get_fee_rate(p0: address, p1: &LiquidityPool): u64 {
        let _v0 = *&p1.fee_rate;
        config::get_trader_fee_rate(p0, _v0)
    }
    public fun get_observation_cardinality(p0: object::Object<LiquidityPool>): u16
        acquires PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        *&borrow_global<PoolOracle>(_v0).observation_cardinality
    }
    public fun get_observation_cardinality_next(p0: object::Object<LiquidityPool>): u16
        acquires PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        *&borrow_global<PoolOracle>(_v0).observation_cardinality_next
    }
    public fun get_observation_index(p0: object::Object<LiquidityPool>): u16
        acquires PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        *&borrow_global<PoolOracle>(_v0).observation_index
    }
    public fun get_pool(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>, p2: u64): object::Object<LiquidityPool>
        acquires PoolAccountCap
    {
        object::address_to_object<LiquidityPool>(get_pool_address(p0, p1, p2))
    }
    fun get_pool_account_address(): address
        acquires PoolAccountCap
    {
        account::get_signer_capability_address(&borrow_global<PoolAccountCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap)
    }
    fun get_pool_account_signer(): signer
        acquires PoolAccountCap
    {
        account::create_signer_with_capability(&borrow_global<PoolAccountCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap)
    }
    public fun get_pool_address(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>, p2: u64): address
        acquires PoolAccountCap
    {
        let _v0 = get_pool_account_address();
        let _v1 = &_v0;
        let _v2 = p2;
        let _v3 = p1;
        let _v4 = p0;
        let _v5 = vector[];
        vector::append<u8>(&mut _v5, vector[112u8, 111u8, 111u8, 108u8]);
        let _v6 = &mut _v5;
        let _v7 = object::object_address<fungible_asset::Metadata>(&_v4);
        let _v8 = bcs::to_bytes<address>(&_v7);
        vector::append<u8>(_v6, _v8);
        let _v9 = &mut _v5;
        let _v10 = object::object_address<fungible_asset::Metadata>(&_v3);
        let _v11 = bcs::to_bytes<address>(&_v10);
        vector::append<u8>(_v9, _v11);
        let _v12 = &mut _v5;
        let _v13 = bcs::to_bytes<u64>(&_v2);
        vector::append<u8>(_v12, _v13);
        object::create_object_address(_v1, _v5)
    }
    public fun get_pool_info(p0: object::Object<LiquidityPool>): (object::Object<fungible_asset::Metadata>, object::Object<fungible_asset::Metadata>, u128, u32, u128, u64, u32)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = borrow_global<LiquidityPool>(_v0);
        let _v2 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v1.token_0_reserve);
        let _v3 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v1.token_1_reserve);
        let _v4 = *&_v1.current_sqrt_price;
        let _v5 = *&_v1.current_tick;
        let _v6 = *&_v1.liquidity;
        let _v7 = *&_v1.fee_rate;
        let _v8 = *&_v1.tick_spacing;
        (_v2, _v3, _v4, _v5, _v6, _v7, _v8)
    }
    fun get_pool_reward_infos(p0: &LiquidityPool): vector<u256> {
        let _v0 = timestamp::now_seconds();
        let _v1 = *&p0.reward_last_updated_at_seconds;
        assert!(_v0 >= _v1, 100);
        let _v2 = &p0.reward_infos;
        let _v3 = vector::empty<u256>();
        let _v4 = *&p0.reward_last_updated_at_seconds;
        let _v5 = _v0 - _v4;
        let _v6 = 0;
        let _v7 = false;
        let _v8 = vector::length<PoolRewardInfo>(_v2);
        loop {
            let _v9;
            let _v10;
            let _v11;
            if (_v7) _v6 = _v6 + 1 else _v7 = true;
            if (!(_v6 < _v8)) break;
            let _v12 = vector::borrow<PoolRewardInfo>(_v2, _v6);
            let _v13 = *&_v12.growth_global;
            if (*&p0.liquidity != 0u128) _v9 = _v5 != 0 else _v9 = false;
            if (_v9) _v10 = *&_v12.emissions_per_second != 0 else _v10 = false;
            if (_v10) _v11 = *&_v12.remaining_reward != 0 else _v11 = false;
            if (_v11) {
                let _v14 = *&_v12.emissions_per_second;
                let _v15 = _v5 * _v14;
                let _v16 = *&_v12.remaining_reward;
                let _v17 = fixed_point::u64_to_x64_u256(math64::min(_v15, _v16));
                let _v18 = (*&p0.liquidity) as u256;
                let _v19 = _v17 / _v18;
                _v13 = *&_v12.growth_global + _v19
            };
            vector::push_back<u256>(&mut _v3, _v13);
            continue
        };
        _v3
    }
    friend fun get_pool_signer(p0: object::Object<LiquidityPool>): signer
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        object::generate_signer_for_extending(&borrow_global<LiquidityPool>(_v0).extend_ref)
    }
    public fun get_pool_view(p0: object::Object<LiquidityPool>): LiquidityPoolView
        acquires LiquidityPool
    {
        map_pool_view(&p0)
    }
    public fun get_pool_views(p0: u64, p1: u64): vector<LiquidityPoolView>
        acquires LiquidityPool, LiquidityPools
    {
        let _v0 = &borrow_global<LiquidityPools>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).all_pools;
        let _v1 = vector::empty<LiquidityPoolView>();
        let _v2 = p0;
        let _v3 = false;
        let _v4 = vector::length<object::Object<LiquidityPool>>(_v0);
        let _v5 = p0 + p1;
        let _v6 = math64::min(_v4, _v5);
        loop {
            if (_v3) _v2 = _v2 + 1 else _v3 = true;
            if (!(_v2 < _v6)) break;
            let _v7 = vector::borrow<object::Object<LiquidityPool>>(_v0, _v2);
            let _v8 = &mut _v1;
            let _v9 = map_pool_view(_v7);
            vector::push_back<LiquidityPoolView>(_v8, _v9);
            continue
        };
        _v1
    }
    public fun get_pool_views_by_addresses(p0: vector<address>): vector<LiquidityPoolView>
        acquires LiquidityPool
    {
        let _v0 = vector::empty<LiquidityPoolView>();
        let _v1 = p0;
        vector::reverse<address>(&mut _v1);
        let _v2 = _v1;
        let _v3 = vector::length<address>(&_v2);
        while (_v3 > 0) {
            let _v4 = vector::pop_back<address>(&mut _v2);
            let _v5 = &mut _v0;
            let _v6 = object::address_to_object<LiquidityPool>(_v4);
            let _v7 = map_pool_view(&_v6);
            vector::push_back<LiquidityPoolView>(_v5, _v7);
            _v3 = _v3 - 1;
            continue
        };
        vector::destroy_empty<address>(_v2);
        _v0
    }
    public fun get_position(p0: address, p1: object::Object<LiquidityPool>, p2: u64): Position
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = &borrow_global<LiquidityPool>(_v0).positions;
        let _v2 = get_position_key(&p0, p2);
        let _v3 = table::borrow<vector<u8>,Position>(_v1, _v2);
        let _v4 = *&_v3.id;
        let _v5 = *&_v3.tick_lower;
        let _v6 = *&_v3.tick_upper;
        let _v7 = *&_v3.liquidity;
        let _v8 = *&_v3.fee_growth_inside_0_last_x64;
        let _v9 = *&_v3.fee_growth_inside_1_last_x64;
        let _v10 = *&_v3.tokens_owed_0;
        let _v11 = *&_v3.tokens_owed_1;
        let _v12 = *&_v3.reward_infos;
        Position{id: _v4, tick_lower: _v5, tick_upper: _v6, liquidity: _v7, fee_growth_inside_0_last_x64: _v8, fee_growth_inside_1_last_x64: _v9, tokens_owed_0: _v10, tokens_owed_1: _v11, reward_infos: _v12}
    }
    public fun get_position_info(p0: address, p1: object::Object<LiquidityPool>, p2: u64): (u128, u32, u32, u64, u64)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = get_position_mut(&mut borrow_global_mut<LiquidityPool>(_v0).positions, p0, p2);
        let _v2 = *&_v1.liquidity;
        let _v3 = *&_v1.tick_lower;
        let _v4 = *&_v1.tick_upper;
        let _v5 = *&_v1.tokens_owed_0;
        let _v6 = *&_v1.tokens_owed_1;
        (_v2, _v3, _v4, _v5, _v6)
    }
    fun get_position_key(p0: &address, p1: u64): vector<u8> {
        let _v0 = vector[123u8, 125u8, 45u8, 123u8, 125u8];
        let _v1 = &_v0;
        let _v2 = *p0;
        let _v3 = string_utils::format2<address,u64>(_v1, _v2, p1);
        aptos_hash::keccak256(*string::bytes(&_v3))
    }
    fun get_position_mut(p0: &mut table::Table<vector<u8>, Position>, p1: address, p2: u64): &mut Position {
        let _v0 = get_position_key(&p1, p2);
        assert!(table::contains<vector<u8>,Position>(freeze(p0), _v0), 113);
        table::borrow_mut<vector<u8>,Position>(p0, _v0)
    }
    public fun get_position_token_amounts(p0: object::Object<LiquidityPool>, p1: address, p2: u64): (u64, u64)
        acquires LiquidityPool
    {
        let _v0 = get_position(p1, p0, p2);
        let _v1 = object::object_address<LiquidityPool>(&p0);
        let _v2 = *&borrow_global<LiquidityPool>(_v1).current_sqrt_price;
        let _v3 = tick_math::get_sqrt_price_at_tick(*&(&_v0).tick_lower);
        let _v4 = tick_math::get_sqrt_price_at_tick(*&(&_v0).tick_upper);
        let _v5 = *&(&_v0).liquidity;
        let (_v6,_v7) = liquidity_math::get_amounts_for_liquidity(_v2, _v3, _v4, _v5);
        (_v6, _v7)
    }
    public fun get_position_with_pending_fees_and_rewards(p0: address, p1: object::Object<LiquidityPool>, p2: u64): Position
        acquires LiquidityPool
    {
        let _v0 = get_position(p0, p1, p2);
        let _v1 = object::object_address<LiquidityPool>(&p1);
        let _v2 = borrow_global<LiquidityPool>(_v1);
        let _v3 = *&(&_v0).id;
        let _v4 = *&(&_v0).liquidity;
        let _v5 = *&(&_v0).tick_lower;
        let _v6 = *&(&_v0).tick_upper;
        let _v7 = *&(&_v0).fee_growth_inside_0_last_x64;
        let _v8 = *&(&_v0).fee_growth_inside_1_last_x64;
        let _v9 = *&(&_v0).tokens_owed_0;
        let _v10 = *&(&_v0).tokens_owed_1;
        let _v11 = *&(&_v0).reward_infos;
        let _v12 = Position{id: _v3, tick_lower: _v5, tick_upper: _v6, liquidity: _v4, fee_growth_inside_0_last_x64: _v7, fee_growth_inside_1_last_x64: _v8, tokens_owed_0: _v9, tokens_owed_1: _v10, reward_infos: _v11};
        if (*&(&_v0).liquidity == 0u128) return _v12;
        let _v13 = &_v2.ticks;
        let _v14 = *&(&_v0).tick_lower;
        let _v15 = *&(&_v0).tick_upper;
        let _v16 = *&_v2.current_tick;
        let _v17 = *&_v2.fee_growth_global_0_x64;
        let _v18 = *&_v2.fee_growth_global_1_x64;
        let (_v19,_v20) = get_fee_growth_inside_tick(_v13, _v14, _v15, _v16, _v17, _v18);
        update_position_fee(&mut _v12, _v19, _v20);
        let _v21 = get_pool_reward_infos(_v2);
        let _v22 = &_v2.ticks;
        let _v23 = *&(&_v0).tick_lower;
        let _v24 = *&(&_v0).tick_upper;
        let _v25 = *&_v2.current_tick;
        let _v26 = &_v21;
        let _v27 = get_reward_growths_inside(_v22, _v23, _v24, _v25, _v26);
        let _v28 = &mut _v12;
        let _v29 = &_v27;
        update_position_rewards(_v28, _v29);
        _v12
    }
    public fun get_quote_at_tick(p0: u32, p1: u64, p2: object::Object<fungible_asset::Metadata>, p3: object::Object<fungible_asset::Metadata>): u128 {
        let _v0;
        let _v1 = tick_math::get_sqrt_price_at_tick(p0);
        if (_v1 <= 79228162514264337593543950335u128) {
            let _v2;
            let _v3 = _v1 as u256;
            let _v4 = _v1 as u256;
            let _v5 = _v3 * _v4;
            if (fa_helper::is_sorted(p2, p3)) {
                let _v6 = p1 as u256;
                _v2 = math::mul_div_u256(_v5, _v6, 1461501637330902918203684832716283019655932542976u256)
            } else {
                let _v7 = p1 as u256;
                _v2 = math::mul_div_u256(1461501637330902918203684832716283019655932542976u256, _v7, _v5)
            };
            _v0 = _v2 as u128
        } else {
            let _v8;
            let _v9 = _v1 as u256;
            let _v10 = _v1 as u256;
            let _v11 = math::mul_div_u256(_v9, _v10, 18446744073709551616u256);
            if (fa_helper::is_sorted(p2, p3)) {
                let _v12 = p1 as u256;
                _v8 = math::mul_div_u256(_v11, _v12, 79228162514264337593543950336u256)
            } else {
                let _v13 = p1 as u256;
                _v8 = math::mul_div_u256(79228162514264337593543950336u256, _v13, _v11)
            };
            _v0 = _v8 as u128
        };
        _v0
    }
    public fun get_reserves_size(p0: object::Object<LiquidityPool>): (u64, u64)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = fungible_asset::balance<fungible_asset::FungibleStore>(*&_v1.token_0_reserve);
        let _v3 = fungible_asset::balance<fungible_asset::FungibleStore>(*&_v1.token_1_reserve);
        (_v2, _v3)
    }
    fun get_reward_growths_inside(p0: &table::Table<u32, TickInfo>, p1: u32, p2: u32, p3: u32, p4: &vector<u256>): vector<u256> {
        let _v0;
        let _v1;
        let _v2 = table::borrow<u32,TickInfo>(p0, p1);
        let _v3 = table::borrow<u32,TickInfo>(p0, p2);
        if (p3 >= p1) _v0 = *&_v2.reward_growths_outside else {
            let _v4 = &_v2.reward_growths_outside;
            _v0 = sub_reward_growths(p4, _v4)
        };
        let _v5 = _v0;
        if (p3 < p2) _v1 = *&_v3.reward_growths_outside else {
            let _v6 = &_v3.reward_growths_outside;
            _v1 = sub_reward_growths(p4, _v6)
        };
        let _v7 = _v1;
        let _v8 = &_v5;
        let _v9 = sub_reward_growths(p4, _v8);
        let _v10 = &_v9;
        let _v11 = &_v7;
        sub_reward_growths(_v10, _v11)
    }
    public fun get_swap_receipt_amount(p0: &SwapReciept): u64 {
        *&p0.amount_in
    }
    public fun get_swap_receipt_token_metadata(p0: &SwapReciept): object::Object<fungible_asset::Metadata> {
        *&p0.token_metadata
    }
    public fun get_ticks(p0: object::Object<LiquidityPool>, p1: u32, p2: u32): vector<TickView>
        acquires LiquidityPool
    {
        let _v0;
        let _v1;
        let _v2 = object::object_address<LiquidityPool>(&p0);
        let _v3 = borrow_global<LiquidityPool>(_v2);
        let _v4 = 0u32;
        let _v5 = vector::empty<TickView>();
        let _v6 = tick::max_tick();
        let _v7 = *&_v3.tick_spacing;
        let _v8 = (_v6 / _v7 >> 8u8) as u16;
        let _v9 = *&_v3.tick_spacing;
        let _v10 = tick::tick_adjustment(_v9);
        if (p1 >= _v10) _v1 = p1 - _v10 else _v1 = 0u32;
        let _v11 = _v1 as u64;
        let _v12 = _v9 as u64;
        let _v13 = _v11;
        if (_v13 == 0) if (_v12 != 0) _v0 = 0 else {
            let _v14 = error::invalid_argument(4);
            abort _v14
        } else _v0 = (_v13 - 1) / _v12 + 1;
        let _v15 = _v0 as u32;
        let _v16 = (_v15 >> 8u8) as u16;
        let _v17 = _v15 % 256u32;
        loop {
            let _v18;
            if (_v16 <= _v8) _v18 = _v4 < p2 else _v18 = false;
            if (!_v18) break;
            let _v19 = &_v3.tick_bitmap;
            let _v20 = 0u256;
            let _v21 = &_v20;
            let _v22 = *table::borrow_with_default<u16,u256>(_v19, _v16, _v21);
            if (_v22 == 0u256) {
                _v16 = _v16 + 1u16;
                continue
            };
            let _v23 = _v17;
            while (_v23 < 256u32) {
                let _v24 = _v23 as u8;
                if (1u256 << _v24 & _v22 != 0u256) {
                    let _v25 = ((_v16 as u32) << 8u8) + _v23;
                    let _v26 = *&_v3.tick_spacing;
                    let _v27 = _v25 * _v26 + _v10;
                    let _v28 = table::borrow<u32,TickInfo>(&_v3.ticks, _v27);
                    let _v29 = &mut _v5;
                    let _v30 = *&_v28.liquditiy_gross;
                    let _v31 = *&_v28.liquidity_net;
                    let _v32 = *&_v28.fee_growth_outside_0_x64;
                    let _v33 = *&_v28.fee_growth_outside_1_x64;
                    let _v34 = *&_v28.reward_growths_outside;
                    let _v35 = TickView{tick: _v27, liquidity_gross: _v30, liquidity_net: _v31, fee_growth_outside_0_x64: _v32, fee_growth_outside_1_x64: _v33, reward_growths_outside: _v34};
                    vector::push_back<TickView>(_v29, _v35);
                    _v4 = _v4 + 1u32;
                    if (_v4 >= p2) break
                };
                _v23 = _v23 + 1u32;
                continue
            };
            _v17 = 0u32;
            _v16 = _v16 + 1u16;
            continue
        };
        _v5
    }
    public fun get_tokens(p0: object::Object<LiquidityPool>): (object::Object<fungible_asset::Metadata>, object::Object<fungible_asset::Metadata>)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&borrow_global<LiquidityPool>(_v0).token_0_reserve);
        let _v2 = object::object_address<LiquidityPool>(&p0);
        let _v3 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&borrow_global<LiquidityPool>(_v2).token_1_reserve);
        (_v1, _v3)
    }
    public entry fun increase_observation_cardinality_next(p0: object::Object<LiquidityPool>, p1: u16)
        acquires LiquidityPool, PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = freeze(borrow_global_mut<LiquidityPool>(_v0));
        create_oracle_if_not_exists(_v1);
        let _v2 = object::address_from_extend_ref(&_v1.extend_ref);
        let _v3 = borrow_global_mut<PoolOracle>(_v2);
        let _v4 = *&_v3.observation_cardinality_next;
        let _v5 = oracle::grow(&mut _v3.observations, _v4, p1);
        let _v6 = &mut _v3.observation_cardinality_next;
        *_v6 = _v5;
        if (_v5 != _v4) event::emit<IncreaseObservationCardinalityNextEvent>(IncreaseObservationCardinalityNextEvent{pool: object::object_address<LiquidityPool>(&p0), observation_cardinality_next_old: _v4, observation_cardinality_next_new: _v5});
    }
    fun init_module(p0: &signer) {
        let (_v0,_v1) = account::create_resource_account(p0, vector[112u8, 111u8, 111u8, 108u8, 95u8, 97u8, 99u8, 99u8, 111u8, 117u8, 110u8, 116u8]);
        let _v2 = PoolAccountCap{signer_cap: _v1};
        move_to<PoolAccountCap>(p0, _v2);
        let _v3 = LiquidityPools{all_pools: vector::empty<object::Object<LiquidityPool>>()};
        move_to<LiquidityPools>(p0, _v3);
    }
    friend fun initialize_reward(p0: &signer, p1: object::Object<LiquidityPool>, p2: object::Object<fungible_asset::Metadata>, p3: address)
        acquires LiquidityPool
    {
        config::assert_reward_admin(p0);
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        assert!(vector::length<PoolRewardInfo>(&_v1.reward_infos) < 3, 117);
        let _v2 = PoolRewardInfo{token_metadata: p2, remaining_reward: 0, emissions_per_second: 0, growth_global: 0u256, manager: p3};
        vector::push_back<PoolRewardInfo>(&mut _v1.reward_infos, _v2);
        let _v3 = object::object_address<LiquidityPool>(&p1);
        let _v4 = vector::length<PoolRewardInfo>(&_v1.reward_infos) - 1;
        event::emit<InitRewardEvent>(InitRewardEvent{pool: _v3, reward_index: _v4, manager: p3});
    }
    public fun is_pool_exists(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>, p2: u64): bool
        acquires PoolAccountCap
    {
        object::object_exists<LiquidityPool>(get_pool_address(p0, p1, p2))
    }
    fun map_pool_view(p0: &object::Object<LiquidityPool>): LiquidityPoolView
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(p0);
        let _v1 = borrow_global<LiquidityPool>(_v0);
        let _v2 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v1.token_0_reserve);
        let _v3 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v1.token_1_reserve);
        let _v4 = object::object_address<LiquidityPool>(p0);
        let _v5 = object::object_address<fungible_asset::Metadata>(&_v2);
        let _v6 = object::object_address<fungible_asset::Metadata>(&_v3);
        let _v7 = fungible_asset::decimals<fungible_asset::Metadata>(_v2);
        let _v8 = fungible_asset::decimals<fungible_asset::Metadata>(_v3);
        let _v9 = fungible_asset::balance<fungible_asset::FungibleStore>(*&_v1.token_0_reserve);
        let _v10 = fungible_asset::balance<fungible_asset::FungibleStore>(*&_v1.token_1_reserve);
        let _v11 = *&_v1.current_tick;
        let _v12 = *&_v1.current_sqrt_price;
        let _v13 = *&_v1.liquidity;
        let _v14 = *&_v1.fee_growth_global_0_x64;
        let _v15 = *&_v1.fee_growth_global_1_x64;
        let _v16 = *&_v1.reward_infos;
        let _v17 = *&_v1.fee_rate;
        let _v18 = *&_v1.tick_spacing;
        LiquidityPoolView{pool_addr: _v4, token_0: _v5, token_1: _v6, token_0_decimals: _v7, token_1_decimals: _v8, token_0_reserve: _v9, token_1_reserve: _v10, current_tick: _v11, current_sqrt_price: _v12, liquidity: _v13, fee_growth_global_0_x64: _v14, fee_growth_global_1_x64: _v15, reward_infos: _v16, fee_rate: _v17, tick_spacing: _v18}
    }
    fun modify_position(p0: &mut LiquidityPool, p1: &mut PoolOracle, p2: address, p3: u64, p4: i128::I128): (u64, u64) {
        let _v0;
        let _v1;
        let _v2 = i128::is_zero(&p4);
        loop {
            if (!_v2) {
                let _v3 = update_position(p0, p2, p3, p4);
                let _v4 = *&_v3.tick_lower;
                let _v5 = *&_v3.tick_upper;
                let _v6 = _v4;
                _v0 = 0;
                _v1 = 0;
                if (*&p0.current_tick < _v6) {
                    let _v7 = tick_math::get_sqrt_price_at_tick(_v6);
                    let _v8 = tick_math::get_sqrt_price_at_tick(_v5);
                    let _v9 = i128::abs(&p4);
                    let _v10 = i128::is_positive(&p4);
                    _v0 = sqrt_price_math::get_amount_0_delta(_v7, _v8, _v9, _v10);
                    break
                };
                if (*&p0.current_tick < _v5) {
                    let _v11 = &mut p1.observations;
                    let _v12 = *&p1.observation_index;
                    let _v13 = timestamp::now_seconds();
                    let _v14 = *&p0.current_tick;
                    let _v15 = *&p0.liquidity;
                    let _v16 = *&p1.observation_cardinality;
                    let _v17 = *&p1.observation_cardinality_next;
                    let (_v18,_v19) = oracle::write(_v11, _v12, _v13, _v14, _v15, _v16, _v17);
                    let _v20 = &mut p1.observation_index;
                    *_v20 = _v18;
                    let _v21 = &mut p1.observation_cardinality;
                    *_v21 = _v19;
                    let _v22 = *&p0.current_sqrt_price;
                    let _v23 = tick_math::get_sqrt_price_at_tick(_v5);
                    let _v24 = i128::abs(&p4);
                    let _v25 = i128::is_positive(&p4);
                    _v0 = sqrt_price_math::get_amount_0_delta(_v22, _v23, _v24, _v25);
                    let _v26 = tick_math::get_sqrt_price_at_tick(_v6);
                    let _v27 = *&p0.current_sqrt_price;
                    let _v28 = i128::abs(&p4);
                    let _v29 = i128::is_positive(&p4);
                    _v1 = sqrt_price_math::get_amount_1_delta(_v26, _v27, _v28, _v29);
                    let _v30 = *&p0.liquidity;
                    let _v31 = &p4;
                    let _v32 = add_delta_liquidity(_v30, _v31);
                    let _v33 = &mut p0.liquidity;
                    *_v33 = _v32;
                    break
                };
                let _v34 = tick_math::get_sqrt_price_at_tick(_v6);
                let _v35 = tick_math::get_sqrt_price_at_tick(_v5);
                let _v36 = i128::abs(&p4);
                let _v37 = i128::is_positive(&p4);
                _v1 = sqrt_price_math::get_amount_1_delta(_v34, _v35, _v36, _v37);
                break
            };
            return (0, 0)
        };
        (_v0, _v1)
    }
    public fun observe(p0: object::Object<LiquidityPool>, p1: vector<u64>): (vector<i64::I64>, vector<u256>)
        acquires LiquidityPool, PoolOracle
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        let _v1 = borrow_global<LiquidityPool>(_v0);
        let _v2 = object::object_address<LiquidityPool>(&p0);
        let _v3 = borrow_global<PoolOracle>(_v2);
        let _v4 = &_v3.observations;
        let _v5 = timestamp::now_seconds();
        let _v6 = *&_v1.current_tick;
        let _v7 = *&_v3.observation_index;
        let _v8 = *&_v1.liquidity;
        let _v9 = *&_v3.observation_cardinality;
        let (_v10,_v11) = oracle::observe(_v4, _v5, p1, _v6, _v7, _v8, _v9);
        (_v10, _v11)
    }
    public fun open_position(p0: &signer, p1: object::Object<LiquidityPool>, p2: u32, p3: u32): u64
        acquires LiquidityPool
    {
        emergency::assert_no_emergency();
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        assert!(*&_v1.unlocked, 102);
        let _v2 = *&_v1.tick_spacing;
        assert_ticks(p2, p3, _v2);
        let _v3 = *&_v1.next_position_id;
        let _v4 = signer::address_of(p0);
        let _v5 = get_position_key(&_v4, _v3);
        let _v6 = vector::empty<PositionRewardInfo>();
        let _v7 = Position{id: _v3, tick_lower: p2, tick_upper: p3, liquidity: 0u128, fee_growth_inside_0_last_x64: 0u256, fee_growth_inside_1_last_x64: 0u256, tokens_owed_0: 0, tokens_owed_1: 0, reward_infos: _v6};
        table::add<vector<u8>,Position>(&mut _v1.positions, _v5, _v7);
        let _v8 = *&_v1.next_position_id + 1;
        let _v9 = &mut _v1.next_position_id;
        *_v9 = _v8;
        _v3
    }
    public fun pay_swap(p0: fungible_asset::FungibleAsset, p1: SwapReciept)
        acquires LiquidityPool
    {
        let SwapReciept{pool: _v0, token_metadata: _v1, amount_in: _v2, protocol_fee_amount: _v3} = p1;
        let _v4 = _v3;
        let _v5 = _v1;
        let _v6 = _v0;
        let _v7 = fungible_asset::metadata_from_asset(&p0);
        assert!(_v5 == _v7, 111);
        assert!(fungible_asset::amount(&p0) == _v2, 112);
        let _v8 = object::object_address<LiquidityPool>(&_v6);
        let _v9 = borrow_global_mut<LiquidityPool>(_v8);
        if (_v4 > 0) {
            let _v10 = config::treasury();
            let _v11 = fungible_asset::extract(&mut p0, _v4);
            primary_fungible_store::deposit(_v10, _v11)
        };
        let _v12 = fungible_asset::store_metadata<fungible_asset::FungibleStore>(*&_v9.token_0_reserve);
        if (_v5 == _v12) dispatchable_fungible_asset::deposit<fungible_asset::FungibleStore>(*&_v9.token_0_reserve, p0) else dispatchable_fungible_asset::deposit<fungible_asset::FungibleStore>(*&_v9.token_1_reserve, p0);
        let _v13 = &mut _v9.unlocked;
        *_v13 = true;
    }
    public fun quote_swap(p0: address, p1: object::Object<LiquidityPool>, p2: bool, p3: bool, p4: u64, p5: u128): (u64, u64, u64)
        acquires LiquidityPool
    {
        let _v0;
        let _v1;
        assert!(p4 > 0, 109);
        let _v2 = object::object_address<LiquidityPool>(&p1);
        let _v3 = borrow_global<LiquidityPool>(_v2);
        loop {
            let _v4;
            if (p2) {
                let _v5;
                let _v6 = *&_v3.current_sqrt_price;
                if (p5 < _v6) {
                    let _v7 = tick_math::min_sqrt_price();
                    _v5 = p5 >= _v7
                } else _v5 = false;
                if (_v5) break;
                abort 110
            };
            let _v8 = *&_v3.current_sqrt_price;
            if (p5 > _v8) {
                let _v9 = tick_math::max_sqrt_price();
                _v4 = p5 <= _v9
            } else _v4 = false;
            if (_v4) break;
            abort 110
        };
        let _v10 = *&_v3.tick_spacing;
        let _v11 = *&_v3.current_sqrt_price;
        let _v12 = *&_v3.current_tick;
        let _v13 = *&_v3.liquidity;
        let _v14 = p4;
        let _v15 = 0;
        let _v16 = 0;
        let _v17 = get_fee_rate(p0, _v3);
        loop {
            let _v18;
            let _v19;
            if (_v14 > 0) _v18 = _v11 != p5 else _v18 = false;
            if (!_v18) break;
            let _v20 = _v11;
            let (_v21,_v22) = tick_bitmap::get_next_initialized_tick_within_one_word(&_v3.tick_bitmap, _v12, _v10, p2);
            let _v23 = _v21;
            let _v24 = tick::min_tick();
            if (_v23 < _v24) _v23 = tick::min_tick() else {
                let _v25 = tick::max_tick();
                if (_v23 > _v25) _v23 = tick::max_tick()
            };
            let _v26 = tick_math::get_sqrt_price_at_tick(_v23);
            if (p2) _v19 = math128::max(p5, _v26) else _v19 = math128::min(p5, _v26);
            let (_v27,_v28,_v29,_v30) = swap_math::compute_swap_step(_v11, _v19, _v13, _v14, p3, _v17);
            let _v31 = _v30;
            let _v32 = _v29;
            let _v33 = _v28;
            let _v34 = _v27;
            _v11 = _v34;
            if (p3) {
                let _v35 = _v33 + _v31;
                _v14 = _v14 - _v35;
                _v15 = _v15 + _v32
            } else {
                _v14 = _v14 - _v32;
                let _v36 = _v33 + _v31;
                _v15 = _v15 + _v36
            };
            _v16 = _v16 + _v31;
            if (_v34 == _v26) {
                let _v37;
                let _v38;
                if (_v22) {
                    let _v39 = *&table::borrow<u32,TickInfo>(&_v3.ticks, _v23).liquidity_net;
                    if (p2) _v39 = i128::new(i128::abs(&_v39), !i128::is_negative(&_v39));
                    let _v40 = &_v39;
                    _v13 = add_delta_liquidity(_v13, _v40)
                };
                if (p2) {
                    let _v41 = tick::min_tick();
                    _v38 = _v23 > _v41
                } else _v38 = false;
                if (_v38) _v37 = _v23 - 1u32 else _v37 = _v23;
                _v12 = _v37;
                continue
            };
            if (!(_v11 != _v20)) continue;
            _v12 = tick_math::get_tick_at_sqrt_price(_v34);
            continue
        };
        if (p3) {
            let _v42 = p4 - _v14;
            _v1 = _v15;
            _v0 = _v42
        } else {
            _v1 = p4 - _v14;
            _v0 = _v15
        };
        (_v0, _v1, _v16)
    }
    public fun remove_liquidity(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u128): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset)
        acquires LiquidityPool, PoolAccountCap, PoolOracle
    {
        emergency::assert_no_emergency();
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        assert!(*&_v1.unlocked, 102);
        let _v2 = freeze(_v1);
        create_oracle_if_not_exists(_v2);
        let _v3 = object::address_from_extend_ref(&_v2.extend_ref);
        let _v4 = borrow_global_mut<PoolOracle>(_v3);
        let _v5 = signer::address_of(p0);
        let _v6 = i128::new(p3, true);
        let (_v7,_v8) = modify_position(_v1, _v4, _v5, p2, _v6);
        let _v9 = _v8;
        let _v10 = _v7;
        let _v11 = object::object_address<LiquidityPool>(&p1);
        event::emit<RemoveLiquidityEvent>(RemoveLiquidityEvent{user: _v5, pool: _v11, position_id: p2, liquidity: p3, amount_0: _v10, amount_1: _v9});
        let _v12 = get_pool_account_signer();
        let _v13 = &_v12;
        let _v14 = *&_v1.token_0_reserve;
        let _v15 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v13, _v14, _v10);
        let _v16 = &_v12;
        let _v17 = *&_v1.token_1_reserve;
        let _v18 = dispatchable_fungible_asset::withdraw<fungible_asset::FungibleStore>(_v16, _v17, _v9);
        (_v15, _v18)
    }
    public fun remove_reward(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u64): fungible_asset::FungibleAsset
        acquires LiquidityPool, PoolAccountCap
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = *&vector::borrow<PoolRewardInfo>(&_v1.reward_infos, p2).manager;
        let _v3 = signer::address_of(p0);
        assert!(_v2 == _v3, 118);
        let _v4 = update_pool_reward_infos(_v1);
        let _v5 = vector::borrow_mut<PoolRewardInfo>(&mut _v1.reward_infos, p2);
        let _v6 = math64::min(*&_v5.remaining_reward, p3);
        let _v7 = get_pool_account_signer();
        let _v8 = &_v7;
        let _v9 = *&_v5.token_metadata;
        let _v10 = primary_fungible_store::withdraw<fungible_asset::Metadata>(_v8, _v9, _v6);
        let _v11 = *&_v5.remaining_reward - _v6;
        let _v12 = &mut _v5.remaining_reward;
        *_v12 = _v11;
        let _v13 = object::object_address<LiquidityPool>(&p1);
        let _v14 = *&_v5.manager;
        event::emit<RemoveRewardEvent>(RemoveRewardEvent{pool: _v13, reward_index: p2, manager: _v14, amount: _v6});
        _v10
    }
    public fun rewards_count(p0: object::Object<LiquidityPool>): u64
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p0);
        vector::length<PoolRewardInfo>(&borrow_global<LiquidityPool>(_v0).reward_infos)
    }
    fun sub_reward_growths(p0: &vector<u256>, p1: &vector<u256>): vector<u256> {
        let _v0 = vector[];
        let _v1 = vector::length<u256>(p1);
        let _v2 = 0;
        let _v3 = false;
        let _v4 = vector::length<u256>(p0);
        loop {
            let _v5;
            if (_v3) _v2 = _v2 + 1 else _v3 = true;
            if (!(_v2 < _v4)) break;
            if (_v2 >= _v1) _v5 = 0u256 else _v5 = *vector::borrow<u256>(p1, _v2);
            let _v6 = &mut _v0;
            let _v7 = math::wrapping_sub_u256(*vector::borrow<u256>(p0, _v2), _v5);
            vector::push_back<u256>(_v6, _v7);
            continue
        };
        _v0
    }
    fun tick_bitmap_position(p0: u32): (u16, u8) {
        let _v0 = (p0 >> 8u8) as u16;
        let _v1 = (p0 % 256u32) as u8;
        (_v0, _v1)
    }
    fun try_borrow_mut_reward_info(p0: &mut Position, p1: u64): &mut PositionRewardInfo {
        let _v0 = vector::length<PositionRewardInfo>(&p0.reward_infos);
        if (p1 >= _v0) {
            let _v1 = &mut p0.reward_infos;
            let _v2 = PositionRewardInfo{reward_growth_inside_last: 0u256, amount_owed: 0};
            vector::push_back<PositionRewardInfo>(_v1, _v2)
        };
        vector::borrow_mut<PositionRewardInfo>(&mut p0.reward_infos, p1)
    }
    public entry fun update_params(p0: &signer, p1: object::Object<LiquidityPool>, p2: address) {
        abort 0
    }
    fun update_pool_reward_infos(p0: &mut LiquidityPool): vector<u256> {
        let _v0 = timestamp::now_seconds();
        let _v1 = *&p0.reward_last_updated_at_seconds;
        assert!(_v0 >= _v1, 100);
        let _v2 = &mut p0.reward_infos;
        let _v3 = vector::empty<u256>();
        let _v4 = *&p0.reward_last_updated_at_seconds;
        let _v5 = _v0 - _v4;
        let _v6 = 0;
        let _v7 = false;
        let _v8 = vector::length<PoolRewardInfo>(freeze(_v2));
        loop {
            let _v9;
            let _v10;
            let _v11;
            if (_v7) _v6 = _v6 + 1 else _v7 = true;
            if (!(_v6 < _v8)) break;
            let _v12 = vector::borrow_mut<PoolRewardInfo>(_v2, _v6);
            if (*&p0.liquidity != 0u128) _v9 = _v5 != 0 else _v9 = false;
            if (_v9) _v10 = *&_v12.emissions_per_second != 0 else _v10 = false;
            if (_v10) _v11 = *&_v12.remaining_reward != 0 else _v11 = false;
            if (_v11) {
                let _v13 = *&_v12.emissions_per_second;
                let _v14 = _v5 * _v13;
                let _v15 = *&_v12.remaining_reward;
                let _v16 = math64::min(_v14, _v15);
                let _v17 = *&_v12.remaining_reward - _v16;
                let _v18 = &mut _v12.remaining_reward;
                *_v18 = _v17;
                let _v19 = fixed_point::u64_to_x64_u256(_v16);
                let _v20 = (*&p0.liquidity) as u256;
                let _v21 = _v19 / _v20;
                let _v22 = *&_v12.growth_global + _v21;
                let _v23 = &mut _v12.growth_global;
                *_v23 = _v22
            };
            let _v24 = &mut _v3;
            let _v25 = *&_v12.growth_global;
            vector::push_back<u256>(_v24, _v25);
            continue
        };
        let _v26 = &mut p0.reward_last_updated_at_seconds;
        *_v26 = _v0;
        _v3
    }
    fun update_position(p0: &mut LiquidityPool, p1: address, p2: u64, p3: i128::I128): &Position {
        let _v0 = update_pool_reward_infos(p0);
        let _v1 = get_position_mut(&mut p0.positions, p1, p2);
        let _v2 = false;
        let _v3 = false;
        if (!i128::is_zero(&p3)) {
            let _v4 = &mut p0.ticks;
            let _v5 = *&_v1.tick_lower;
            let _v6 = *&p0.current_tick;
            let _v7 = *&p0.fee_growth_global_0_x64;
            let _v8 = *&p0.fee_growth_global_1_x64;
            let _v9 = *&p0.max_liquidity_per_tick;
            _v2 = update_tick(_v4, _v5, _v6, p3, _v7, _v8, _v0, false, _v9);
            let _v10 = &mut p0.ticks;
            let _v11 = *&_v1.tick_upper;
            let _v12 = *&p0.current_tick;
            let _v13 = *&p0.fee_growth_global_0_x64;
            let _v14 = *&p0.fee_growth_global_1_x64;
            let _v15 = *&p0.max_liquidity_per_tick;
            _v3 = update_tick(_v10, _v11, _v12, p3, _v13, _v14, _v0, true, _v15);
            if (_v2) {
                let _v16 = &mut p0.tick_bitmap;
                let _v17 = *&_v1.tick_lower;
                let _v18 = *&p0.tick_spacing;
                tick_bitmap::flip_tick(_v16, _v17, _v18)
            };
            if (_v3) {
                let _v19 = &mut p0.tick_bitmap;
                let _v20 = *&_v1.tick_upper;
                let _v21 = *&p0.tick_spacing;
                tick_bitmap::flip_tick(_v19, _v20, _v21)
            }
        };
        let _v22 = &p0.ticks;
        let _v23 = *&_v1.tick_lower;
        let _v24 = *&_v1.tick_upper;
        let _v25 = *&p0.current_tick;
        let _v26 = *&p0.fee_growth_global_0_x64;
        let _v27 = *&p0.fee_growth_global_1_x64;
        let (_v28,_v29) = get_fee_growth_inside_tick(_v22, _v23, _v24, _v25, _v26, _v27);
        let _v30 = &p0.ticks;
        let _v31 = *&_v1.tick_lower;
        let _v32 = *&_v1.tick_upper;
        let _v33 = *&p0.current_tick;
        let _v34 = &_v0;
        let _v35 = get_reward_growths_inside(_v30, _v31, _v32, _v33, _v34);
        update_position_fee(_v1, _v28, _v29);
        let _v36 = &_v35;
        update_position_rewards(_v1, _v36);
        let _v37 = &p3;
        let _v38 = i128::new(*&_v1.liquidity, false);
        let _v39 = &_v38;
        let _v40 = i128::add(_v37, _v39);
        let _v41 = i128::as_u128(&_v40);
        let _v42 = &mut _v1.liquidity;
        *_v42 = _v41;
        if (i128::is_negative(&p3)) {
            if (_v2) {
                let _v43 = &mut p0.ticks;
                let _v44 = *&_v1.tick_lower;
                clear_tick(_v43, _v44)
            };
            if (_v3) {
                let _v45 = &mut p0.ticks;
                let _v46 = *&_v1.tick_upper;
                clear_tick(_v45, _v46)
            }
        };
        freeze(_v1)
    }
    fun update_position_fee(p0: &mut Position, p1: u256, p2: u256) {
        let _v0 = *&p0.fee_growth_inside_0_last_x64;
        let _v1 = math::wrapping_sub_u256(p1, _v0);
        let _v2 = (*&p0.liquidity) as u256;
        let _v3 = fixed_point::q64() as u256;
        let _v4 = math::mul_div_u256(_v1, _v2, _v3);
        let _v5 = *&p0.fee_growth_inside_1_last_x64;
        let _v6 = math::wrapping_sub_u256(p2, _v5);
        let _v7 = (*&p0.liquidity) as u256;
        let _v8 = fixed_point::q64() as u256;
        let _v9 = math::mul_div_u256(_v6, _v7, _v8);
        let _v10 = &mut p0.fee_growth_inside_0_last_x64;
        *_v10 = p1;
        let _v11 = &mut p0.fee_growth_inside_1_last_x64;
        *_v11 = p2;
        let _v12 = *&p0.tokens_owed_0;
        let _v13 = _v4 as u64;
        let _v14 = _v12 + _v13;
        let _v15 = &mut p0.tokens_owed_0;
        *_v15 = _v14;
        let _v16 = *&p0.tokens_owed_1;
        let _v17 = _v9 as u64;
        let _v18 = _v16 + _v17;
        let _v19 = &mut p0.tokens_owed_1;
        *_v19 = _v18;
    }
    fun update_position_rewards(p0: &mut Position, p1: &vector<u256>) {
        let _v0 = 0;
        let _v1 = false;
        let _v2 = vector::length<u256>(p1);
        loop {
            if (_v1) _v0 = _v0 + 1 else _v1 = true;
            if (!(_v0 < _v2)) break;
            let _v3 = *&p0.liquidity;
            let _v4 = *vector::borrow<u256>(p1, _v0);
            let _v5 = try_borrow_mut_reward_info(p0, _v0);
            let _v6 = *&_v5.reward_growth_inside_last;
            let _v7 = math::wrapping_sub_u256(_v4, _v6);
            let _v8 = _v3 as u256;
            let _v9 = fixed_point::q64() as u256;
            let _v10 = math::mul_div_u256(_v7, _v8, _v9);
            let _v11 = &mut _v5.reward_growth_inside_last;
            *_v11 = _v4;
            let _v12 = *&_v5.amount_owed;
            let _v13 = _v10 as u64;
            let _v14 = _v12 + _v13;
            let _v15 = &mut _v5.amount_owed;
            *_v15 = _v14;
            continue
        };
    }
    public fun update_reward_emissions(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: u64)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = *&vector::borrow<PoolRewardInfo>(&_v1.reward_infos, p2).manager;
        let _v3 = signer::address_of(p0);
        assert!(_v2 == _v3, 118);
        let _v4 = update_pool_reward_infos(_v1);
        let _v5 = vector::borrow_mut<PoolRewardInfo>(&mut _v1.reward_infos, p2);
        let _v6 = &mut _v5.emissions_per_second;
        *_v6 = p3;
        let _v7 = object::object_address<LiquidityPool>(&p1);
        let _v8 = *&_v5.manager;
        event::emit<UpdateRewardEmissionsEvent>(UpdateRewardEmissionsEvent{pool: _v7, reward_index: p2, manager: _v8, emissions_per_second: p3});
    }
    fun update_reward_growths(p0: &mut vector<u256>, p1: &vector<u256>) {
        let _v0 = vector::length<u256>(freeze(p0));
        let _v1 = 0;
        let _v2 = false;
        let _v3 = vector::length<u256>(p1);
        loop {
            if (_v2) _v1 = _v1 + 1 else _v2 = true;
            if (!(_v1 < _v3)) break;
            if (_v1 >= _v0) {
                let _v4 = *vector::borrow<u256>(p1, _v1);
                vector::push_back<u256>(p0, _v4);
                continue
            };
            let _v5 = vector::borrow_mut<u256>(p0, _v1);
            let _v6 = *vector::borrow<u256>(p1, _v1);
            let _v7 = *_v5;
            *_v5 = math::wrapping_sub_u256(_v6, _v7);
            continue
        };
    }
    public fun update_reward_manager(p0: &signer, p1: object::Object<LiquidityPool>, p2: u64, p3: address)
        acquires LiquidityPool
    {
        let _v0 = object::object_address<LiquidityPool>(&p1);
        let _v1 = borrow_global_mut<LiquidityPool>(_v0);
        let _v2 = *&vector::borrow<PoolRewardInfo>(&_v1.reward_infos, p2).manager;
        let _v3 = signer::address_of(p0);
        assert!(_v2 == _v3, 118);
        let _v4 = &mut vector::borrow_mut<PoolRewardInfo>(&mut _v1.reward_infos, p2).manager;
        *_v4 = p3;
        event::emit<UpdateRewardManagerEvent>(UpdateRewardManagerEvent{pool: object::object_address<LiquidityPool>(&p1), reward_index: p2, manager: p3});
    }
    fun update_tick(p0: &mut table::Table<u32, TickInfo>, p1: u32, p2: u32, p3: i128::I128, p4: u256, p5: u256, p6: vector<u256>, p7: bool, p8: u128): bool {
        let _v0 = i128::zero();
        let _v1 = TickInfo{liquditiy_gross: 0u128, liquidity_net: _v0, fee_growth_outside_0_x64: 0u256, fee_growth_outside_1_x64: 0u256, reward_growths_outside: vector[], initialized: false};
        let _v2 = table::borrow_mut_with_default<u32,TickInfo>(p0, p1, _v1);
        let _v3 = *&_v2.liquditiy_gross;
        let _v4 = &p3;
        let _v5 = i128::new(_v3, false);
        let _v6 = &_v5;
        let _v7 = i128::add(_v4, _v6);
        let _v8 = i128::as_u128(&_v7);
        assert!(_v8 <= p8, 106);
        if (_v3 == 0u128) {
            'l0: loop {
                if (p1 <= p2) {
                    let _v9 = &mut _v2.fee_growth_outside_0_x64;
                    *_v9 = p4;
                    let _v10 = &mut _v2.fee_growth_outside_1_x64;
                    *_v10 = p5;
                    let _v11 = &mut _v2.reward_growths_outside;
                    *_v11 = p6;
                    break
                };
                let _v12 = vector::length<u256>(&p6);
                let _v13 = 0;
                loop {
                    if (!(_v13 < _v12)) break 'l0;
                    vector::push_back<u256>(&mut _v2.reward_growths_outside, 0u256);
                    _v13 = _v13 + 1
                };
                break
            };
            let _v14 = &mut _v2.initialized;
            *_v14 = true
        };
        let _v15 = &mut _v2.liquditiy_gross;
        *_v15 = _v8;
        if (p7) {
            let _v16 = &_v2.liquidity_net;
            let _v17 = &p3;
            let _v18 = i128::sub(_v16, _v17);
            let _v19 = &mut _v2.liquidity_net;
            *_v19 = _v18
        } else {
            let _v20 = &p3;
            let _v21 = &_v2.liquidity_net;
            let _v22 = i128::add(_v20, _v21);
            let _v23 = &mut _v2.liquidity_net;
            *_v23 = _v22
        };
        _v3 == 0u128 != (_v8 == 0u128)
    }
}
