module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::math {
    use 0x1::error;
    public fun div_rounding_up_u128(p0: u128, p1: u128): u128 {
        let _v0 = p0 / p1;
        if (p0 % p1 > 0u128) _v0 = _v0 + 1u128;
        _v0
    }
    public fun div_rounding_up_u256(p0: u256, p1: u256): u256 {
        let _v0 = p0 / p1;
        if (p0 % p1 > 0u256) _v0 = _v0 + 1u256;
        _v0
    }
    public fun mul_div_rounding_up_u128(p0: u128, p1: u128, p2: u128): u128 {
        let _v0 = p2;
        if (!(_v0 != 0u128)) {
            let _v1 = error::invalid_argument(4);
            abort _v1
        };
        let _v2 = p0 as u256;
        let _v3 = p1 as u256;
        let _v4 = _v2 * _v3;
        let _v5 = _v0 as u256;
        let _v6 = (_v4 / _v5) as u128;
        if (mul_mod_u128(p0, p1, p2) > 0u128) _v6 = _v6 + 1u128;
        _v6
    }
    public fun mul_div_rounding_up_u64(p0: u64, p1: u64, p2: u64): u64 {
        let _v0 = p2;
        if (!(_v0 != 0)) {
            let _v1 = error::invalid_argument(4);
            abort _v1
        };
        let _v2 = p0 as u128;
        let _v3 = p1 as u128;
        let _v4 = _v2 * _v3;
        let _v5 = _v0 as u128;
        let _v6 = (_v4 / _v5) as u64;
        if (mul_mod_u64(p0, p1, p2) > 0) _v6 = _v6 + 1;
        _v6
    }
    public fun mul_div_u256(p0: u256, p1: u256, p2: u256): u256 {
        p0 * p1 / p2
    }
    fun mul_mod_u128(p0: u128, p1: u128, p2: u128): u128 {
        let _v0 = p0 as u256;
        let _v1 = p1 as u256;
        let _v2 = _v0 * _v1;
        let _v3 = p2 as u256;
        (_v2 % _v3) as u128
    }
    fun mul_mod_u64(p0: u64, p1: u64, p2: u64): u64 {
        let _v0 = p0 as u128;
        let _v1 = p1 as u128;
        let _v2 = _v0 * _v1;
        let _v3 = p2 as u128;
        (_v2 % _v3) as u64
    }
    public fun overflow_add_u256(p0: u256, p1: u256): u256 {
        let _v0;
        if (115792089237316195423570985008687907853269984665640564039457584007913129639935u256 - p0 >= p1) _v0 = p0 + p1 else {
            let _v1 = 115792089237316195423570985008687907853269984665640564039457584007913129639935u256 - p0;
            _v0 = p1 - _v1 - 1u256
        };
        _v0
    }
    fun overflow_sub_u256(p0: u256, p1: u256): (u256, bool) {
        let _v0;
        let _v1;
        if (p0 >= p1) {
            let _v2 = p0 - p1;
            _v1 = false;
            _v0 = _v2
        } else {
            let _v3 = 115792089237316195423570985008687907853269984665640564039457584007913129639935u256 - p1 + p0 + 1u256;
            _v1 = true;
            _v0 = _v3
        };
        (_v0, _v1)
    }
    public fun wrapping_sub_u256(p0: u256, p1: u256): u256 {
        let (_v0,_v1) = overflow_sub_u256(p0, p1);
        _v0
    }
}
