module yuzuswap::config {
    use 0x1::signer;
    use 0x1::table;
    struct Config has key {
        pool_admin: address,
        reward_admin: address,
        emergency_admin: address,
        treasury: address,
        protocol_fee_rate: u64
    }

    struct TraderFeeMultipliers has key {
        values: table::Table<address, u64>
    }

    public fun pool_admin(): address acquires Config {
        *&borrow_global<Config>(@yuzuswap)
            .pool_admin
    }

    public fun reward_admin(): address acquires Config {
        *&borrow_global<Config>(@yuzuswap)
            .reward_admin
    }

    public fun emergency_admin(): address acquires Config {
        *&borrow_global<Config>(@yuzuswap)
            .pool_admin
    }

    public fun treasury(): address acquires Config {
        *&borrow_global<Config>(@yuzuswap)
            .treasury
    }

    public fun protocol_fee_rate(): u64 acquires Config {
        *&borrow_global<Config>(@yuzuswap)
            .protocol_fee_rate
    }

    public fun assert_emergency_admin(p0: &signer) acquires Config {
        let _v0 =
            borrow_global<Config>(
                @yuzuswap
            );
        let _v1 = signer::address_of(p0);
        let _v2 = *&_v0.emergency_admin;
        assert!(_v1 == _v2, 1);
    }

    public fun assert_pool_admin(p0: &signer) acquires Config {
        let _v0 =
            borrow_global<Config>(
                @yuzuswap
            );
        let _v1 = signer::address_of(p0);
        let _v2 = *&_v0.pool_admin;
        assert!(_v1 == _v2, 1);
    }

    public fun assert_reward_admin(p0: &signer) acquires Config {
        let _v0 =
            borrow_global<Config>(
                @yuzuswap
            );
        let _v1 = signer::address_of(p0);
        let _v2 = *&_v0.reward_admin;
        assert!(_v1 == _v2, 1);
    }

    public fun fee_scale(): u64 {
        1000000
    }

    public fun get_trader_fee_multiplier(p0: address): u64 acquires TraderFeeMultipliers {
        let _v0;
        let _v1 =
            &borrow_global<TraderFeeMultipliers>(
                @yuzuswap
            ).values;
        if (table::contains<address, u64>(_v1, p0)) _v0 = *table::borrow<address, u64>(_v1, p0)
        else _v0 = 10000;
        _v0
    }

    public fun get_trader_fee_rate(p0: address, p1: u64): u64 acquires TraderFeeMultipliers {
        let _v0;
        let _v1 =
            &borrow_global<TraderFeeMultipliers>(
                @yuzuswap
            ).values;
        if (table::contains<address, u64>(_v1, p0)) {
            let _v2 = *table::borrow<address, u64>(_v1, p0);
            _v0 = p1 * _v2 / 10000
        } else _v0 = p1;
        _v0
    }

    fun init_module(p0: &signer) {
        let _v0 = Config {
            pool_admin: @0x10834a54f1c6064da9909e0f3cf4319cad8e08ca9a38f7fa19a851bf951fcbce,
            reward_admin: @0x10834a54f1c6064da9909e0f3cf4319cad8e08ca9a38f7fa19a851bf951fcbce,
            emergency_admin: @0x10834a54f1c6064da9909e0f3cf4319cad8e08ca9a38f7fa19a851bf951fcbce,
            treasury: @0xf5013610bc5abc7ecd151dd9fecf0def83fd5d44ad8d167a117491c5e1e8bac6,
            protocol_fee_rate: 200000
        };
        move_to<Config>(p0, _v0);
        let _v1 = TraderFeeMultipliers {
            values: table::new<address, u64>()
        };
        move_to<TraderFeeMultipliers>(p0, _v1);
    }

    public entry fun set_emergency_admin(p0: &signer, p1: address) acquires Config {
        assert_emergency_admin(p0);
        let _v0 =
            &mut borrow_global_mut<Config>(
                @yuzuswap
            ).emergency_admin;
        *_v0 = p1;
    }

    public entry fun set_pool_admin(p0: &signer, p1: address) acquires Config {
        assert_pool_admin(p0);
        let _v0 =
            &mut borrow_global_mut<Config>(
                @yuzuswap
            ).pool_admin;
        *_v0 = p1;
    }

    public entry fun set_protocol_fee(p0: &signer, p1: u64) acquires Config {
        assert_pool_admin(p0);
        assert!(p1 <= 1000000, 2);
        let _v0 =
            &mut borrow_global_mut<Config>(
                @yuzuswap
            ).protocol_fee_rate;
        *_v0 = p1;
    }

    public entry fun set_reward_admin(p0: &signer, p1: address) acquires Config {
        assert_reward_admin(p0);
        let _v0 =
            &mut borrow_global_mut<Config>(
                @yuzuswap
            ).reward_admin;
        *_v0 = p1;
    }

    public entry fun set_trader_fee_multipliers(
        p0: &signer, p1: vector<address>, p2: vector<u64>
    ) acquires Config, TraderFeeMultipliers {
        assert_pool_admin(p0);
        let _v0 = 0x1::vector::length<address>(&p1);
        let _v1 = 0x1::vector::length<u64>(&p2);
        assert!(_v0 == _v1, 4);
        let _v2 =
            &mut borrow_global_mut<TraderFeeMultipliers>(
                @yuzuswap
            ).values;
        'l0: loop {
            loop {
                if (!(0x1::vector::length<address>(&p1) > 0)) break 'l0;
                let _v3 = 0x1::vector::pop_back<u64>(&mut p2);
                if (!(_v3 <= 10000)) break;
                let _v4 = 0x1::vector::pop_back<address>(&mut p1);
                if (_v3 < 10000) {
                    table::upsert<address, u64>(_v2, _v4, _v3);
                    continue
                };
                if (!table::contains<address, u64>(freeze(_v2), _v4))
                    continue;
                let _v5 = table::remove<address, u64>(_v2, _v4);
                continue
            };
            abort 3
        };
    }

    public entry fun set_treasury(p0: &signer, p1: address) acquires Config {
        assert_pool_admin(p0);
        let _v0 =
            &mut borrow_global_mut<Config>(
                @yuzuswap
            ).treasury;
        *_v0 = p1;
    }

    public fun trader_fee_multiplier_scale(): u64 {
        10000
    }

    #[test_only]
    public fun init_module_for_test(p0: &signer) {
        init_module(p0);
    }
}

