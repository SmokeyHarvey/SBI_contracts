module token_addr::coin_base {
    use std::string;
    use std::signer;
    use std::error;
    
    const ENO_CAPABILITIES: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const EUNAUTHORIZED: u64 = 4;

    struct CoinInfo<phantom CoinType> has key {
        name: string::String,
        symbol: string::String,
        decimals: u8,
        supply: u64
    }

    struct CoinStore<phantom CoinType> has key {
        balance: u64
    }

    struct MintCapability<phantom CoinType> has key, store {}
    struct BurnCapability<phantom CoinType> has key, store {}

    public fun register<CoinType>(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<CoinStore<CoinType>>(addr), error::already_exists(EALREADY_INITIALIZED));
        move_to(account, CoinStore<CoinType> { balance: 0 });
    }

    public fun balance<CoinType>(owner: address): u64 acquires CoinStore {
        borrow_global<CoinStore<CoinType>>(owner).balance
    }

    public fun transfer<CoinType>(
        from: &signer,
        to: address,
        amount: u64
    ) acquires CoinStore {
        let from_addr = signer::address_of(from);
        assert!(exists<CoinStore<CoinType>>(to), error::not_found(ENO_CAPABILITIES));
        
        let from_balance = &mut borrow_global_mut<CoinStore<CoinType>>(from_addr).balance;
        assert!(*from_balance >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
        *from_balance = *from_balance - amount;

        let to_balance = &mut borrow_global_mut<CoinStore<CoinType>>(to).balance;
        *to_balance = *to_balance + amount;
    }

    public fun mint<CoinType>(
        account: &signer,
        amount: u64
    ): bool acquires CoinStore, CoinInfo {
        let addr = signer::address_of(account);
        assert!(exists<MintCapability<CoinType>>(addr), error::not_found(EUNAUTHORIZED));
        
        let coin_store = borrow_global_mut<CoinStore<CoinType>>(addr);
        coin_store.balance = coin_store.balance + amount;

        let coin_info = borrow_global_mut<CoinInfo<CoinType>>(@token_addr);
        coin_info.supply = coin_info.supply + amount;
        true
    }

    public fun burn<CoinType>(
        account: &signer,
        amount: u64
    ): bool acquires CoinStore, CoinInfo {
        let addr = signer::address_of(account);
        assert!(exists<BurnCapability<CoinType>>(addr), error::not_found(EUNAUTHORIZED));
        
        let coin_store = borrow_global_mut<CoinStore<CoinType>>(addr);
        assert!(coin_store.balance >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
        coin_store.balance = coin_store.balance - amount;

        let coin_info = borrow_global_mut<CoinInfo<CoinType>>(@token_addr);
        coin_info.supply = coin_info.supply - amount;
        true
    }
}