module 0x46566b4a16a1261ab400ab5b9067de84ba152b5eb4016b217187f2a2ca980c5a::fa_helper {
    use 0x1::comparator;
    use 0x1::fungible_asset;
    use 0x1::object;
    use 0x1::string;
    fun compare(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>): comparator::Result {
        let _v0 = fungible_asset::symbol<fungible_asset::Metadata>(p0);
        let _v1 = fungible_asset::symbol<fungible_asset::Metadata>(p1);
        let _v2 = &_v0;
        let _v3 = &_v1;
        let _v4 = comparator::compare<string::String>(_v2, _v3);
        if (!comparator::is_equal(&_v4)) return _v4;
        let _v5 = object::object_address<fungible_asset::Metadata>(&p0);
        let _v6 = object::object_address<fungible_asset::Metadata>(&p1);
        let _v7 = &_v5;
        let _v8 = &_v6;
        comparator::compare<address>(_v7, _v8)
    }
    public fun is_sorted(p0: object::Object<fungible_asset::Metadata>, p1: object::Object<fungible_asset::Metadata>): bool {
        let _v0 = compare(p0, p1);
        assert!(!comparator::is_equal(&_v0), 3000);
        comparator::is_smaller_than(&_v0)
    }
}
