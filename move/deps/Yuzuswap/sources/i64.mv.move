module yuzuswap::i64 {
    struct I64 has copy, drop, store {
        value: u64,
        is_negative: bool
    }

    public fun is_negative(p0: &I64): bool {
        *&p0.is_negative
    }

    public fun abs(p0: &I64): u64 {
        *&p0.value
    }

    public fun add(p0: &I64, p1: &I64): I64 {
        let _v0;
        let _v1 = *&p0.is_negative;
        let _v2 = *&p1.is_negative;
        if (_v1 == _v2) {
            let _v3 = *&p0.value;
            let _v4 = *&p1.value;
            let _v5 = _v3 + _v4;
            let _v6 = *&p0.is_negative;
            _v0 = I64 { value: _v5, is_negative: _v6 }
        } else {
            let _v7;
            let _v8 = *&p0.value;
            let _v9 = *&p1.value;
            if (_v8 > _v9) {
                let _v10 = *&p0.value;
                let _v11 = *&p1.value;
                let _v12 = _v10 - _v11;
                let _v13 = *&p0.is_negative;
                _v7 = I64 { value: _v12, is_negative: _v13 }
            } else {
                let _v14 = *&p1.value;
                let _v15 = *&p0.value;
                let _v16 = _v14 - _v15;
                let _v17 = *&p1.is_negative;
                _v7 = I64 { value: _v16, is_negative: _v17 }
            };
            _v0 = _v7
        };
        _v0
    }

    public fun as_u64(p0: &I64): u64 {
        let _v0;
        if (!*&p0.is_negative) _v0 = true else _v0 = *&p0.value == 0;
        assert!(_v0, 0);
        *&p0.value
    }

    public fun compare(p0: &I64, p1: &I64): u8 {
        let _v0;
        if (eq(p0, p1)) _v0 = 0u8
        else {
            let _v1;
            if (lt(p0, p1)) _v1 = 1u8
            else _v1 = 2u8;
            _v0 = _v1
        };
        _v0
    }

    public fun div(p0: &I64, p1: &I64): I64 {
        assert!(!is_zero(p1), 1);
        let _v0 = *&p0.value;
        let _v1 = *&p1.value;
        let _v2 = _v0 / _v1;
        let _v3 = *&p0.is_negative;
        let _v4 = *&p1.is_negative;
        I64 { value: _v2, is_negative: _v3 != _v4 }
    }

    public fun eq(p0: &I64, p1: &I64): bool {
        let _v0;
        let _v1 = *&p0.value;
        let _v2 = *&p1.value;
        if (_v1 == _v2) {
            let _v3 = *&p0.is_negative;
            let _v4 = *&p1.is_negative;
            _v0 = _v3 == _v4
        } else _v0 = false;
        _v0
    }

    public fun gt(p0: &I64, p1: &I64): bool {
        let _v0;
        let _v1;
        if (*&p0.is_negative) _v1 = !*&p1.is_negative else _v1 = false;
        if (_v1) _v0 = false
        else {
            let _v2;
            let _v3;
            if (!*&p0.is_negative) _v3 = *&p1.is_negative
            else _v3 = false;
            if (_v3) _v2 = true
            else {
                let _v4;
                let _v5;
                if (*&p0.is_negative) _v5 = *&p1.is_negative
                else _v5 = false;
                if (_v5) {
                    let _v6 = *&p0.value;
                    let _v7 = *&p1.value;
                    _v4 = _v6 < _v7
                } else {
                    let _v8 = *&p0.value;
                    let _v9 = *&p1.value;
                    _v4 = _v8 > _v9
                };
                _v2 = _v4
            };
            _v0 = _v2
        };
        _v0
    }

    public fun gte(p0: &I64, p1: &I64): bool {
        let _v0;
        if (gt(p0, p1)) _v0 = true else _v0 = eq(p0, p1);
        _v0
    }

    public fun is_positive(p0: &I64): bool {
        !*&p0.is_negative
    }

    public fun is_zero(p0: &I64): bool {
        *&p0.value == 0
    }

    public fun lt(p0: &I64, p1: &I64): bool {
        let _v0;
        let _v1;
        if (*&p0.is_negative) _v1 = !*&p1.is_negative else _v1 = false;
        if (_v1) _v0 = true
        else {
            let _v2;
            let _v3;
            if (!*&p0.is_negative) _v3 = *&p1.is_negative
            else _v3 = false;
            if (_v3) _v2 = false
            else {
                let _v4;
                let _v5;
                if (*&p0.is_negative) _v5 = *&p1.is_negative
                else _v5 = false;
                if (_v5) {
                    let _v6 = *&p0.value;
                    let _v7 = *&p1.value;
                    _v4 = _v6 > _v7
                } else {
                    let _v8 = *&p0.value;
                    let _v9 = *&p1.value;
                    _v4 = _v8 < _v9
                };
                _v2 = _v4
            };
            _v0 = _v2
        };
        _v0
    }

    public fun lte(p0: &I64, p1: &I64): bool {
        let _v0;
        if (lt(p0, p1)) _v0 = true else _v0 = eq(p0, p1);
        _v0
    }

    public fun mod(p0: &I64, p1: &I64): I64 {
        assert!(!is_zero(p1), 1);
        let _v0 = *&p0.value;
        let _v1 = *&p1.value;
        let _v2 = _v0 % _v1;
        let _v3 = *&p0.is_negative;
        I64 { value: _v2, is_negative: _v3 }
    }

    public fun mul(p0: &I64, p1: &I64): I64 {
        let _v0;
        if (is_zero(p0)) _v0 = true else _v0 = is_zero(p1);
        if (_v0) return zero();
        let _v1 = *&p0.value;
        let _v2 = *&p1.value;
        let _v3 = _v1 * _v2;
        let _v4 = *&p0.is_negative;
        let _v5 = *&p1.is_negative;
        I64 { value: _v3, is_negative: _v4 != _v5 }
    }

    public fun new(p0: u64, p1: bool): I64 {
        I64 { value: p0, is_negative: p1 }
    }

    public fun sub(p0: &I64, p1: &I64): I64 {
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
                _v3 = I64 { value: _v8, is_negative: _v9 }
            } else {
                let _v10 = *&p1.value;
                let _v11 = *&p0.value;
                _v3 = I64 { value: _v10 - _v11, is_negative: !*&p0.is_negative }
            };
            _v0 = _v3
        } else {
            let _v12 = *&p0.value;
            let _v13 = *&p1.value;
            let _v14 = _v12 + _v13;
            let _v15 = *&p0.is_negative;
            _v0 = I64 { value: _v14, is_negative: _v15 }
        };
        _v0
    }

    public fun zero(): I64 {
        I64 { value: 0, is_negative: false }
    }
}

