module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::swap_math {
    use 0x1::error;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::config;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::sqrt_price_math;
    public fun compute_swap_step(p0: u128, p1: u128, p2: u128, p3: u64, p4: bool, p5: u64): (u128, u64, u64, u64) {
        let _v0;
        let _v1;
        let _v2;
        let _v3;
        let _v4 = p0 >= p1;
        let _v5 = config::fee_scale();
        let _v6 = 0;
        let _v7 = 0;
        loop {
            let _v8;
            if (p4) {
                let _v9;
                let _v10 = _v5 - p5;
                let _v11 = _v5;
                if (!(_v11 != 0)) {
                    let _v12 = error::invalid_argument(4);
                    abort _v12
                };
                let _v13 = p3 as u128;
                let _v14 = _v10 as u128;
                let _v15 = _v13 * _v14;
                let _v16 = _v11 as u128;
                let _v17 = (_v15 / _v16) as u64;
                if (_v4) _v9 = sqrt_price_math::get_amount_0_delta(p1, p0, p2, true) else _v9 = sqrt_price_math::get_amount_1_delta(p0, p1, p2, true);
                _v6 = _v9;
                if (_v17 >= _v6) {
                    _v3 = p1;
                    break
                };
                _v3 = sqrt_price_math::get_next_sqrt_price_from_input(p0, p2, _v17, _v4);
                break
            };
            if (_v4) _v8 = sqrt_price_math::get_amount_1_delta(p1, p0, p2, false) else _v8 = sqrt_price_math::get_amount_0_delta(p0, p1, p2, false);
            _v7 = _v8;
            if (p3 >= _v7) {
                _v3 = p1;
                break
            };
            _v3 = sqrt_price_math::get_next_sqrt_price_from_output(p0, p2, p3, _v4);
            break
        };
        let _v18 = p1 == _v3;
        if (_v4) {
            let _v19;
            let _v20;
            let _v21;
            if (_v18 && p4) _v21 = _v6 else _v21 = sqrt_price_math::get_amount_0_delta(_v3, p0, p2, true);
            _v6 = _v21;
            if (_v18) _v20 = !p4 else _v20 = false;
            if (_v20) _v19 = _v7 else _v19 = sqrt_price_math::get_amount_1_delta(_v3, p0, p2, false);
            _v7 = _v19
        } else {
            let _v22;
            let _v23;
            let _v24;
            if (_v18 && p4) _v24 = _v6 else _v24 = sqrt_price_math::get_amount_1_delta(p0, _v3, p2, true);
            _v6 = _v24;
            if (_v18) _v23 = !p4 else _v23 = false;
            if (_v23) _v22 = _v7 else _v22 = sqrt_price_math::get_amount_0_delta(p0, _v3, p2, false);
            _v7 = _v22
        };
        if (p4) _v2 = false else _v2 = _v7 > p3;
        if (_v2) _v7 = p3;
        if (p4) _v1 = _v3 != p1 else _v1 = false;
        if (_v1) _v0 = p3 - _v6 else {
            let _v25 = _v5 - p5;
            _v0 = math::mul_div_rounding_up_u64(_v6, p5, _v25)
        };
        (_v3, _v6, _v7, _v0)
    }
}
