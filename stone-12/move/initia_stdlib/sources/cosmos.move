/// This module provides interfaces to allow CosmosMessage 
/// execution after the move execution finished.
module initia_std::cosmos {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::object::Object;
    use std::fungible_asset::Metadata;
    use std::collection::{Collection};

    public entry fun delegate (
        delegator: &signer, 
        validator: String, 
        metadata: Object<Metadata>,
        amount: u64,
    ) {
        delegate_internal(
            signer::address_of(delegator),
            *string::bytes(&validator),
            &metadata,
            amount,
        )
    }

    public entry fun fund_community_pool (
        sender: &signer, 
        metadata: Object<Metadata>,
        amount: u64,
    ) {
        fund_community_pool_internal(
            signer::address_of(sender),
            &metadata,
            amount,
        )
    }

    /// ICS20 ibc transfer
    /// https://github.com/cosmos/ibc/tree/main/spec/app/ics-020-fungible-token-transfer
    public entry fun transfer (
        sender: &signer,
        receiver: String,
        metadata: Object<Metadata>,
        token_amount: u64,
        source_port: String,
        source_channel: String,
        revision_number: u64,
        revision_height: u64,
        timeout_timestamp: u64,
        memo: String,
    ) {
        transfer_internal(
            signer::address_of(sender),
            *string::bytes(&receiver),
            &metadata,
            token_amount,
            *string::bytes(&source_port),
            *string::bytes(&source_channel),
            revision_number,
            revision_height,
            timeout_timestamp,
            *string::bytes(&memo),
        )
    }

    /// ICS721 ibc nft_transfer
    /// https://github.com/cosmos/ibc/tree/main/spec/app/ics-721-nft-transfer
    public entry fun nft_transfer (
        sender: &signer,
        receiver: String,
        collection: Object<Collection>,
        token_ids: vector<String>,
        source_port: String,
        source_channel: String,
        revision_number: u64,
        revision_height: u64,
        timeout_timestamp: u64,
        memo: String,
    ) {
        nft_transfer_internal(
            signer::address_of(sender),
            *string::bytes(&receiver),
            &collection,
            vector::map_ref(&token_ids, |v| *string::bytes(v)),
            *string::bytes(&source_port),
            *string::bytes(&source_channel),
            revision_number,
            revision_height,
            timeout_timestamp,
            *string::bytes(&memo),
        )
    }

    /// ICS29 ibc relayer fee
    /// https://github.com/cosmos/ibc/tree/main/spec/app/ics-029-fee-payment
    public entry fun pay_fee (
        sender: &signer,
        source_port: String,
        source_channel: String,
        recv_fee_metadata: Object<Metadata>,
        recv_fee_amount: u64,
        ack_fee_metadata: Object<Metadata>,
        ack_fee_amount: u64,
        timeout_fee_metadata: Object<Metadata>,
        timeout_fee_amount: u64,
    ) {
        pay_fee_internal(
            signer::address_of(sender),
            *string::bytes(&source_port),
            *string::bytes(&source_channel),
            &recv_fee_metadata,
            recv_fee_amount,
            &ack_fee_metadata,
            ack_fee_amount,
            &timeout_fee_metadata,
            timeout_fee_amount,
        )
    }

    public entry fun initiate_token_deposit (
        sender: &signer,
        bridge_id: u64,
        to: address,
        metadata: Object<Metadata>,
        amount: u64,
        data: vector<u8>,
    ) {
        initiate_token_deposit_internal(
            bridge_id,
            signer::address_of(sender),
            to,
            &metadata,
            amount,
            data,
        )
    }

    native fun delegate_internal (
        delegator: address, 
        validator: vector<u8>, 
        metadata: &Object<Metadata>,
        amount: u64,
    );

    native fun fund_community_pool_internal (
        sender: address, 
        metadata: &Object<Metadata>,
        amount: u64,
    );

    native fun transfer_internal (
        sender: address,
        receiver: vector<u8>,
        metadata: &Object<Metadata>,
        token_amount: u64,
        source_port: vector<u8>,
        source_channel: vector<u8>,
        revision_number: u64,
        revision_height: u64,
        timeout_timestamp: u64,
        memo: vector<u8>,
    );

    native fun nft_transfer_internal (
        sender: address,
        receiver: vector<u8>,
        collection: &Object<Collection>,
        token_ids: vector<vector<u8>>,
        source_port: vector<u8>,
        source_channel: vector<u8>,
        revision_number: u64,
        revision_height: u64,
        timeout_timestamp: u64,
        memo: vector<u8>,
    );

    native fun pay_fee_internal (
        sender: address,
        source_port: vector<u8>,
        source_channel: vector<u8>,
        recv_fee_metadata: &Object<Metadata>,
        recv_fee_amount: u64,
        ack_fee_metadata: &Object<Metadata>,
        ack_fee_amount: u64,
        timeout_fee_metadata: &Object<Metadata>,
        timeout_fee_amount: u64,
    );

    native fun initiate_token_deposit_internal (
        bridge_id: u64,
        sender: address,
        to: address,
        metadata: &Object<Metadata>,
        amount: u64,
        data: vector<u8>,
    );
}