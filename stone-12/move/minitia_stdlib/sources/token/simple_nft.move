/// This defines a minimally viable nft for no-code solutions akin the the original nft at
/// minitia_std::nft module.
/// IBC transfer will only support nft that is created by simple_nft
/// The key features are:
/// * Base nft and collection features
/// * Only owner can burn nft
/// * Freeze is not available
/// * Standard object-based transfer and events
/// * Metadata property type
module minitia_std::simple_nft {
    use std::error;
    use std::option::{Self, Option};
    use std::string::String;
    use std::signer;
    use minitia_std::object::{Self, ConstructorRef, Object};
    use minitia_std::collection;
    use minitia_std::property_map;
    use minitia_std::royalty;
    use minitia_std::nft;
    use minitia_std::decimal128::Decimal128;

    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    /// The nft does not exist
    const ENFT_DOES_NOT_EXIST: u64 = 2;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 3;
    /// The field being changed is not mutable
    const EFIELD_NOT_MUTABLE: u64 = 4;
    /// The provided signer is not the owner
    const ENOT_OWNER: u64 = 5;
    /// The property map being mutated is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 6;

    /// Storage state for managing the no-code Collection.
    struct SimpleNftCollection has key {
        /// Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        /// Used to mutate royalties
        royalty_mutator_ref: Option<royalty::MutatorRef>,
        /// Determines if the creator can mutate the collection's description
        mutable_description: bool,
        /// Determines if the creator can mutate the collection's uri
        mutable_uri: bool,
        /// Determines if the creator can mutate nft descriptions
        mutable_nft_description: bool,
        /// Determines if the creator can mutate nft properties
        mutable_nft_properties: bool,
        /// Determines if the creator can mutate nft uris
        mutable_nft_uri: bool,
    }

    /// Storage state for managing the no-code Nft.
    struct SimpleNft has key {
        /// Used to burn.
        burn_ref: nft::BurnRef,
        /// Used to mutate fields
        mutator_ref: Option<nft::MutatorRef>,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
    }

    /// Create a new collection
    public entry fun create_collection(
        creator: &signer,
        description: String,
        max_supply: Option<u64>,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_nft_description: bool,
        mutable_nft_properties: bool,
        mutable_nft_uri: bool,
        royalty: Decimal128,
    ) {
        create_collection_object(
            creator,
            description,
            max_supply,
            name,
            uri,
            mutable_description,
            mutable_royalty,
            mutable_uri,
            mutable_nft_description,
            mutable_nft_properties,
            mutable_nft_uri,
            royalty,
        );
    }

    public fun create_collection_object(
        creator: &signer,
        description: String,
        max_supply: Option<u64>,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_nft_description: bool,
        mutable_nft_properties: bool,
        mutable_nft_uri: bool,
        royalty: Decimal128,
    ): Object<SimpleNftCollection> {
        let creator_addr = signer::address_of(creator);
        let royalty = royalty::create(royalty, creator_addr);
        let constructor_ref = if (option::is_some(&max_supply)) {
            collection::create_fixed_collection(
                creator,
                description,
                option::extract(&mut max_supply),
                name,
                option::some(royalty),
                uri,
            )
        } else {
            collection::create_unlimited_collection(
                creator,
                description,
                name,
                option::some(royalty),
                uri,
            )
        };

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = if (mutable_description || mutable_uri) {
            option::some(collection::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let royalty_mutator_ref = if (mutable_royalty) {
            option::some(royalty::generate_mutator_ref(object::generate_extend_ref(&constructor_ref)))
        } else {
            option::none()
        };

        let simple_nft_collection = SimpleNftCollection {
            mutator_ref,
            royalty_mutator_ref,
            mutable_description,
            mutable_uri,
            mutable_nft_description,
            mutable_nft_properties,
            mutable_nft_uri,
        };
        move_to(&object_signer, simple_nft_collection);
        object::object_from_constructor_ref(&constructor_ref)
    }

    /// With an existing collection, directly mint a viable nft into the creators account.
    public entry fun mint(
        creator: &signer,
        collection: String,
        description: String,
        token_id: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        to: Option<address>,
    ) acquires SimpleNftCollection {
        let nft_object = mint_nft_object(
            creator, collection, description, 
            token_id, uri, property_keys, property_types, property_values,
        );
        if (option::is_some(&to)) {
            object::transfer(creator, nft_object, option::extract(&mut to));
        }
    }

    /// Mint a nft into an existing collection, and retrieve the object / address of the nft.
    public fun mint_nft_object(
        creator: &signer,
        collection: String,
        description: String,
        token_id: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
    ): Object<SimpleNft> acquires SimpleNftCollection {
        let constructor_ref = mint_internal(
            creator,
            collection,
            description,
            token_id,
            uri,
            property_keys,
            property_types,
            property_values,
        );

        object::object_from_constructor_ref(&constructor_ref)
    }

    fun mint_internal(
        creator: &signer,
        collection: String,
        description: String,
        token_id: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
    ): ConstructorRef acquires SimpleNftCollection {
        let constructor_ref = nft::create(
                creator,
                collection,
                description,
                token_id,
                option::none(),
                uri,
            );

        let object_signer = object::generate_signer(&constructor_ref);

        let collection_obj = collection_object(creator, &collection);
        let collection = borrow_collection(collection_obj);

        let mutator_ref = if (
            collection.mutable_nft_description
                || collection.mutable_nft_uri
        ) {
            option::some(nft::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let burn_ref = nft::generate_burn_ref(&constructor_ref);

        let simple_nft = SimpleNft {
            burn_ref,
            mutator_ref,
            property_mutator_ref: property_map::generate_mutator_ref(&constructor_ref),
        };
        move_to(&object_signer, simple_nft);

        let properties = property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);

        constructor_ref
    }

    // Nft accessors

    inline fun borrow<T: key>(nft: Object<T>): &SimpleNft {
        let nft_address = object::object_address(nft);
        assert!(
            exists<SimpleNft>(nft_address),
            error::not_found(ENFT_DOES_NOT_EXIST),
        );
        borrow_global<SimpleNft>(nft_address)
    }

    #[view]
    public fun are_properties_mutable<T: key>(nft: Object<T>): bool acquires SimpleNftCollection {
        let collection = nft::collection_object(nft);
        borrow_collection(collection).mutable_nft_properties
    }

    #[view]
    public fun is_mutable_description<T: key>(nft: Object<T>): bool acquires SimpleNftCollection {
        is_mutable_collection_nft_description(nft::collection_object(nft))
    }

    #[view]
    public fun is_mutable_uri<T: key>(nft: Object<T>): bool acquires SimpleNftCollection {
        is_mutable_collection_nft_uri(nft::collection_object(nft))
    }

    // Nft mutators

    inline fun authorized_borrow<T: key>(nft: Object<T>, creator: &signer): &SimpleNft {
        let nft_address = object::object_address(nft);
        assert!(
            exists<SimpleNft>(nft_address),
            error::not_found(ENFT_DOES_NOT_EXIST),
        );

        assert!(
            nft::creator(nft) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
        borrow_global<SimpleNft>(nft_address)
    }

    public entry fun burn<T: key>(owner: &signer, nft: Object<T>) acquires SimpleNft {
        let nft_address = object::object_address(nft);
        assert!(
            exists<SimpleNft>(nft_address),
            error::not_found(ENFT_DOES_NOT_EXIST),
        );
        assert!(
            object::owns(nft, signer::address_of(owner)),
            error::permission_denied(ENOT_OWNER),
        );

        let simple_nft = move_from<SimpleNft>(object::object_address(nft));
        let SimpleNft {
            burn_ref,
            mutator_ref: _,
            property_mutator_ref,
        } = simple_nft;
        property_map::burn(property_mutator_ref);
        nft::burn(burn_ref);
    }

    public entry fun set_description<T: key>(
        creator: &signer,
        nft: Object<T>,
        description: String,
    ) acquires SimpleNftCollection, SimpleNft {
        assert!(
            is_mutable_description(nft),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let simple_nft = authorized_borrow(nft, creator);
        nft::set_description(option::borrow(&simple_nft.mutator_ref), description);
    }

    public entry fun set_uri<T: key>(
        creator: &signer,
        nft: Object<T>,
        uri: String,
    ) acquires SimpleNftCollection, SimpleNft {
        assert!(
            is_mutable_uri(nft),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let simple_nft = authorized_borrow(nft, creator);
        nft::set_uri(option::borrow(&simple_nft.mutator_ref), uri);
    }

    public entry fun add_property<T: key>(
        creator: &signer,
        nft: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires SimpleNftCollection, SimpleNft {
        let simple_nft = authorized_borrow(nft, creator);
        assert!(
            are_properties_mutable(nft),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add(&simple_nft.property_mutator_ref, key, type, value);
    }

    public entry fun add_typed_property<T: key, V: drop>(
        creator: &signer,
        nft: Object<T>,
        key: String,
        value: V,
    ) acquires SimpleNftCollection, SimpleNft {
        let simple_nft = authorized_borrow(nft, creator);
        assert!(
            are_properties_mutable(nft),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add_typed(&simple_nft.property_mutator_ref, key, value);
    }

    public entry fun remove_property<T: key>(
        creator: &signer,
        nft: Object<T>,
        key: String,
    ) acquires SimpleNftCollection, SimpleNft {
        let simple_nft = authorized_borrow(nft, creator);
        assert!(
            are_properties_mutable(nft),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::remove(&simple_nft.property_mutator_ref, &key);
    }

    public entry fun update_property<T: key>(
        creator: &signer,
        nft: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires SimpleNftCollection, SimpleNft {
        let simple_nft = authorized_borrow(nft, creator);
        assert!(
            are_properties_mutable(nft),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update(&simple_nft.property_mutator_ref, &key, type, value);
    }

    public entry fun update_typed_property<T: key, V: drop>(
        creator: &signer,
        nft: Object<T>,
        key: String,
        value: V,
    ) acquires SimpleNftCollection, SimpleNft {
        let simple_nft = authorized_borrow(nft, creator);
        assert!(
            are_properties_mutable(nft),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update_typed(&simple_nft.property_mutator_ref, &key, value);
    }

    // Collection accessors

    inline fun collection_object(creator: &signer, name: &String): Object<SimpleNftCollection> {
        let collection_addr = collection::create_collection_address(signer::address_of(creator), name);
        object::address_to_object<SimpleNftCollection>(collection_addr)
    }

    inline fun borrow_collection<T: key>(nft: Object<T>): &SimpleNftCollection {
        let collection_address = object::object_address(nft);
        assert!(
            exists<SimpleNftCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<SimpleNftCollection>(collection_address)
    }

    public fun is_mutable_collection_description<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        borrow_collection(collection).mutable_description
    }

    public fun is_mutable_collection_royalty<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        option::is_some(&borrow_collection(collection).royalty_mutator_ref)
    }

    public fun is_mutable_collection_uri<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        borrow_collection(collection).mutable_uri
    }

    public fun is_mutable_collection_nft_description<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        borrow_collection(collection).mutable_nft_description
    }

    public fun is_mutable_collection_nft_uri<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        borrow_collection(collection).mutable_nft_uri
    }

    public fun is_mutable_collection_nft_properties<T: key>(
        collection: Object<T>,
    ): bool acquires SimpleNftCollection {
        borrow_collection(collection).mutable_nft_properties
    }

    // Collection mutators

    inline fun authorized_borrow_collection<T: key>(collection: Object<T>, creator: &signer): &SimpleNftCollection {
        let collection_address = object::object_address(collection);
        assert!(
            exists<SimpleNftCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        assert!(
            collection::creator(collection) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
        borrow_global<SimpleNftCollection>(collection_address)
    }

    public entry fun set_collection_description<T: key>(
        creator: &signer,
        collection: Object<T>,
        description: String,
    ) acquires SimpleNftCollection {
        let simple_nft_collection = authorized_borrow_collection(collection, creator);
        assert!(
            simple_nft_collection.mutable_description,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_description(option::borrow(&simple_nft_collection.mutator_ref), description);
    }

    public fun set_collection_royalties<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty: royalty::Royalty,
    ) acquires SimpleNftCollection {
        let simple_nft_collection = authorized_borrow_collection(collection, creator);
        assert!(
            option::is_some(&simple_nft_collection.royalty_mutator_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        royalty::update(option::borrow(&simple_nft_collection.royalty_mutator_ref), royalty);
    }

    entry fun set_collection_royalties_call<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty: Decimal128,
        payee_address: address,
    ) acquires SimpleNftCollection {
        let royalty = royalty::create(royalty, payee_address);
        set_collection_royalties(creator, collection, royalty);
    }

    public entry fun set_collection_uri<T: key>(
        creator: &signer,
        collection: Object<T>,
        uri: String,
    ) acquires SimpleNftCollection {
        let simple_nft_collection = authorized_borrow_collection(collection, creator);
        assert!(
            simple_nft_collection.mutable_uri,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_uri(option::borrow(&simple_nft_collection.mutator_ref), uri);
    }

    // Tests

    #[test_only]
    use std::string;

    #[test_only]
    use minitia_std::decimal128;

    #[test(creator = @0x123)]
    fun test_create_and_transfer(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        assert!(object::owner(nft) == signer::address_of(creator), 1);
        object::transfer(creator, nft, @0x345);
        assert!(object::owner(nft) == @0x345, 1);
    }

    #[test(creator = @0x123)]
    fun test_set_description(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        let description = string::utf8(b"not");
        assert!(nft::description(nft) != description, 0);
        set_description(creator, nft, description);
        assert!(nft::description(nft) == description, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_description(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, false);
        let nft = mint_helper(creator, collection_name, token_id);

        set_description(creator, nft, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        let description = string::utf8(b"not");
        set_description(noncreator, nft, description);
    }

    #[test(creator = @0x123)]
    fun test_set_uri(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        let uri = string::utf8(b"not");
        assert!(nft::uri(nft) != uri, 0);
        set_uri(creator, nft, uri);
        assert!(nft::uri(nft) == uri, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_uri(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, false);
        let nft = mint_helper(creator, collection_name, token_id);

        set_uri(creator, nft, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        let uri = string::utf8(b"not");
        set_uri(noncreator, nft, uri);
    }

    #[test(creator = @0x123)]
    fun test_burnable(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        let nft_addr = object::object_address(nft);

        assert!(exists<SimpleNft>(nft_addr), 0);
        burn(creator, nft);
        assert!(!exists<SimpleNft>(nft_addr), 1);
    }

    #[test(creator = @0x123, nonowner = @0x456)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    fun test_burn_non_owner(
        creator: &signer,
        nonowner: &signer,
    ) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        burn(nonowner, nft);
    }

    #[test(creator = @0x123)]
    fun test_set_collection_description(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::description(collection) != value, 0);
        set_collection_description(creator, collection, value);
        assert!(collection::description(collection) == value, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_collection_description(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_description(creator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_collection_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_description(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123)]
    fun test_set_collection_uri(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::uri(collection) != value, 0);
        set_collection_uri(creator, collection, value);
        assert!(collection::uri(collection) == value, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_collection_uri(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_uri(creator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_collection_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_uri(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123)]
    fun test_property_add(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");
        let property_name = string::utf8(b"u8");
        let property_type = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        add_property(creator, nft, property_name, property_type, vector [ 0x08 ]);

        assert!(property_map::read_u8(nft, &property_name) == 0x8, 0);
    }

    #[test(creator = @0x123)]
    fun test_property_typed_add(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");
        let property_name = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        add_typed_property<SimpleNft, u8>(creator, nft, property_name, 0x8);

        assert!(property_map::read_u8(nft, &property_name) == 0x8, 0);
    }

    #[test(creator = @0x123)]
    fun test_property_update(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");
        let property_name = string::utf8(b"bool");
        let property_type = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        update_property(creator, nft, property_name, property_type, vector [ 0x00 ]);

        assert!(!property_map::read_bool(nft, &property_name), 0);
    }

    #[test(creator = @0x123)]
    fun test_property_update_typed(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        update_typed_property<SimpleNft, bool>(creator, nft, property_name, false);

        assert!(!property_map::read_bool(nft, &property_name), 0);
    }

    #[test(creator = @0x123)]
    fun test_property_remove(creator: &signer) acquires SimpleNftCollection, SimpleNft {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);
        remove_property(creator, nft, property_name);
    }

    #[test(creator = @0x123)]
    fun test_royalties(creator: &signer) acquires SimpleNftCollection {
        let collection_name = string::utf8(b"collection name");
        let token_id = string::utf8(b"nft name");

        let collection = create_collection_helper(creator, collection_name, true);
        let nft = mint_helper(creator, collection_name, token_id);

        let royalty_before = option::extract(&mut nft::royalty(nft));
        set_collection_royalties_call(creator, collection, decimal128::from_ratio(2, 3), @0x444);
        let royalty_after = option::extract(&mut nft::royalty(nft));
        assert!(royalty_before != royalty_after, 0);
    }

    #[test_only]
    fun create_collection_helper(
        creator: &signer,
        collection_name: String,
        flag: bool,
    ): Object<SimpleNftCollection> {
        create_collection_object(
            creator,
            string::utf8(b"collection description"),
            option::some(1),
            collection_name,
            string::utf8(b"collection uri"),
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            decimal128::from_ratio(1, 100),
        )
    }

    #[test_only]
    fun mint_helper(
        creator: &signer,
        collection_name: String,
        token_id: String,
    ): Object<SimpleNft> acquires SimpleNftCollection {
        mint_nft_object(
            creator,
            collection_name,
            string::utf8(b"description"),
            token_id,
            string::utf8(b"uri"),
            vector[string::utf8(b"bool")],
            vector[string::utf8(b"bool")],
            vector[vector[0x01]],
        )
    }
}
