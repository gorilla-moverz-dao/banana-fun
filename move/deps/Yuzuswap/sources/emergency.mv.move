module yuzuswap::emergency {
    use 0x1::account;
    use yuzuswap::config;
    friend yuzuswap::liquidity_pool;
    struct EmergencyAccountCap has key {
        signer_cap: account::SignerCapability
    }

    struct IsDisabled has key {}

    struct IsEmergency has key {}

    public fun assert_no_emergency() acquires EmergencyAccountCap {
        assert!(!is_emergency(), 602);
    }

    public entry fun disable_forever(p0: &signer) acquires EmergencyAccountCap {
        assert!(!is_disabled(), 601);
        config::assert_emergency_admin(p0);
        let _v0 =
            account::create_signer_with_capability(
                &borrow_global<EmergencyAccountCap>(
                    @yuzuswap
                ).signer_cap
            );
        let _v1 = &_v0;
        let _v2 = IsDisabled {};
        move_to<IsDisabled>(_v1, _v2);
    }

    fun get_emergency_account_address(): address acquires EmergencyAccountCap {
        account::get_signer_capability_address(
            &borrow_global<EmergencyAccountCap>(
                @yuzuswap
            ).signer_cap
        )
    }

    fun init_module(p0: &signer) {
        let (_v0, _v1) =
            account::create_resource_account(
                p0,
                vector[
                    101u8, 109u8, 101u8, 114u8, 103u8, 101u8, 110u8, 99u8, 121u8, 95u8, 97u8, 99u8,
                    99u8, 111u8, 117u8, 110u8, 116u8
                ]
            );
        let _v2 = EmergencyAccountCap { signer_cap: _v1 };
        move_to<EmergencyAccountCap>(p0, _v2);
    }

    public fun is_disabled(): bool acquires EmergencyAccountCap {
        let _v0 = get_emergency_account_address();
        exists<IsDisabled>(_v0)
    }

    public fun is_emergency(): bool acquires EmergencyAccountCap {
        let _v0 = get_emergency_account_address();
        exists<IsEmergency>(_v0)
    }

    public entry fun pause(p0: &signer) acquires EmergencyAccountCap {
        assert!(!is_disabled(), 601);
        assert_no_emergency();
        config::assert_emergency_admin(p0);
        let _v0 =
            account::create_signer_with_capability(
                &borrow_global<EmergencyAccountCap>(
                    @yuzuswap
                ).signer_cap
            );
        let _v1 = &_v0;
        let _v2 = IsEmergency {};
        move_to<IsEmergency>(_v1, _v2);
    }

    public entry fun resume(p0: &signer) acquires EmergencyAccountCap, IsEmergency {
        assert!(!is_disabled(), 601);
        assert!(is_emergency(), 603);
        config::assert_emergency_admin(p0);
        let _v0 = get_emergency_account_address();
        let IsEmergency {} = move_from<IsEmergency>(_v0);
    }

    #[test_only]
    public fun init_module_for_test(p0: &signer) {
        init_module(p0);
    }
}

