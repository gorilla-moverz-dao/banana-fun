module yuzuswap::sqrt_price_math {
    use 0x1::error;
    use yuzuswap::fixed_point;
    use yuzuswap::math;
    use yuzuswap::unsafe_math;
    public fun get_amount_0_delta(p0: u128, p1: u128, p2: u128, p3: bool): u64 {
        let _v0;
        if (p0 > p1) {
            let _v1 = p1;
            p1 = p0;
            p0 = _v1
        };
        assert!(p0 != 0u128, 1);
        let _v2 = p0 as u256;
        let _v3 = p1 as u256;
        let _v4 = p2 as u256;
        let _v5 = _v3 - _v2;
        let _v6 = _v4 * _v5;
        if (_v6 < 95780971304118053647396689196894323976171195136475135u256) {
            let _v7;
            let _v8 = fixed_point::u256_to_x80_u256(_v6);
            if (p3) _v7 = math::div_rounding_up_u256(math::div_rounding_up_u256(_v8, _v3), _v2)
            else _v7 = _v8 / _v3 / _v2;
            let _v9 = _v7;
            let _v10 = 18446744073709551615 as u256;
            assert!(_v9 <= _v10, 5);
            _v0 = _v9 as u64
        } else {
            let _v11;
            let _v12 = fixed_point::u128_to_x80_u256(p2);
            if (p3) {
                let _v13 = math::div_rounding_up_u256(_v12, _v2);
                let _v14 = _v12 / _v3;
                _v11 = _v13 - _v14
            } else {
                let _v15 = _v12 / _v2;
                let _v16 = _v12 / _v3;
                _v11 = _v15 - _v16
            };
            let _v17 = _v11;
            let _v18 = 18446744073709551615 as u256;
            if (_v17 <= _v18) _v0 = _v17 as u64
            else abort 5
        };
        _v0
    }

    public fun get_amount_1_delta(p0: u128, p1: u128, p2: u128, p3: bool): u64 {
        let _v0;
        if (p0 > p1) {
            let _v1 = p1;
            p1 = p0;
            p0 = _v1
        };
        if (p3) {
            let _v2 = p1 - p0;
            let _v3 = fixed_point::q80();
            _v0 = math::mul_div_rounding_up_u128(p2, _v2, _v3)
        } else {
            let _v4 = p1 - p0;
            let _v5 = fixed_point::q80();
            if (_v5 != 0u128) {
                let _v6 = p2 as u256;
                let _v7 = _v4 as u256;
                let _v8 = _v6 * _v7;
                let _v9 = _v5 as u256;
                _v0 = (_v8 / _v9) as u128
            } else {
                let _v10 = error::invalid_argument(4);
                abort _v10
            }
        };
        let _v11 = _v0;
        let _v12 = 18446744073709551615 as u128;
        assert!(_v11 <= _v12, 5);
        _v11 as u64
    }

    fun get_next_sqrt_price_from_amount_0_rounding_up(
        p0: u128, p1: u128, p2: u64, p3: bool
    ): u128 {
        let _v0;
        let _v1;
        let _v2;
        'l2: loop {
            let _v3;
            'l1: loop {
                'l0: loop {
                    let _v4;
                    loop {
                        if (!(p2 == 0)) {
                            _v0 = fixed_point::u128_to_x80_u256(p1);
                            _v2 = p0 as u256;
                            _v1 = p2 as u256;
                            if (p3) {
                                if (!((p1 as u256) * _v2
                                    < 95780971304118053647396689196894323976171195136475135u256))
                                    break 'l0;
                                let _v5 = _v1 * _v2;
                                _v4 = _v0 + _v5;
                                if (!(_v4 >= _v0)) break 'l0;
                                break
                            };
                            if ((p1 as u256) * _v2
                                < 95780971304118053647396689196894323976171195136475135u256) {
                                _v3 = _v1 * _v2;
                                if (_v0 > _v3) break 'l1;
                                abort 4
                            };
                            let _v6 = _v1 * _v2;
                            if (_v0 > _v6) break 'l2;
                            abort 4
                        };
                        return p0
                    };
                    return unsafe_math::mul_div_rounding_up(_v0, _v2, _v4) as u128
                };
                let _v7 = _v0 / _v2;
                let _v8 = _v1 + _v7;
                return math::div_rounding_up_u256(_v0, _v8) as u128
            };
            let _v9 = _v0 - _v3;
            return unsafe_math::mul_div_rounding_up(_v0, _v2, _v9) as u128
        };
        let _v10 = _v0 / _v2 - _v1;
        math::div_rounding_up_u256(_v0, _v10) as u128
    }

    fun get_next_sqrt_price_from_amount_1_rounding_down(
        p0: u128, p1: u128, p2: u64, p3: bool
    ): u128 {
        let _v0;
        if (p3) {
            let _v1 = fixed_point::u64_to_x80_u256(p2);
            let _v2 = p1 as u256;
            let _v3 = _v1 / _v2;
            _v0 = ((p0 as u256) + _v3) as u128
        } else {
            let _v4 = fixed_point::u64_to_x80_u256(p2);
            let _v5 = p1 as u256;
            let _v6 = math::div_rounding_up_u256(_v4, _v5);
            if ((p0 as u256) > _v6) {
                let _v7 = _v6 as u128;
                _v0 = p0 - _v7
            } else abort 2
        };
        _v0
    }

    public fun get_next_sqrt_price_from_input(
        p0: u128, p1: u128, p2: u64, p3: bool
    ): u128 {
        let _v0;
        assert!(p0 > 0u128, 1);
        assert!(p1 > 0u128, 3);
        if (p3) _v0 = get_next_sqrt_price_from_amount_0_rounding_up(p0, p1, p2, true)
        else _v0 = get_next_sqrt_price_from_amount_1_rounding_down(p0, p1, p2, true);
        _v0
    }

    public fun get_next_sqrt_price_from_output(
        p0: u128, p1: u128, p2: u64, p3: bool
    ): u128 {
        let _v0;
        assert!(p0 > 0u128, 1);
        assert!(p1 > 0u128, 3);
        if (p3) _v0 = get_next_sqrt_price_from_amount_1_rounding_down(p0, p1, p2, false)
        else _v0 = get_next_sqrt_price_from_amount_0_rounding_up(p0, p1, p2, false);
        _v0
    }
}

