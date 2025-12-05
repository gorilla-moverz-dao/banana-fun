module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::coin_helper {
    use 0x1::account;
    use 0x1::coin;
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::option;
    use 0x1::primary_fungible_store;
    use 0x1::signer;
    friend 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::router;
    struct ResourceSignerCap has key {
        signer_cap: account::SignerCapability,
    }
    public fun ensure_paired_metadata<T0>(): object::Object<fungible_asset::Metadata>
        acquires ResourceSignerCap
    {
        let _v0 = coin::paired_metadata<T0>();
        if (option::is_none<object::Object<fungible_asset::Metadata>>(&_v0)) {
            let _v1 = get_acc_signer();
            coin::migrate_to_fungible_store<T0>(&_v1);
            _v0 = coin::paired_metadata<T0>()
        };
        assert!(option::is_some<object::Object<fungible_asset::Metadata>>(&_v0), 1);
        option::destroy_some<object::Object<fungible_asset::Metadata>>(_v0)
    }
    public fun fungible_asset_to_coin<T0>(p0: fungible_asset::FungibleAsset): coin::Coin<T0>
        acquires ResourceSignerCap
    {
        let _v0 = get_acc_signer();
        let _v1 = &_v0;
        let _v2 = signer::address_of(_v1);
        let _v3 = fungible_asset::amount(&p0);
        primary_fungible_store::deposit(_v2, p0);
        coin::withdraw<T0>(_v1, _v3)
    }
    fun get_acc_signer(): signer
        acquires ResourceSignerCap
    {
        account::create_signer_with_capability(&borrow_global<ResourceSignerCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap)
    }
    fun init_module(p0: &signer) {
        let (_v0,_v1) = account::create_resource_account(p0, vector[99u8, 111u8, 105u8, 110u8, 95u8, 104u8, 101u8, 108u8, 112u8, 101u8, 114u8]);
        let _v2 = ResourceSignerCap{signer_cap: _v1};
        move_to<ResourceSignerCap>(p0, _v2);
    }
    #[test_only]
    public fun init_module_for_test(p0: &signer) {
        init_module(p0);
    }
    public fun paired_metadata_unchecked<T0>(): object::Object<fungible_asset::Metadata> {
        option::destroy_some<object::Object<fungible_asset::Metadata>>(coin::paired_metadata<T0>())
    }
    public fun withdraw_fa<T0>(p0: &signer, p1: u64): fungible_asset::FungibleAsset {
        coin::coin_to_fungible_asset<T0>(coin::withdraw<T0>(p0, p1))
    }
}
