module token_addr::doge_coin {
    use std::string;
    use token_addr::coin_base;
    use std::signer;

    struct DOGE {}

    const DECIMALS: u8 = 8;
    const INITIAL_SUPPLY: u64 = 1000000000; // 1 billion DOGE

    struct DogeCoin has key {
        mint_cap: coin_base::MintCapability<DOGE>,
        burn_cap: coin_base::BurnCapability<DOGE>
    }

    public entry fun initialize(account: &signer) {
        let name = string::utf8(b"Dogecoin");
        let symbol = string::utf8(b"DOGE");
        
        coin_base::initialize<DOGE>(
            account,
            name,
            symbol,
            DECIMALS,
            INITIAL_SUPPLY
        );
    }

    public entry fun register(account: &signer) {
        coin_base::register<DOGE>(account);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        coin_base::transfer<DOGE>(from, to, amount);
    }

    #[view]
    public fun balance(owner: address): u64 {
        coin_base::balance<DOGE>(owner)
    }
}