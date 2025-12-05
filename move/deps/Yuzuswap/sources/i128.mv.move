module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::i128 {
    struct I128 has copy, drop, store {
        value: u128,
        is_negative: bool,
    }
    public fun is_negative(p0: &I128): bool {
        *&p0.is_negative
    }
    public fun abs(p0: &I128): u128 {
        *&p0.value
    }
    public fun add(p0: &I128, p1: &I128): I128 {
        let _v0;
        let _v1 = *&p0.is_negative;
        let _v2 = *&p1.is_negative;
        if (_v1 == _v2) {
            let _v3 = *&p0.value;
            let _v4 = *&p1.value;
            let _v5 = _v3 + _v4;
            let _v6 = *&p0.is_negative;
            _v0 = I128{value: _v5, is_negative: _v6}
        } else {
            let _v7;
            let _v8 = *&p0.value;
            let _v9 = *&p1.value;
            if (_v8 > _v9) {
                let _v10 = *&p0.value;
                let _v11 = *&p1.value;
                let _v12 = _v10 - _v11;
                let _v13 = *&p0.is_negative;
                _v7 = I128{value: _v12, is_negative: _v13}
            } else {
                let _v14 = *&p1.value;
                let _v15 = *&p0.value;
                let _v16 = _v14 - _v15;
                let _v17 = *&p1.is_negative;
                _v7 = I128{value: _v16, is_negative: _v17}
            };
            _v0 = _v7
        };
        _v0
    }
    public fun as_u128(p0: &I128): u128 {
        assert!(!*&p0.is_negative, 0);
        *&p0.value
    }
    public fun is_positive(p0: &I128): bool {
        !*&p0.is_negative
    }
    public fun is_zero(p0: &I128): bool {
        *&p0.value == 0u128
    }
    public fun new(p0: u128, p1: bool): I128 {
        I128{value: p0, is_negative: p1}
    }
    public fun sub(p0: &I128, p1: &I128): I128 {
        let _v0;
        let _v1 = *&p0.is_negative;
        let _v2 = *&p1.is_negative;
        if (_v1 == _v2) {
            let _v3;
            let _v4 = *&p0.value;
            let _v5 = *&p1.value;
            if (_v4 > _v5) {
                let _v6 = *&p0.value;
                let _v7 = *&p1.value;
                let _v8 = _v6 - _v7;
                let _v9 = *&p0.is_negative;
                _v3 = I128{value: _v8, is_negative: _v9}
            } else {
                let _v10 = *&p1.value;
                let _v11 = *&p0.value;
                _v3 = I128{value: _v10 - _v11, is_negative: !*&p0.is_negative}
            };
            _v0 = _v3
        } else {
            let _v12 = *&p0.value;
            let _v13 = *&p1.value;
            let _v14 = _v12 + _v13;
            let _v15 = *&p0.is_negative;
            _v0 = I128{value: _v14, is_negative: _v15}
        };
        _v0
    }
    public fun zero(): I128 {
        I128{value: 0u128, is_negative: false}
    }
}
