module token_addr::usdt_coin {
    use std::string;
    use token_addr::coin_base;
    use std::signer;

    struct USDT {}

    const DECIMALS: u8 = 6;  // USDT uses 6 decimals
    const INITIAL_SUPPLY: u64 = 1000000000000; // 1 billion USDT

    struct USDTCoin has key {
        mint_cap: coin_base::MintCapability<USDT>,
        burn_cap: coin_base::BurnCapability<USDT>
    }

    public entry fun initialize(account: &signer) {
        let name = string::utf8(b"Tether USD");
        let symbol = string::utf8(b"USDT");
        
        coin_base::initialize<USDT>(
            account,
            name,
            symbol,
            DECIMALS,
            INITIAL_SUPPLY
        );
    }

    public entry fun register(account: &signer) {
        coin_base::register<USDT>(account);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        coin_base::transfer<USDT>(from, to, amount);
    }

    #[view]
    public fun balance(owner: address): u64 {
        coin_base::balance<USDT>(owner)
    }
}