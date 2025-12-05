module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick_bitmap {
    use 0x1::table;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::bit_math;
    use 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick;
    public fun flip_tick(p0: &mut table::Table<u16, u256>, p1: u32, p2: u32) {
        assert!(tick::is_spaced_tick(p1, p2), 1);
        let _v0 = tick::tick_adjustment(p2);
        let (_v1,_v2) = tick_bitmap_position((p1 - _v0) / p2);
        let _v3 = _v1;
        let _v4 = 1u256 << _v2;
        let _v5 = 0u256;
        let _v6 = &_v5;
        let _v7 = *table::borrow_with_default<u16,u256>(freeze(p0), _v3, _v6);
        table::upsert<u16,u256>(p0, _v3, _v7 ^ _v4);
    }
    public fun get_next_initialized_tick_within_one_word(p0: &table::Table<u16, u256>, p1: u32, p2: u32, p3: bool): (u32, bool) {
        let _v0;
        let _v1;
        let _v2 = tick::tick_adjustment(p2);
        let _v3 = p1 < _v2 && p3;
        loop {
            if (!_v3) {
                let _v4;
                let _v5;
                if (p1 < _v2) _v5 = 0u32 else _v5 = (p1 - _v2) / p2;
                if (p3) {
                    let _v6;
                    let (_v7,_v8) = tick_bitmap_position(_v5);
                    let _v9 = _v8;
                    let _v10 = (1u256 << _v9) - 1u256;
                    let _v11 = 1u256 << _v9;
                    let _v12 = _v10 + _v11;
                    let _v13 = 0u256;
                    let _v14 = &_v13;
                    let _v15 = *table::borrow_with_default<u16,u256>(p0, _v7, _v14) & _v12;
                    _v1 = _v15 != 0u256;
                    if (_v1) {
                        let _v16 = bit_math::most_significant_bit_u256(_v15);
                        let _v17 = (_v9 - _v16) as u32;
                        _v6 = (_v5 - _v17) * p2
                    } else {
                        let _v18 = _v9 as u32;
                        _v6 = (_v5 - _v18) * p2
                    };
                    _v0 = _v6;
                    break
                };
                let (_v19,_v20) = tick_bitmap_position(_v5 + 1u32);
                let _v21 = _v20;
                let _v22 = (1u256 << _v21) - 1u256;
                let _v23 = 0u256;
                let _v24 = &_v23;
                let _v25 = *table::borrow_with_default<u16,u256>(p0, _v19, _v24) & (_v22 ^ 115792089237316195423570985008687907853269984665640564039457584007913129639935u256);
                _v1 = _v25 != 0u256;
                if (_v1) {
                    let _v26 = _v5 + 1u32;
                    let _v27 = (bit_math::least_significant_bit_u256(_v25) - _v21) as u32;
                    _v4 = (_v26 + _v27) * p2
                } else {
                    let _v28 = _v5 + 1u32;
                    let _v29 = (255u8 - _v21) as u32;
                    _v4 = (_v28 + _v29) * p2
                };
                _v0 = _v4;
                break
            };
            return (tick::min_tick(), false)
        };
        (_v0 + _v2, _v1)
    }
    fun tick_bitmap_position(p0: u32): (u16, u8) {
        let _v0 = (p0 >> 8u8) as u16;
        let _v1 = (p0 % 256u32) as u8;
        (_v0, _v1)
    }
}
