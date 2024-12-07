module oracle_addr::price_feed {
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event;
    use supra_holder::price_data_pull;

    // DOGE/USDT pair index in Supra Oracle
    const DOGE_USDT_PAIR: u32 = 21; // Example index, verify correct index from Supra docs

    struct PricePair has copy, drop, store {
        pair: u32,
        price: u128,
        decimal: u16,
        round: u64
    }

    struct PriceStorage has key {
        doge_usdt_price: u128,
        doge_usdt_decimal: u16,
        last_update: u64
    }

    struct EmitPrice has key {
        price_pairs: event::EventHandle<vector<PricePair>>
    }

    fun init_module(owner: &signer) {
        move_to(owner, PriceStorage {
            doge_usdt_price: 0,
            doge_usdt_decimal: 0,
            last_update: 0
        });
        move_to(owner, EmitPrice {
            price_pairs: account::new_event_handle<vector<PricePair>>(owner)
        });
    }

    public entry fun get_pair_price(
        account: &signer,
        dkg_state_addr: address,
        oracle_holder_addr: address,
        vote_smr_block_round: vector<vector<u8>>,
        vote_smr_block_timestamp: vector<vector<u8>>,
        vote_smr_block_author: vector<vector<u8>>,
        vote_smr_block_qc_hash: vector<vector<u8>>,
        vote_smr_block_batch_hashes: vector<vector<vector<u8>>>,
        vote_round: vector<u64>,
        min_batch_protocol: vector<vector<u8>>,
        min_batch_txn_hashes: vector<vector<vector<u8>>>,
        min_txn_cluster_hashes: vector<vector<vector<u8>>>,
        min_txn_sender: vector<vector<u8>>,
        min_txn_protocol: vector<vector<u8>>,
        min_txn_tx_sub_type: vector<u8>,
        scc_data_hash: vector<vector<u8>>,
        scc_pair: vector<vector<u32>>,
        scc_prices: vector<vector<u128>>,
        scc_timestamp: vector<vector<u128>>,
        scc_decimals: vector<vector<u16>>,
        scc_qc: vector<vector<u8>>,
        scc_round: vector<u64>,
        scc_id: vector<vector<u8>>,
        scc_member_index: vector<u64>,
        scc_committee_index: vector<u64>,
        batch_idx: vector<u64>,
        txn_idx: vector<u64>,
        cluster_idx: vector<u64>,
        sig: vector<vector<u8>>,
        pair_mask: vector<vector<bool>>
    ) acquires EmitPrice, PriceStorage {
        let price_datas = price_data_pull::verify_oracle_proof(
            account, dkg_state_addr, oracle_holder_addr,
            vote_smr_block_round, vote_smr_block_timestamp, vote_smr_block_author, 
            vote_smr_block_qc_hash, vote_smr_block_batch_hashes, vote_round,
            min_batch_protocol, min_batch_txn_hashes,
            min_txn_cluster_hashes, min_txn_sender, min_txn_protocol, min_txn_tx_sub_type,
            scc_data_hash, scc_pair, scc_prices, scc_timestamp, scc_decimals, 
            scc_qc, scc_round, scc_id, scc_member_index, scc_committee_index,
            batch_idx, txn_idx, cluster_idx, sig, pair_mask
        );

        let price_pairs = vector::empty<PricePair>();
        while (!vector::is_empty(&price_datas)) {
            let price_data = vector::pop_back(&mut price_datas);
            let (cc_pair_index, cc_price, cc_decimal, cc_round) = 
                price_data_pull::price_data_split(&price_data);
            
            // Store DOGE/USDT price
            if (cc_pair_index == DOGE_USDT_PAIR) {
                let storage = borrow_global_mut<PriceStorage>(@oracle_addr);
                storage.doge_usdt_price = cc_price;
                storage.doge_usdt_decimal = cc_decimal;
                storage.last_update = cc_round;
            };
            
            vector::push_back(&mut price_pairs, PricePair {
                pair: cc_pair_index,
                price: cc_price,
                decimal: cc_decimal,
                round: cc_round
            });
        };

        let event_handler = borrow_global_mut<EmitPrice>(@oracle_addr);
        event::emit_event<vector<PricePair>>(&mut event_handler.price_pairs, price_pairs);
    }

    #[view]
    public fun get_doge_usdt_price(): (u128, u16, u64) acquires PriceStorage {
        let storage = borrow_global<PriceStorage>(@oracle_addr);
        (storage.doge_usdt_price, storage.doge_usdt_decimal, storage.last_update)
    }
}