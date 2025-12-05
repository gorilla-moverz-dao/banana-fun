module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::position_nft_manager {
    use 0x1::account;
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::option;
    use 0x1::signer;
    use 0x1::string;
    use 0x1::string_utils;
    use 0x4::collection;
    use 0x4::royalty;
    use 0x4::token;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::liquidity_pool;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick_math;
    friend 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::router;
    struct PositionToken has key {
        pool: address,
        position_id: u64,
        burn_ref: token::BurnRef,
    }
    struct ResourceSignerCap has key {
        signer_cap: account::SignerCapability,
    }
    public fun burn(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64): vector<fungible_asset::FungibleAsset>
        acquires PositionToken, ResourceSignerCap
    {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p1);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        let _v6 = token::create_token_address(_v1, _v3, _v5);
        let _v7 = object::address_to_object<token::Token>(_v6);
        let _v8 = signer::address_of(p0);
        assert!(object::is_owner<token::Token>(_v7, _v8), 301);
        let _v9 = get_nft_manager_acc_signer();
        let _v10 = &_v9;
        let (_v11,_v12,_v13,_v14,_v15) = liquidity_pool::get_position_info(get_nft_manager_acc_addr(), p1, p2);
        let _v16 = 0x1::vector::empty<fungible_asset::FungibleAsset>();
        let (_v17,_v18) = decrease_liquidity(p0, p1, p2, _v11, 0, 0);
        0x1::vector::push_back<fungible_asset::FungibleAsset>(&mut _v16, _v17);
        0x1::vector::push_back<fungible_asset::FungibleAsset>(&mut _v16, _v18);
        let (_v19,_v20) = liquidity_pool::collect_fee(_v10, p1, p2, 18446744073709551615, 18446744073709551615);
        0x1::vector::push_back<fungible_asset::FungibleAsset>(&mut _v16, _v19);
        0x1::vector::push_back<fungible_asset::FungibleAsset>(&mut _v16, _v20);
        let _v21 = liquidity_pool::rewards_count(p1);
        let _v22 = 0;
        let _v23 = false;
        loop {
            if (_v23) _v22 = _v22 + 1 else _v23 = true;
            if (!(_v22 < _v21)) break;
            let _v24 = liquidity_pool::collect_reward(_v10, p1, p2, _v22, 18446744073709551615);
            0x1::vector::push_back<fungible_asset::FungibleAsset>(&mut _v16, _v24);
            continue
        };
        liquidity_pool::close_position(_v10, p1, p2);
        let PositionToken{pool: _v25, position_id: _v26, burn_ref: _v27} = move_from<PositionToken>(_v6);
        token::burn(_v27);
        _v16
    }
    public fun collect_fee(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset)
        acquires ResourceSignerCap
    {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p1);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        let _v6 = object::address_to_object<token::Token>(token::create_token_address(_v1, _v3, _v5));
        let _v7 = signer::address_of(p0);
        assert!(object::is_owner<token::Token>(_v6, _v7), 301);
        let _v8 = get_nft_manager_acc_signer();
        let (_v9,_v10) = liquidity_pool::collect_fee(&_v8, p1, p2, p3, p4);
        (_v9, _v10)
    }
    public fun collect_reward(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u64, p4: u64): fungible_asset::FungibleAsset
        acquires ResourceSignerCap
    {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p1);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        let _v6 = object::address_to_object<token::Token>(token::create_token_address(_v1, _v3, _v5));
        let _v7 = signer::address_of(p0);
        assert!(object::is_owner<token::Token>(_v6, _v7), 301);
        let _v8 = get_nft_manager_acc_signer();
        liquidity_pool::collect_reward(&_v8, p1, p2, p3, p4)
    }
    friend fun create_collection(p0: object::Object<liquidity_pool::LiquidityPool>, p1: string::String): string::String {
        let _v0 = get_collection_name(p0);
        let _v1 = liquidity_pool::get_pool_signer(p0);
        let _v2 = &_v1;
        let _v3 = string::utf8(vector[89u8, 117u8, 122u8, 117u8, 115u8, 119u8, 97u8, 112u8, 32u8, 108u8, 105u8, 113u8, 117u8, 105u8, 100u8, 105u8, 116u8, 121u8, 32u8, 112u8, 111u8, 115u8, 105u8, 116u8, 105u8, 111u8, 110u8, 32u8, 99u8, 111u8, 108u8, 108u8, 101u8, 99u8, 116u8, 105u8, 111u8, 110u8]);
        let _v4 = option::none<royalty::Royalty>();
        let _v5 = collection::create_unlimited_collection(_v2, _v3, _v0, _v4, p1);
        _v0
    }
    public fun decrease_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: u128, p4: u64, p5: u64): (fungible_asset::FungibleAsset, fungible_asset::FungibleAsset)
        acquires ResourceSignerCap
    {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p1);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        let _v6 = object::address_to_object<token::Token>(token::create_token_address(_v1, _v3, _v5));
        let _v7 = signer::address_of(p0);
        assert!(object::is_owner<token::Token>(_v6, _v7), 301);
        let _v8 = get_nft_manager_acc_signer();
        let (_v9,_v10) = liquidity_pool::remove_liquidity(&_v8, p1, p2, p3);
        let _v11 = _v10;
        let _v12 = _v9;
        assert!(fungible_asset::amount(&_v12) >= p4, 303);
        assert!(fungible_asset::amount(&_v11) >= p5, 303);
        (_v12, _v11)
    }
    fun get_collection_name(p0: object::Object<liquidity_pool::LiquidityPool>): string::String {
        let (_v0,_v1,_v2,_v3,_v4,_v5,_v6) = liquidity_pool::get_pool_info(p0);
        let _v7 = _v6;
        let _v8 = _v5;
        let _v9 = string::utf8(vector[89u8, 117u8, 122u8, 117u8, 115u8, 119u8, 97u8, 112u8, 32u8, 108u8, 105u8, 113u8, 117u8, 105u8, 100u8, 105u8, 116u8, 121u8, 32u8, 112u8, 111u8, 115u8, 105u8, 116u8, 105u8, 111u8, 110u8, 32u8, 124u8, 32u8]);
        let _v10 = &mut _v9;
        let _v11 = fungible_asset::symbol<fungible_asset::Metadata>(_v0);
        string::append(_v10, _v11);
        string::append_utf8(&mut _v9, vector[47u8]);
        let _v12 = &mut _v9;
        let _v13 = fungible_asset::symbol<fungible_asset::Metadata>(_v1);
        string::append(_v12, _v13);
        string::append_utf8(&mut _v9, vector[32u8, 124u8, 32u8, 102u8, 101u8, 101u8, 58u8, 32u8]);
        let _v14 = &mut _v9;
        let _v15 = string_utils::to_string<u64>(&_v8);
        string::append(_v14, _v15);
        string::append_utf8(&mut _v9, vector[32u8, 124u8, 32u8, 116u8, 105u8, 99u8, 107u8, 32u8, 115u8, 112u8, 97u8, 99u8, 105u8, 110u8, 103u8, 58u8, 32u8]);
        let _v16 = &mut _v9;
        let _v17 = string_utils::to_string<u32>(&_v7);
        string::append(_v16, _v17);
        _v9
    }
    public fun get_nft_manager_acc_addr(): address
        acquires ResourceSignerCap
    {
        account::get_signer_capability_address(&borrow_global<ResourceSignerCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap)
    }
    fun get_nft_manager_acc_signer(): signer
        acquires ResourceSignerCap
    {
        account::create_signer_with_capability(&borrow_global<ResourceSignerCap>(@0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a).signer_cap)
    }
    public fun get_position(p0: object::Object<liquidity_pool::LiquidityPool>, p1: u64): liquidity_pool::Position
        acquires ResourceSignerCap
    {
        liquidity_pool::get_position(get_nft_manager_acc_addr(), p0, p1)
    }
    public fun get_position_token_amounts(p0: object::Object<liquidity_pool::LiquidityPool>, p1: u64): (u64, u64)
        acquires ResourceSignerCap
    {
        let _v0 = get_nft_manager_acc_addr();
        let (_v1,_v2) = liquidity_pool::get_position_token_amounts(p0, _v0, p1);
        (_v1, _v2)
    }
    public fun get_positions(p0: vector<address>, p1: vector<u64>): vector<option::Option<liquidity_pool::Position>>
        acquires ResourceSignerCap
    {
        let _v0 = 0x1::vector::length<address>(&p0);
        let _v1 = 0x1::vector::length<u64>(&p1);
        assert!(_v0 == _v1, 304);
        let _v2 = get_nft_manager_acc_addr();
        let _v3 = 0x1::vector::empty<option::Option<liquidity_pool::Position>>();
        let _v4 = 0;
        let _v5 = false;
        let _v6 = 0x1::vector::length<u64>(&p1);
        loop {
            if (_v5) _v4 = _v4 + 1 else _v5 = true;
            if (!(_v4 < _v6)) break;
            let _v7 = *0x1::vector::borrow<address>(&p0, _v4);
            if (!object::object_exists<liquidity_pool::LiquidityPool>(_v7)) {
                let _v8 = &mut _v3;
                let _v9 = option::none<liquidity_pool::Position>();
                0x1::vector::push_back<option::Option<liquidity_pool::Position>>(_v8, _v9);
                continue
            };
            let _v10 = object::address_to_object<liquidity_pool::LiquidityPool>(_v7);
            let _v11 = *0x1::vector::borrow<u64>(&p1, _v4);
            let _v12 = &mut _v3;
            let _v13 = option::some<liquidity_pool::Position>(liquidity_pool::get_position_with_pending_fees_and_rewards(_v2, _v10, _v11));
            0x1::vector::push_back<option::Option<liquidity_pool::Position>>(_v12, _v13);
            continue
        };
        _v3
    }
    public fun increase_liquidity(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u64, p3: &mut fungible_asset::FungibleAsset, p4: &mut fungible_asset::FungibleAsset, p5: u64, p6: u64)
        acquires ResourceSignerCap
    {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p1);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        let _v6 = object::address_to_object<token::Token>(token::create_token_address(_v1, _v3, _v5));
        let _v7 = signer::address_of(p0);
        assert!(object::is_owner<token::Token>(_v6, _v7), 301);
        let _v8 = get_nft_manager_acc_signer();
        let _v9 = &_v8;
        let (_v10,_v11,_v12,_v13,_v14,_v15,_v16) = liquidity_pool::get_pool_info(p1);
        let (_v17,_v18,_v19,_v20,_v21) = liquidity_pool::get_position_info(signer::address_of(_v9), p1, p2);
        let _v22 = fungible_asset::amount(freeze(p3));
        let _v23 = fungible_asset::amount(freeze(p4));
        let _v24 = tick_math::get_sqrt_price_at_tick(_v18);
        let _v25 = tick_math::get_sqrt_price_at_tick(_v19);
        let _v26 = liquidity_math::get_liquidity_for_amounts(_v12, _v24, _v25, _v22, _v23);
        liquidity_pool::add_liquidity(_v9, p1, p2, _v26, p3, p4);
        let _v27 = fungible_asset::amount(freeze(p3));
        assert!(_v22 - _v27 >= p5, 302);
        let _v28 = fungible_asset::amount(freeze(p4));
        assert!(_v23 - _v28 >= p6, 302);
    }
    fun init_module(p0: &signer) {
        let (_v0,_v1) = account::create_resource_account(p0, vector[112u8, 111u8, 115u8, 105u8, 116u8, 105u8, 111u8, 110u8, 95u8, 110u8, 102u8, 116u8, 95u8, 109u8, 97u8, 110u8, 97u8, 103u8, 101u8, 114u8]);
        let _v2 = ResourceSignerCap{signer_cap: _v1};
        move_to<ResourceSignerCap>(p0, _v2);
    }
    #[test_only]
    public fun init_module_for_test(p0: &signer) {
        init_module(p0);
    }
    public fun is_owner(p0: object::Object<liquidity_pool::LiquidityPool>, p1: address, p2: u64): bool {
        let _v0 = object::object_address<liquidity_pool::LiquidityPool>(&p0);
        let _v1 = &_v0;
        let _v2 = get_collection_name(p0);
        let _v3 = &_v2;
        let _v4 = string_utils::to_string<u64>(&p2);
        let _v5 = &_v4;
        object::is_owner<token::Token>(object::address_to_object<token::Token>(token::create_token_address(_v1, _v3, _v5)), p1)
    }
    public fun mint(p0: &signer, p1: object::Object<liquidity_pool::LiquidityPool>, p2: u32, p3: u32, p4: &mut fungible_asset::FungibleAsset, p5: &mut fungible_asset::FungibleAsset, p6: u64, p7: u64): u64
        acquires ResourceSignerCap
    {
        let _v0 = liquidity_pool::get_pool_signer(p1);
        let _v1 = &_v0;
        let _v2 = get_nft_manager_acc_signer();
        let _v3 = liquidity_pool::open_position(&_v2, p1, p2, p3);
        let (_v4,_v5,_v6,_v7,_v8,_v9,_v10) = liquidity_pool::get_pool_info(p1);
        let _v11 = fungible_asset::amount(freeze(p4));
        let _v12 = fungible_asset::amount(freeze(p5));
        let _v13 = tick_math::get_sqrt_price_at_tick(p2);
        let _v14 = tick_math::get_sqrt_price_at_tick(p3);
        let _v15 = liquidity_math::get_liquidity_for_amounts(_v6, _v13, _v14, _v11, _v12);
        let _v16 = get_nft_manager_acc_signer();
        liquidity_pool::add_liquidity(&_v16, p1, _v3, _v15, p4, p5);
        let _v17 = fungible_asset::amount(freeze(p4));
        assert!(_v11 - _v17 >= p6, 302);
        let _v18 = fungible_asset::amount(freeze(p5));
        assert!(_v12 - _v18 >= p7, 302);
        let _v19 = get_collection_name(p1);
        let _v20 = string::utf8(vector[89u8, 117u8, 122u8, 117u8, 115u8, 119u8, 97u8, 112u8, 32u8, 108u8, 105u8, 113u8, 117u8, 105u8, 100u8, 105u8, 116u8, 121u8, 32u8, 112u8, 111u8, 115u8, 105u8, 116u8, 105u8, 111u8, 110u8]);
        let _v21 = string_utils::to_string<u64>(&_v3);
        let _v22 = option::none<royalty::Royalty>();
        let _v23 = string::utf8(vector[]);
        let _v24 = token::create_named_token(_v1, _v19, _v20, _v21, _v22, _v23);
        let _v25 = object::address_from_constructor_ref(&_v24);
        let _v26 = signer::address_of(p0);
        object::transfer_call(_v1, _v25, _v26);
        let _v27 = object::generate_signer(&_v24);
        let _v28 = &_v27;
        let _v29 = object::object_address<liquidity_pool::LiquidityPool>(&p1);
        let _v30 = token::generate_burn_ref(&_v24);
        let _v31 = PositionToken{pool: _v29, position_id: _v3, burn_ref: _v30};
        move_to<PositionToken>(_v28, _v31);
        _v3
    }
    public fun quote_remove_liquidity(p0: object::Object<liquidity_pool::LiquidityPool>, p1: vector<u64>, p2: vector<u128>, p3: bool, p4: bool): vector<vector<u64>> {
        abort 0
    }
}
