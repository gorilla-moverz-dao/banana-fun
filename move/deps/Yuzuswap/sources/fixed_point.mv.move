module yuzuswap::fixed_point {
    public fun q64(): u128 {
        18446744073709551616u128
    }
    public fun q80(): u128 {
        1208925819614629174706176u128
    }
    public fun u128_to_x80_u128(p0: u128): u128 {
        p0 << 80u8
    }
    public fun u128_to_x80_u256(p0: u128): u256 {
        (p0 as u256) << 80u8
    }
    public fun u256_to_x80_u256(p0: u256): u256 {
        p0 << 80u8
    }
    public fun u64_to_x64_u128(p0: u64): u128 {
        (p0 as u128) << 64u8
    }
    public fun u64_to_x64_u256(p0: u64): u256 {
        (p0 as u256) << 64u8
    }
    public fun u64_to_x80_u256(p0: u64): u256 {
        (p0 as u256) << 80u8
    }
}
