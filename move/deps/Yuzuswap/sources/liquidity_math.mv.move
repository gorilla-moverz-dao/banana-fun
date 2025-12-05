module yuzuswap::liquidity_math {
    use 0x1::error;
    use 0x1::math128;
    use yuzuswap::fixed_point;
    use yuzuswap::sqrt_price_math;
    public fun get_amounts_for_liquidity(p0: u128, p1: u128, p2: u128, p3: u128): (u64, u64) {
        if (p1 > p2) {
            let _v0 = p2;
            p2 = p1;
            p1 = _v0
        };
        let _v1 = 0;
        let _v2 = 0;
        if (p0 <= p1) _v1 = sqrt_price_math::get_amount_0_delta(p1, p2, p3, false) else if (p0 < p2) {
            _v1 = sqrt_price_math::get_amount_0_delta(p0, p2, p3, false);
            _v2 = sqrt_price_math::get_amount_1_delta(p1, p0, p3, false)
        } else _v2 = sqrt_price_math::get_amount_1_delta(p1, p2, p3, false);
        (_v1, _v2)
    }
    fun get_liquidity_for_amount_0(p0: u128, p1: u128, p2: u64): u128 {
        if (p0 > p1) {
            let _v0 = p1;
            p1 = p0;
            p0 = _v0
        };
        let _v1 = p0 as u256;
        let _v2 = p1 as u256;
        let _v3 = _v1 * _v2;
        let _v4 = fixed_point::q80() as u256;
        let _v5 = _v3 / _v4;
        let _v6 = (p2 as u256) * _v5;
        let _v7 = (p1 - p0) as u256;
        (_v6 / _v7) as u128
    }
    fun get_liquidity_for_amount_1(p0: u128, p1: u128, p2: u64): u128 {
        if (p0 > p1) {
            let _v0 = p1;
            p1 = p0;
            p0 = _v0
        };
        let _v1 = p2 as u128;
        let _v2 = fixed_point::q80();
        let _v3 = p1 - p0;
        if (!(_v3 != 0u128)) {
            let _v4 = error::invalid_argument(4);
            abort _v4
        };
        let _v5 = _v1 as u256;
        let _v6 = _v2 as u256;
        let _v7 = _v5 * _v6;
        let _v8 = _v3 as u256;
        (_v7 / _v8) as u128
    }
    public fun get_liquidity_for_amounts(p0: u128, p1: u128, p2: u128, p3: u64, p4: u64): u128 {
        let _v0;
        if (p1 > p2) {
            let _v1 = p2;
            p2 = p1;
            p1 = _v1
        };
        if (p0 <= p1) _v0 = get_liquidity_for_amount_0(p1, p2, p3) else {
            let _v2;
            if (p0 < p2) {
                let _v3 = get_liquidity_for_amount_0(p0, p2, p3);
                let _v4 = get_liquidity_for_amount_1(p1, p0, p4);
                _v2 = math128::min(_v3, _v4)
            } else _v2 = get_liquidity_for_amount_1(p1, p2, p4);
            _v0 = _v2
        };
        _v0
    }
}
