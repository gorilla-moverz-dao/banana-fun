module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::tick {
    public fun abs_tick(p0: u32): u32 {
        let _v0;
        if (p0 >= 443636u32) _v0 = p0 - 443636u32 else _v0 = 443636u32 - p0;
        _v0
    }
    public fun is_negative_tick(p0: u32): bool {
        p0 < 443636u32
    }
    public fun is_spaced_tick(p0: u32, p1: u32): bool {
        abs_tick(p0) % p1 == 0u32
    }
    public fun is_tick_spaced(p0: u32, p1: u32): bool {
        p0 % p1 == 0u32
    }
    public fun max_tick(): u32 {
        887272u32
    }
    public fun min_tick(): u32 {
        0u32
    }
    public fun tick_adjustment(p0: u32): u32 {
        443636u32 % p0
    }
    public fun tick_spacing_to_max_liquidity_per_tick(p0: u32): u128 {
        let _v0 = 443636u32 % p0;
        let _v1 = ((887272u32 / p0 * p0 - _v0) / p0 + 1u32) as u128;
        340282366920938463463374607431768211455u128 / _v1
    }
    public fun zero_tick(): u32 {
        443636u32
    }
}
