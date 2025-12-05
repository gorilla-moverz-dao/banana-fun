module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::unsafe_math {
    fun mul_div(p0: u256, p1: u256, p2: u256): u256 {
        p0 * p1 / p2
    }
    public fun mul_div_rounding_up(p0: u256, p1: u256, p2: u256): u256 {
        let _v0 = mul_div(p0, p1, p2);
        if (mul_mod(p0, p1, p2) > 0u256) _v0 = _v0 + 1u256;
        _v0
    }
    fun mul_mod(p0: u256, p1: u256, p2: u256): u256 {
        p0 * p1 % p2
    }
}
