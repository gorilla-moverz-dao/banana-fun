module yuzuswap::oracle {
    use yuzuswap::i64;
    use yuzuswap::math;
    use yuzuswap::tick;
    friend yuzuswap::liquidity_pool;
    struct Observation has copy, drop, store {
        timestamp: u64,
        tick_cumulative: i64::I64,
        seconds_per_liquidity_cumulative: u256,
        initialized: bool,
    }
    public fun timestamp(p0: &Observation): u64 {
        *&p0.timestamp
    }
    public fun tick_cumulative(p0: &Observation): i64::I64 {
        *&p0.tick_cumulative
    }
    public fun seconds_per_liquidity_cumulative(p0: &Observation): u256 {
        *&p0.seconds_per_liquidity_cumulative
    }
    public fun initialized(p0: &Observation): bool {
        *&p0.initialized
    }
    public fun binary_search(p0: &vector<Observation>, p1: u64, p2: u16, p3: u16): (Observation, Observation) {
        let _v0 = empty_observation();
        let _v1 = empty_observation();
        let _v2 = (p2 + 1u16) % p3;
        let _v3 = _v2 + p3 - 1u16;
        loop {
            let _v4;
            let _v5 = (_v2 + _v3) / 2u16;
            let _v6 = _v5 % p3;
            _v0 = get_observation_or_empty(p0, _v6);
            if (!*&(&_v0).initialized) {
                _v2 = _v5 + 1u16;
                continue
            };
            let _v7 = (_v5 + 1u16) % p3;
            _v1 = get_observation_or_empty(p0, _v7);
            let _v8 = *&(&_v0).timestamp <= p1;
            if (_v8) {
                let _v9 = *&(&_v1).timestamp;
                _v4 = p1 <= _v9
            } else _v4 = false;
            if (_v4) break;
            if (!_v8) {
                _v3 = _v5 - 1u16;
                continue
            };
            _v2 = _v5 + 1u16;
            continue
        };
        (_v0, _v1)
    }
    fun empty_observation(): Observation {
        let _v0 = i64::zero();
        Observation{timestamp: 0, tick_cumulative: _v0, seconds_per_liquidity_cumulative: 0u256, initialized: false}
    }
    public fun get_observation_or_empty(p0: &vector<Observation>, p1: u16): Observation {
        let _v0;
        let _v1 = p1 as u64;
        let _v2 = 0x1::vector::length<Observation>(p0) - 1;
        if (_v1 > _v2) _v0 = empty_observation() else _v0 = *0x1::vector::borrow<Observation>(p0, _v1);
        _v0
    }
    fun get_surrounding_observations(p0: &vector<Observation>, p1: u64, p2: u32, p3: u16, p4: u128, p5: u16): (Observation, Observation) {
        let _v0 = get_observation_or_empty(p0, p3);
        let _v1 = empty_observation();
        let _v2 = *&(&_v0).timestamp;
        'l0: loop {
            loop {
                if (_v2 <= p1) if (!(*&(&_v0).timestamp == p1)) break else {
                    let _v3 = (p3 + 1u16) % p5;
                    _v0 = get_observation_or_empty(p0, _v3);
                    if (!*&(&_v0).initialized) _v0 = *0x1::vector::borrow<Observation>(p0, 0);
                    if (*&(&_v0).timestamp > p1) abort 1 else break 'l0
                };
                return (_v0, _v1)
            };
            let _v4 = transform(&_v0, p1, p2, p4);
            return (_v0, _v4)
        };
        let (_v5,_v6) = binary_search(p0, p1, p3, p5);
        (_v5, _v6)
    }
    friend fun grow(p0: &mut vector<Observation>, p1: u16, p2: u16): u16 {
        if (p1 == 0u16) abort 0;
        if (p2 > 1000u16) abort 2;
        let _v0 = p2 <= p1;
        'l0: loop {
            if (!_v0) loop {
                if (!(p1 < p2)) break 'l0;
                let _v1 = i64::zero();
                let _v2 = Observation{timestamp: 1, tick_cumulative: _v1, seconds_per_liquidity_cumulative: 0u256, initialized: false};
                0x1::vector::push_back<Observation>(p0, _v2);
                p1 = p1 + 1u16;
                continue
            };
            return p1
        };
        p2
    }
    friend fun initialize(p0: &mut vector<Observation>, p1: u64): (u16, u16) {
        let _v0 = i64::zero();
        let _v1 = Observation{timestamp: p1, tick_cumulative: _v0, seconds_per_liquidity_cumulative: 0u256, initialized: true};
        0x1::vector::push_back<Observation>(p0, _v1);
        (1u16, 1u16)
    }
    public fun max_observations(): u16 {
        1000u16
    }
    public fun observe(p0: &vector<Observation>, p1: u64, p2: vector<u64>, p3: u32, p4: u16, p5: u128, p6: u16): (vector<i64::I64>, vector<u256>) {
        if (p6 == 0u16) abort 0;
        let _v0 = 0x1::vector::empty<i64::I64>();
        let _v1 = vector[];
        let _v2 = 0x1::vector::length<u64>(&p2);
        let _v3 = 0;
        while (_v3 < _v2) {
            let _v4 = *0x1::vector::borrow<u64>(&p2, _v3);
            let (_v5,_v6) = observe_single(p0, p1, _v4, p3, p4, p5, p6);
            0x1::vector::push_back<i64::I64>(&mut _v0, _v5);
            0x1::vector::push_back<u256>(&mut _v1, _v6);
            _v3 = _v3 + 1;
            continue
        };
        (_v0, _v1)
    }
    public fun observe_single(p0: &vector<Observation>, p1: u64, p2: u64, p3: u32, p4: u16, p5: u128, p6: u16): (i64::I64, u256) {
        let _v0;
        let _v1;
        'l0: loop {
            let _v2;
            loop {
                let _v3;
                let _v4;
                if (p2 == 0) {
                    _v2 = get_observation_or_empty(p0, p4);
                    if (!(*&(&_v2).timestamp != p1)) break;
                    _v2 = transform(&_v2, p1, p3, p5);
                    break
                };
                let _v5 = p1 - p2;
                let (_v6,_v7) = get_surrounding_observations(p0, _v5, p3, p4, p5, p6);
                let _v8 = _v7;
                let _v9 = _v6;
                let _v10 = *&(&_v9).timestamp;
                if (_v5 == _v10) {
                    let _v11 = *&(&_v9).tick_cumulative;
                    _v0 = *&(&_v9).seconds_per_liquidity_cumulative;
                    _v1 = _v11;
                    break 'l0
                };
                let _v12 = *&(&_v8).timestamp;
                if (_v5 == _v12) {
                    let _v13 = *&(&_v8).tick_cumulative;
                    _v4 = *&(&_v8).seconds_per_liquidity_cumulative;
                    _v3 = _v13
                } else {
                    let _v14 = *&(&_v8).timestamp;
                    let _v15 = *&(&_v9).timestamp;
                    let _v16 = _v14 - _v15;
                    let _v17 = *&(&_v9).timestamp;
                    let _v18 = _v5 - _v17;
                    let _v19 = &(&_v9).tick_cumulative;
                    let _v20 = &(&_v8).tick_cumulative;
                    let _v21 = &(&_v9).tick_cumulative;
                    let _v22 = i64::sub(_v20, _v21);
                    let _v23 = &_v22;
                    let _v24 = i64::new(_v16, false);
                    let _v25 = &_v24;
                    let _v26 = i64::div(_v23, _v25);
                    let _v27 = &_v26;
                    let _v28 = i64::new(_v18, false);
                    let _v29 = &_v28;
                    let _v30 = i64::mul(_v27, _v29);
                    let _v31 = &_v30;
                    let _v32 = i64::add(_v19, _v31);
                    let _v33 = *&(&_v9).seconds_per_liquidity_cumulative;
                    let _v34 = *&(&_v8).seconds_per_liquidity_cumulative;
                    let _v35 = *&(&_v9).seconds_per_liquidity_cumulative;
                    let _v36 = _v34 - _v35;
                    let _v37 = _v18 as u256;
                    let _v38 = _v36 * _v37;
                    let _v39 = _v16 as u256;
                    let _v40 = _v38 / _v39;
                    _v4 = _v33 + _v40;
                    _v3 = _v32
                };
                _v0 = _v4;
                _v1 = _v3;
                break 'l0
            };
            let _v41 = *&(&_v2).tick_cumulative;
            let _v42 = *&(&_v2).seconds_per_liquidity_cumulative;
            return (_v41, _v42)
        };
        (_v1, _v0)
    }
    fun transform(p0: &Observation, p1: u64, p2: u32, p3: u128): Observation {
        let _v0;
        let _v1;
        if (tick::is_negative_tick(p2)) _v0 = i64::new(tick::abs_tick(p2) as u64, true) else _v0 = i64::new(tick::abs_tick(p2) as u64, false);
        let _v2 = _v0;
        let _v3 = *&p0.timestamp;
        let _v4 = p1 - _v3;
        if (p3 == 0u128) _v1 = 1u128 else _v1 = p3;
        let _v5 = &p0.tick_cumulative;
        let _v6 = &_v2;
        let _v7 = i64::new(_v4, false);
        let _v8 = &_v7;
        let _v9 = i64::mul(_v6, _v8);
        let _v10 = &_v9;
        let _v11 = i64::add(_v5, _v10);
        let _v12 = *&p0.seconds_per_liquidity_cumulative;
        let _v13 = (_v4 as u256) << 128u8;
        let _v14 = _v1 as u256;
        let _v15 = _v13 / _v14;
        let _v16 = math::overflow_add_u256(_v12, _v15);
        Observation{timestamp: p1, tick_cumulative: _v11, seconds_per_liquidity_cumulative: _v16, initialized: true}
    }
    friend fun write(p0: &mut vector<Observation>, p1: u16, p2: u64, p3: u32, p4: u128, p5: u16, p6: u16): (u16, u16) {
        let _v0;
        let _v1 = p1 as u64;
        let _v2 = 0x1::vector::borrow<Observation>(freeze(p0), _v1);
        let _v3 = *&_v2.timestamp;
        loop {
            if (!(_v3 == p2)) {
                let _v4;
                if (p6 > p5) {
                    let _v5 = p5 - 1u16;
                    _v4 = p1 == _v5
                } else _v4 = false;
                if (_v4) {
                    _v0 = p6;
                    break
                };
                _v0 = p5;
                break
            };
            return (p1, p5)
        };
        let _v6 = _v0;
        let _v7 = (p1 + 1u16) % _v6;
        let _v8 = transform(_v2, p2, p3, p4);
        let _v9 = _v7 as u64;
        let _v10 = 0x1::vector::borrow_mut<Observation>(p0, _v9);
        *_v10 = _v8;
        (_v7, _v6)
    }
}
