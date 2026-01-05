module yuzuswap::fee_tier {
    use 0x1::event;
    use 0x1::table;
    use yuzuswap::config;
    #[event]
    struct AddFeeTierEvent has drop, store {
        fee: u64,
        tick_spacing: u64
    }

    #[event]
    struct DeleteFeeTierEvent has drop, store {
        fee: u64
    }

    struct FeeTiers has key {
        fee_tiers: table::Table<u64, u32>
    }

    public entry fun add_fee_tier(p0: &signer, p1: u64, p2: u32) acquires FeeTiers {
        assert!(p1 > 0, 201);
        let _v0 = config::fee_scale();
        assert!(p1 < _v0, 202);
        assert!(p2 > 0u32, 205);
        config::assert_pool_admin(p0);
        let _v1 = &mut borrow_global_mut<FeeTiers>(@yuzuswap).fee_tiers;
        assert!(!table::contains<u64, u32>(freeze(_v1), p1), 203);
        table::add<u64, u32>(_v1, p1, p2);
    }

    public entry fun delete_fee_tier(p0: &signer, p1: u64) acquires FeeTiers {
        config::assert_pool_admin(p0);
        let _v0 = &mut borrow_global_mut<FeeTiers>(@yuzuswap).fee_tiers;
        assert!(table::contains<u64, u32>(freeze(_v0), p1), 204);
        let _v1 = table::remove<u64, u32>(_v0, p1);
        event::emit<DeleteFeeTierEvent>(DeleteFeeTierEvent { fee: p1 });
    }

    public fun get_tick_spacing(p0: u64): u32 acquires FeeTiers {
        let _v0 = &borrow_global<FeeTiers>(@yuzuswap).fee_tiers;
        assert!(table::contains<u64, u32>(_v0, p0), 204);
        *table::borrow<u64, u32>(_v0, p0)
    }

    fun init_module(p0: &signer) {
        let _v0 = table::new<u64, u32>();
        table::add<u64, u32>(&mut _v0, 100, 2u32);
        table::add<u64, u32>(&mut _v0, 500, 10u32);
        table::add<u64, u32>(&mut _v0, 2500, 50u32);
        table::add<u64, u32>(&mut _v0, 10000, 200u32);
        let _v1 = FeeTiers { fee_tiers: _v0 };
        move_to<FeeTiers>(p0, _v1);
    }

    #[test_only]
    public fun init_module_for_test(p0: &signer) {
        init_module(p0);
    }
}

