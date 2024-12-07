
module lending_addr::lending_protocol {
    use std::signer;
    use supra_framework::supra_coin;
    use supra_framework::coin;
    use std::timestamp;
    use std::account;
    use std::error;

    // Error codes
    const ERR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERR_INSUFFICIENT_COLLATERAL: u64 = 2;
    const ERR_NO_ACTIVE_LOAN: u64 = 3;
    const ERR_NO_LENDING: u64 = 4;
    const ERR_INSUFFICIENT_LIQUIDITY: u64 = 5;
    const ERR_NOT_INITIALIZED: u64 = 6;

    // Constants - Simplified for whole numbers
    const LENDING_APR: u64 = 1; // 1% per minute for lending
    const BORROWING_APR: u64 = 2; // 2% per minute for borrowing
    const COLLATERAL_RATIO: u64 = 150; // 150% collateralization required
    const DOGE_PRICE_IN_USDT: u64 = 100; // 1 DOGE = 0.1 USDT (with 3 decimals)

    struct LendingCapability has key {
        signer_cap: account::SignerCapability
    }

    struct LenderInfo has key {
        usdt_deposited: u64,
        deposit_timestamp: u64,
        earned_interest: u64
    }

    struct BorrowerInfo has key {
        doge_collateral: u64,
        usdt_borrowed: u64,
        borrow_timestamp: u64
    }

    struct LendingPool has key {
        total_usdt_deposits: u64,
        total_usdt_borrowed: u64,
        total_doge_collateral: u64,
        owner: address
    }

    public entry fun initialize_pool(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        let (pool_signer, signer_cap) = account::create_resource_account(admin, b"lending_pool");
        coin::register<supra_coin::SupraCoin>(&pool_signer);
        
        move_to(&pool_signer, LendingPool {
            total_usdt_deposits: 0,
            total_usdt_borrowed: 0,
            total_doge_collateral: 0,
            owner: admin_addr
        });
        
        move_to(admin, LendingCapability {
            signer_cap
        });
    }

    public entry fun initialize_lender(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<LenderInfo>(account_addr)) {
            move_to(account, LenderInfo {
                usdt_deposited: 0,
                deposit_timestamp: 0,
                earned_interest: 0
            });
            if (!coin::is_account_registered<supra_coin::SupraCoin>(account_addr)) {
                coin::register<supra_coin::SupraCoin>(account);
            };
        }
    }

    public entry fun initialize_borrower(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<BorrowerInfo>(account_addr)) {
            move_to(account, BorrowerInfo {
                doge_collateral: 0,
                usdt_borrowed: 0,
                borrow_timestamp: 0
            });
            if (!coin::is_account_registered<supra_coin::SupraCoin>(account_addr)) {
                coin::register<supra_coin::SupraCoin>(account);
            };
        }
    }

    fun get_pool_address(): address {
        account::create_resource_address(&@lending_addr, b"lending_pool")
    }

    // Simplified interest calculation
    fun calculate_interest(amount: u64, start_time: u64, rate: u64): u64 {
        if (amount == 0 || start_time == 0) return 0;
        let minutes = (timestamp::now_seconds() - start_time) / 60;
        ((amount * rate * (minutes as u64)) / 100)
    }

    fun calculate_lending_interest(amount: u64, start_time: u64): u64 {
        calculate_interest(amount, start_time, LENDING_APR)
    }

    fun calculate_borrow_interest(amount: u64, start_time: u64): u64 {
        calculate_interest(amount, start_time, BORROWING_APR)
    }

    public entry fun deposit_usdt(account: &signer, amount: u64) 
    acquires LenderInfo, LendingPool {
        let sender_addr = signer::address_of(account);
        assert!(exists<LenderInfo>(sender_addr), error::not_found(ERR_NOT_INITIALIZED));
        
        let pool_addr = get_pool_address();
        coin::transfer<supra_coin::SupraCoin>(account, pool_addr, amount);

        let lender = borrow_global_mut<LenderInfo>(sender_addr);
        if (lender.usdt_deposited == 0) {
            lender.deposit_timestamp = timestamp::now_seconds();
        };
        lender.usdt_deposited = lender.usdt_deposited + amount;

        let pool = borrow_global_mut<LendingPool>(pool_addr);
        pool.total_usdt_deposits = pool.total_usdt_deposits + amount;
    }

    public entry fun withdraw_usdt(account: &signer, amount: u64) 
    acquires LenderInfo, LendingPool, LendingCapability {
        let sender_addr = signer::address_of(account);
        let pool_addr = get_pool_address();
        
        assert!(exists<LenderInfo>(sender_addr), error::not_found(ERR_NOT_INITIALIZED));
        let lender = borrow_global_mut<LenderInfo>(sender_addr);
        
        let interest = calculate_lending_interest(lender.usdt_deposited, lender.deposit_timestamp);
        let total_available = lender.usdt_deposited + interest;
        assert!(amount <= total_available, error::invalid_argument(ERR_INSUFFICIENT_BALANCE));

        let lending_cap = borrow_global<LendingCapability>(@lending_addr);
        let pool_signer = account::create_signer_with_capability(&lending_cap.signer_cap);

        if (amount == total_available) {
            lender.usdt_deposited = 0;
            lender.deposit_timestamp = 0;
        } else {
            lender.usdt_deposited = lender.usdt_deposited - amount;
        };
        lender.earned_interest = lender.earned_interest + interest;

        let pool = borrow_global_mut<LendingPool>(pool_addr);
        pool.total_usdt_deposits = pool.total_usdt_deposits - amount;

        coin::transfer<supra_coin::SupraCoin>(&pool_signer, sender_addr, amount);
    }

    public entry fun deposit_collateral(account: &signer, amount: u64) 
    acquires BorrowerInfo, LendingPool {
        let sender_addr = signer::address_of(account);
        let pool_addr = get_pool_address();
        
        assert!(exists<BorrowerInfo>(sender_addr), error::not_found(ERR_NOT_INITIALIZED));
        
        coin::transfer<supra_coin::SupraCoin>(account, pool_addr, amount);

        let borrower = borrow_global_mut<BorrowerInfo>(sender_addr);
        borrower.doge_collateral = borrower.doge_collateral + amount;

        let pool = borrow_global_mut<LendingPool>(pool_addr);
        pool.total_doge_collateral = pool.total_doge_collateral + amount;
    }

    public entry fun borrow_usdt(account: &signer, amount: u64) 
    acquires BorrowerInfo, LendingPool, LendingCapability {
        let sender_addr = signer::address_of(account);
        let pool_addr = get_pool_address();
        
        assert!(exists<BorrowerInfo>(sender_addr), error::not_found(ERR_NOT_INITIALIZED));
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        
        assert!(amount <= (pool.total_usdt_deposits - pool.total_usdt_borrowed), 
            error::invalid_argument(ERR_INSUFFICIENT_LIQUIDITY));

        let borrower = borrow_global_mut<BorrowerInfo>(sender_addr);
        let collateral_value = (borrower.doge_collateral * DOGE_PRICE_IN_USDT) / 1000;
        let max_borrow = (collateral_value * 100) / COLLATERAL_RATIO;
        
        assert!(amount <= max_borrow, error::invalid_argument(ERR_INSUFFICIENT_COLLATERAL));

        let lending_cap = borrow_global<LendingCapability>(@lending_addr);
        let pool_signer = account::create_signer_with_capability(&lending_cap.signer_cap);

        borrower.usdt_borrowed = borrower.usdt_borrowed + amount;
        borrower.borrow_timestamp = timestamp::now_seconds();

        pool.total_usdt_borrowed = pool.total_usdt_borrowed + amount;

        coin::transfer<supra_coin::SupraCoin>(&pool_signer, sender_addr, amount);
    }

    // Updated repay function
public entry fun repay_loan(
    account: &signer,
    amount: u64
) acquires BorrowerInfo, LendingPool {
    let sender_addr = signer::address_of(account);
    let pool_addr = get_pool_address();
    
    // Check if borrower exists and has a loan
    assert!(exists<BorrowerInfo>(sender_addr), error::not_found(ERR_NOT_INITIALIZED));
    let borrower = borrow_global_mut<BorrowerInfo>(sender_addr);
    assert!(borrower.usdt_borrowed > 0, error::invalid_state(ERR_NO_ACTIVE_LOAN));

    // Calculate minimum repayment needed
    let principal = borrower.usdt_borrowed;
    let current_time = timestamp::now_seconds();
    let time_elapsed = current_time - borrower.borrow_timestamp;
    let minutes = (time_elapsed / 60);
    let interest = ((principal * 2 * minutes) / 100);
    let minimum_repayment = principal + interest;

    // Allow repayment if amount is greater than or equal to minimum
    assert!(amount >= minimum_repayment, error::invalid_argument(ERR_INSUFFICIENT_BALANCE));

    // Transfer USDT to pool
    coin::transfer<supra_coin::SupraCoin>(account, pool_addr, amount);

    // Clear the loan completely
    borrower.usdt_borrowed = 0;
    borrower.borrow_timestamp = 0;

    // Update pool
    let pool = borrow_global_mut<LendingPool>(pool_addr);
    pool.total_usdt_borrowed = pool.total_usdt_borrowed - principal;
}

    public entry fun withdraw_collateral(account: &signer, amount: u64) 
    acquires BorrowerInfo, LendingPool, LendingCapability {
        let sender_addr = signer::address_of(account);
        let pool_addr = get_pool_address();
        
        let borrower = borrow_global_mut<BorrowerInfo>(sender_addr);
        assert!(borrower.usdt_borrowed == 0, error::invalid_state(ERR_INSUFFICIENT_COLLATERAL));
        assert!(amount <= borrower.doge_collateral, error::invalid_argument(ERR_INSUFFICIENT_BALANCE));

        let lending_cap = borrow_global<LendingCapability>(@lending_addr);
        let pool_signer = account::create_signer_with_capability(&lending_cap.signer_cap);

        borrower.doge_collateral = borrower.doge_collateral - amount;

        let pool = borrow_global_mut<LendingPool>(pool_addr);
        pool.total_doge_collateral = pool.total_doge_collateral - amount;

        coin::transfer<supra_coin::SupraCoin>(&pool_signer, sender_addr, amount);
    }

    #[view]
    public fun get_balance(addr: address): u64 {
        coin::balance<supra_coin::SupraCoin>(addr)
    }

    #[view]
    public fun get_lender_info(addr: address): (u64, u64, u64) acquires LenderInfo {
        assert!(exists<LenderInfo>(addr), error::not_found(ERR_NOT_INITIALIZED));
        let lender = borrow_global<LenderInfo>(addr);
        (
            lender.usdt_deposited,
            calculate_lending_interest(lender.usdt_deposited, lender.deposit_timestamp),
            lender.earned_interest
        )
    }

    #[view]
    public fun get_borrower_info(addr: address): (u64, u64, u64, u64, u64) acquires BorrowerInfo {
        assert!(exists<BorrowerInfo>(addr), error::not_found(ERR_NOT_INITIALIZED));
        let borrower = borrow_global<BorrowerInfo>(addr);
        
        let time_elapsed = timestamp::now_seconds() - borrower.borrow_timestamp;
        let interest = calculate_borrow_interest(borrower.usdt_borrowed, borrower.borrow_timestamp);
        let total_owed = borrower.usdt_borrowed + interest;

        (
            borrower.doge_collateral,
            borrower.usdt_borrowed,
            interest,
            total_owed,
            time_elapsed
        )
    }

    #[view]
    public fun get_pool_info(): (u64, u64, u64) acquires LendingPool {
        let pool = borrow_global<LendingPool>(get_pool_address());
        (
            pool.total_usdt_deposits,
            pool.total_usdt_borrowed,
            pool.total_doge_collateral
        )
    }
}