/// This defines the Move object model with the the following properties:
/// - Simplified storage interface that supports a heterogeneous collection of resources to be
///   stored together. This enables data types to share a common core data layer (e.g., tokens),
///   while having richer extensions (e.g., concert ticket, sword).
/// - Globally accessible data and ownership model that enables creators and developers to dictate
///   the application and lifetime of data.
/// - Extensible programming model that supports individualization of user applications that
///   leverage the core framework including tokens.
/// - Support emitting events directly, thus improving discoverability of events associated with
///   objects.
/// - Considerate of the underlying system by leveraging resource groups for gas efficiency,
///   avoiding costly deserialization and serialization costs, and supporting deletability.
///
/// TODO:
/// * There is no means to borrow an object or a reference to an object. We are exploring how to
///   make it so that a reference to a global object can be returned from a function.
module minitia_std::object {
    use std::error;
    use std::signer;
    use std::vector;
    use std::bcs;
    use std::guid;
    use std::hash;

    use minitia_std::from_bcs;
    use minitia_std::account;
    use minitia_std::transaction_context;
    use minitia_std::event;

    friend minitia_std::primary_fungible_store;

    /// An object already exists at this address
    const EOBJECT_EXISTS: u64 = 1;
    /// An object does not exist at this address
    const EOBJECT_DOES_NOT_EXIST: u64 = 2;
    /// The object does not have ungated transfers enabled
    const ENO_UNGATED_TRANSFERS: u64 = 3;
    /// The caller does not have ownership permissions
    const ENOT_OBJECT_OWNER: u64 = 4;
    /// The object does not allow for deletion
    const ECANNOT_DELETE: u64 = 5;
    /// Exceeds maximum nesting for an object transfer.
    const EMAXIMUM_NESTING: u64 = 6;
    /// The resource is not stored at the specified address.
    const ERESOURCE_DOES_NOT_EXIST: u64 = 7;
    /// Cannot reclaim objects that weren't burnt.
    const EOBJECT_NOT_BURNT: u64 = 8;

    /// Maximum nesting from one object to another. That is objects can technically have infinte
    /// nesting, but any checks such as transfer will only be evaluated this deep.
    const MAXIMUM_OBJECT_NESTING: u8 = 8;

    /// Scheme identifier used to generate an object's address `obj_addr` as derived from another object.
    /// The object's address is generated as:
    /// ```
    ///     obj_addr = sha3_256(account addr | derived from object's address | 0xFC)
    /// ```
    ///
    /// This 0xFC constant serves as a domain separation tag to prevent existing authentication key and resource account
    /// derivation to produce an object address.
    const OBJECT_DERIVED_SCHEME: u8 = 0xFC;

    /// Scheme identifier used to generate an object's address `obj_addr` via a fresh GUID generated by the creator at
    /// `source_addr`. The object's address is generated as:
    /// ```
    ///     obj_addr = sha3_256(guid | 0xFD)
    /// ```
    /// where `guid = account::create_guid(create_signer(source_addr))`
    ///
    /// This 0xFD constant serves as a domain separation tag to prevent existing authentication key and resource account
    /// derivation to produce an object address.
    const OBJECT_FROM_GUID_ADDRESS_SCHEME: u8 = 0xFD;

    /// Scheme identifier used to generate an object's address `obj_addr` from the creator's `source_addr` and a `seed` as:
    ///     obj_addr = sha3_256(source_addr | seed | 0xFE).
    ///
    /// This 0xFE constant serves as a domain separation tag to prevent existing authentication key and resource account
    /// derivation to produce an object address.
    const OBJECT_FROM_SEED_ADDRESS_SCHEME: u8 = 0xFE;

    /// Address where unwanted objects can be forcefully transferred to.
    const BURN_ADDRESS: address = @0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// The core of the object model that defines ownership, transferability, and events.
    struct ObjectCore has key {
        /// The address (object or account) that owns this object
        owner: address,
        /// Object transferring is a common operation, this allows for disabling and enabling
        /// transfers bypassing the use of a TransferRef.
        allow_ungated_transfer: bool,
    }

    /// This is added to objects that are burnt (ownership transferred to BURN_ADDRESS).
    struct TombStone has key {
        /// Track the previous owner before the object is burnt so they can reclaim later if so desired.
        original_owner: address,
    }

    /// A shared resource group for storing object resources together in storage.
    struct ObjectGroup {}

    /// A pointer to an object -- these can only provide guarantees based upon the underlying data
    /// type, that is the validity of T existing at an address is something that cannot be verified
    /// by any other module than the module that defined T. Similarly, the module that defines T
    /// can remove it from storage at any point in time.
    struct Object<phantom T> has copy, drop, store {
        inner: address,
    }

    /// This is a one time ability given to the creator to configure the object as necessary
    struct ConstructorRef has drop {
        self: address,
        /// True if the object can be deleted. Named objects are not deletable.
        can_delete: bool,
    }

    /// Used to remove an object from storage.
    struct DeleteRef has drop, store {
        self: address,
    }

    /// Used to create events or move additional resources into object storage.
    struct ExtendRef has drop, store {
        self: address,
    }

    /// Used to create LinearTransferRef, hence ownership transfer.
    struct TransferRef has drop, store {
        self: address,
    }

    /// Used to perform transfers. This locks transferring ability to a single time use bound to
    /// the current owner.
    struct LinearTransferRef has drop {
        self: address,
        owner: address,
    }

    /// Used to create derived objects from a given objects.
    struct DeriveRef has drop, store {
        self: address,
    }

    /// Emitted whenever the object's owner field is changed.
    struct TransferEvent has drop, store {
        object: address,
        from: address,
        to: address,
    }

    #[view]
    public fun is_burnt<T: key>(object: Object<T>): bool {
        exists<TombStone>(object.inner)
    }

    /// Produces an ObjectId from the given address. This is not verified.
    public fun address_to_object<T: key>(object: address): Object<T> {
        assert!(exists<ObjectCore>(object), error::not_found(EOBJECT_DOES_NOT_EXIST));
        assert!(exists_at<T>(object), error::not_found(ERESOURCE_DOES_NOT_EXIST));
        Object<T> { inner: object }
    }

    /// Returns true if there exists an object or the remnants of an object.
    public fun is_object(object: address): bool {
        exists<ObjectCore>(object)
    }

    /// Derives an object address from source material: sha3_256([creator address | seed | 0xFE]).
    public fun create_object_address(source: address, seed: vector<u8>): address {
        let bytes = bcs::to_bytes(&source);
        vector::append(&mut bytes, seed);
        vector::push_back(&mut bytes, OBJECT_FROM_SEED_ADDRESS_SCHEME);
        from_bcs::to_address(hash::sha3_256(bytes))
    }

    /// Derives an object address from the source address and an object: sha3_256([source | object addr | 0xFC]).
    public fun create_user_derived_object_address(source: address, derive_from: address): address {
        let bytes = bcs::to_bytes(&source);
        vector::append(&mut bytes, bcs::to_bytes(&derive_from));
        vector::push_back(&mut bytes, OBJECT_DERIVED_SCHEME);
        from_bcs::to_address(hash::sha3_256(bytes))
    }

    /// Derives an object from an Account GUID.
    public fun create_guid_object_address(source: address, creation_num: u64): address {
        let id = guid::create_id(source, creation_num);
        let bytes = bcs::to_bytes(&id);
        vector::push_back(&mut bytes, OBJECT_FROM_GUID_ADDRESS_SCHEME);
        from_bcs::to_address(hash::sha3_256(bytes))
    }

    native fun exists_at<T: key>(object: address): bool;

    /// Returns the address of within an ObjectId.
    public fun object_address<T: key>(object: Object<T>): address {
        object.inner
    }

    /// Convert Object<X> to Object<Y>.
    public fun convert<X: key, Y: key>(object: Object<X>): Object<Y> {
        address_to_object<Y>(object.inner)
    }

    /// Create a new named object and return the ConstructorRef. Named objects can be queried globally
    /// by knowing the user generated seed used to create them. Named objects cannot be deleted.
    public fun create_named_object(creator: &signer, seed: vector<u8>): ConstructorRef {
        let creator_address = signer::address_of(creator);
        let obj_addr = create_object_address(creator_address, seed);
        create_object_internal(creator_address, obj_addr, false)
    }

    /// Create a new object whose address is derived based on the creator account address and another object.
    /// Derivde objects, similar to named objects, cannot be deleted.
    public(friend) fun create_user_derived_object(creator_address: address, derive_ref: &DeriveRef): ConstructorRef {
        let obj_addr = create_user_derived_object_address(creator_address, derive_ref.self);
        create_object_internal(creator_address, obj_addr, false)
    }

    /// Create a new object by generating a random unique address based on transaction hash.
    /// The unique address is computed sha3_256([transaction hash | auid counter | 0xFB]).
    /// The created object is deletable as we can guarantee the same unique address can
    /// never be regenerated with future txs.
    public fun create_object(owner_address: address): ConstructorRef {
        let unique_address = transaction_context::generate_unique_address();
        create_object_internal(owner_address, unique_address, true)
    }

    /// Same as `create_object` except the object to be created will be undeletable.
    public fun create_sticky_object(owner_address: address): ConstructorRef {
        let unique_address = transaction_context::generate_unique_address();
        create_object_internal(owner_address, unique_address, false)
    }

    fun create_object_internal(
        creator_address: address,
        object: address,
        can_delete: bool,
    ): ConstructorRef {
        // create resource account to prevent address overapping.
        account::create_object_account(object);

        assert!(!exists<ObjectCore>(object), error::already_exists(EOBJECT_EXISTS));
        let object_signer = account::create_signer(object);

        move_to(
            &object_signer,
            ObjectCore {
                owner: creator_address,
                allow_ungated_transfer: true,
            },
        );
        ConstructorRef { self: object, can_delete }
    }

    // Creation helpers

    /// Generates the DeleteRef, which can be used to remove ObjectCore from global storage.
    public fun generate_delete_ref(ref: &ConstructorRef): DeleteRef {
        assert!(ref.can_delete, error::permission_denied(ECANNOT_DELETE));
        DeleteRef { self: ref.self }
    }

    /// Generates the ExtendRef, which can be used to add new events and resources to the object.
    public fun generate_extend_ref(ref: &ConstructorRef): ExtendRef {
        ExtendRef { self: ref.self }
    }

    /// Generates the TransferRef, which can be used to manage object transfers.
    public fun generate_transfer_ref(ref: &ConstructorRef): TransferRef {
        TransferRef { self: ref.self }
    }

    /// Generates the DeriveRef, which can be used to create determnistic derived objects from the current object.
    public fun generate_derive_ref(ref: &ConstructorRef): DeriveRef {
        DeriveRef { self: ref.self }
    }

    /// Create a signer for the ConstructorRef
    public fun generate_signer(ref: &ConstructorRef): signer {
        account::create_signer(ref.self)
    }

    /// Returns the address associated with the constructor
    public fun address_from_constructor_ref(ref: &ConstructorRef): address {
        ref.self
    }

    /// Returns an Object<T> from within a ConstructorRef
    public fun object_from_constructor_ref<T: key>(ref: &ConstructorRef): Object<T> {
        address_to_object<T>(ref.self)
    }

    /// Returns whether or not the ConstructorRef can be used to create DeleteRef
    public fun can_generate_delete_ref(ref: &ConstructorRef): bool {
        ref.can_delete
    }

    // Deletion helpers

    /// Returns the address associated with the constructor
    public fun address_from_delete_ref(ref: &DeleteRef): address {
        ref.self
    }

    /// Returns an Object<T> from within a DeleteRef.
    public fun object_from_delete_ref<T: key>(ref: &DeleteRef): Object<T> {
        address_to_object<T>(ref.self)
    }

    /// Removes from the specified Object from global storage.
    public fun delete(ref: DeleteRef) acquires ObjectCore {
        let object_core = move_from<ObjectCore>(ref.self);
        let ObjectCore {
            owner: _,
            allow_ungated_transfer: _,
        } = object_core;
    }

    // Extension helpers

    /// Create a signer for the ExtendRef
    public fun generate_signer_for_extending(ref: &ExtendRef): signer {
        account::create_signer(ref.self)
    }

    /// Returns an address from within a ExtendRef.
    public fun address_from_extend_ref(ref: &ExtendRef): address {
        ref.self
    }

    // Transfer functionality

    /// Disable direct transfer, transfers can only be triggered via a TransferRef
    public fun disable_ungated_transfer(ref: &TransferRef) acquires ObjectCore {
        let object = borrow_global_mut<ObjectCore>(ref.self);
        object.allow_ungated_transfer = false;
    }

    /// Enable direct transfer.
    public fun enable_ungated_transfer(ref: &TransferRef) acquires ObjectCore {
        let object = borrow_global_mut<ObjectCore>(ref.self);
        object.allow_ungated_transfer = true;
    }

    /// Create a LinearTransferRef for a one-time transfer. This requires that the owner at the
    /// time of generation is the owner at the time of transferring.
    public fun generate_linear_transfer_ref(ref: &TransferRef): LinearTransferRef acquires ObjectCore {
        let owner = owner(Object<ObjectCore> { inner: ref.self });
        LinearTransferRef {
            self: ref.self,
            owner,
        }
    }

    /// Transfer to the destination address using a LinearTransferRef.
    public fun transfer_with_ref(ref: LinearTransferRef, to: address) acquires ObjectCore {
        let object = borrow_global_mut<ObjectCore>(ref.self);
        assert!(
            object.owner == ref.owner,
            error::permission_denied(ENOT_OBJECT_OWNER),
        );
        event::emit(
            TransferEvent {
                object: ref.self,
                from: object.owner,
                to,
            },
        );
        object.owner = to;
    }

    /// Entry function that can be used to transfer, if allow_ungated_transfer is set true.
    public entry fun transfer_call(
        owner: &signer,
        object: address,
        to: address,
    ) acquires ObjectCore {
        transfer_raw(owner, object, to)
    }

    /// Transfers ownership of the object (and all associated resources) at the specified address
    /// for Object<T> to the "to" address.
    public entry fun transfer<T: key>(
        owner: &signer,
        object: Object<T>,
        to: address,
    ) acquires ObjectCore {
        transfer_raw(owner, object.inner, to)
    }

    /// Attempts to transfer using addresses only. Transfers the given object if
    /// allow_ungated_transfer is set true. Note, that this allows the owner of a nested object to
    /// transfer that object, so long as allow_ungated_transfer is enabled at each stage in the
    /// hierarchy.
    public fun transfer_raw(
        owner: &signer,
        object: address,
        to: address,
    ) acquires ObjectCore {
        let owner_address = signer::address_of(owner);
        verify_ungated_and_descendant(owner_address, object);

        let object_core = borrow_global_mut<ObjectCore>(object);
        if (object_core.owner == to) {
            return
        };

        event::emit(
            TransferEvent {
                object: object,
                from: object_core.owner,
                to,
            },
        );
        object_core.owner = to;
    }

    /// Transfer the given object to another object. See `transfer` for more information.
    public entry fun transfer_to_object<O: key, T: key>(
        owner: &signer,
        object: Object<O>,
        to: Object<T>,
    ) acquires ObjectCore {
        transfer(owner, object, to.inner)
    }

    /// This checks that the destination address is eventually owned by the owner and that each
    /// object between the two allows for ungated transfers. Note, this is limited to a depth of 8
    /// objects may have cyclic dependencies.
    fun verify_ungated_and_descendant(owner: address, destination: address) acquires ObjectCore {
        let current_address = destination;
        assert!(
            exists<ObjectCore>(current_address),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );

        let object = borrow_global<ObjectCore>(current_address);
        assert!(
            object.allow_ungated_transfer,
            error::permission_denied(ENO_UNGATED_TRANSFERS),
        );

        let current_address = object.owner;

        let count = 0;
        while (owner != current_address) {
            let count = count + 1;
            assert!(count < MAXIMUM_OBJECT_NESTING, error::out_of_range(EMAXIMUM_NESTING));

            // At this point, the first object exists and so the more likely case is that the
            // object's owner is not an object. So we return a more sensible error.
            assert!(
                exists<ObjectCore>(current_address),
                error::permission_denied(ENOT_OBJECT_OWNER),
            );
            let object = borrow_global<ObjectCore>(current_address);
            assert!(
                object.allow_ungated_transfer,
                error::permission_denied(ENO_UNGATED_TRANSFERS),
            );

            current_address = object.owner;
        };
    }

    /// Forcefully transfer an unwanted object to BURN_ADDRESS, ignoring whether ungated_transfer is allowed.
    /// This only works for objects directly owned and for simplicity does not apply to indirectly owned objects.
    /// Original owners can reclaim burnt objects any time in the future by calling unburn.
    public entry fun burn<T: key>(owner: &signer, object: Object<T>) acquires ObjectCore {
        let original_owner = signer::address_of(owner);
        assert!(owner(object) == original_owner, error::permission_denied(ENOT_OBJECT_OWNER));
        let object_addr = object.inner;
        move_to(&account::create_signer(object_addr), TombStone { original_owner });
        let object = borrow_global_mut<ObjectCore>(object_addr);
        object.owner = BURN_ADDRESS;

        // Burn should still emit event to make sure ownership is upgrade correctly in indexing.
        event::emit(
            TransferEvent {
                object: object_addr,
                from: original_owner,
                to: BURN_ADDRESS,
            },
        );
    }

    /// Allow origin owners to reclaim any objects they previous burnt.
    public entry fun unburn<T: key>(
        original_owner: &signer,
        object: Object<T>,
    ) acquires ObjectCore, TombStone {
        let object_addr = object.inner;
        assert!(exists<TombStone>(object_addr), error::invalid_argument(EOBJECT_NOT_BURNT));

        let TombStone { original_owner: original_owner_addr } = move_from<TombStone>(object_addr);
        assert!(original_owner_addr == signer::address_of(original_owner), error::permission_denied(ENOT_OBJECT_OWNER));
        let object = borrow_global_mut<ObjectCore>(object_addr);
        object.owner = original_owner_addr;

        // Unburn reclaims should still emit event to make sure ownership is upgrade correctly in indexing.
        event::emit(
            TransferEvent {
                object: object_addr,
                from: BURN_ADDRESS,
                to: original_owner_addr,
            },
        );
    }

    // Accessors

    #[view] 
    /// Return true if ungated transfer is allowed.
    public fun ungated_transfer_allowed<T: key>(object: Object<T>): bool acquires ObjectCore {
        assert!(
            exists<ObjectCore>(object.inner),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );
        borrow_global<ObjectCore>(object.inner).allow_ungated_transfer
    }

    #[view]
    /// Return the current owner.
    public fun owner<T: key>(object: Object<T>): address acquires ObjectCore {
        assert!(
            exists<ObjectCore>(object.inner),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );
        borrow_global<ObjectCore>(object.inner).owner
    }

    #[view]
    /// Return true if the provided address is the current owner.
    public fun is_owner<T: key>(object: Object<T>, owner: address): bool acquires ObjectCore {
        owner(object) == owner
    }

    #[view]
    /// Return true if the provided address has indirect or direct ownership of the provided object.
    public fun owns<T: key>(object: Object<T>, owner: address): bool acquires ObjectCore {
        let current_address = object_address(object);
        if (current_address == owner) {
            return true
        };

        assert!(
            exists<ObjectCore>(current_address),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );

        let object = borrow_global<ObjectCore>(current_address);
        let current_address = object.owner;

        let count = 0;
        while (owner != current_address) {
            let count = count + 1;
            assert!(count < MAXIMUM_OBJECT_NESTING, error::out_of_range(EMAXIMUM_NESTING));
            if (!exists<ObjectCore>(current_address)) {
                return false
            };

            let object = borrow_global<ObjectCore>(current_address);
            current_address = object.owner;
        };
        true
    }
    #[test_only]
    use std::option::{Self, Option};

    #[test_only]
    const EHERO_DOES_NOT_EXIST: u64 = 0x100;
    #[test_only]
    const EWEAPON_DOES_NOT_EXIST: u64 = 0x101;

    #[test_only]
    struct HeroEquipEvent has drop, store {
        weapon_id: Option<Object<Weapon>>,
    }

    #[test_only]
    struct Hero has key {
        weapon: Option<Object<Weapon>>,
    }

    #[test_only]
    struct Weapon has key {}

    #[test_only]
    public fun create_hero(creator: &signer): (ConstructorRef, Object<Hero>) {
        let hero_constructor_ref = create_named_object(creator, b"hero");
        let hero_signer = generate_signer(&hero_constructor_ref);
        move_to(
            &hero_signer,
            Hero {
                weapon: option::none(),
            },
        );

        let hero = object_from_constructor_ref<Hero>(&hero_constructor_ref);
        (hero_constructor_ref, hero)
    }

    #[test_only]
    public fun create_weapon(creator: &signer): (ConstructorRef, Object<Weapon>) {
        let weapon_constructor_ref = create_named_object(creator, b"weapon");
        let weapon_signer = generate_signer(&weapon_constructor_ref);
        move_to(&weapon_signer, Weapon {});
        let weapon = object_from_constructor_ref<Weapon>(&weapon_constructor_ref);
        (weapon_constructor_ref, weapon)
    }

    #[test_only]
    public fun hero_equip(
        owner: &signer,
        hero: Object<Hero>,
        weapon: Object<Weapon>,
    ) acquires Hero, ObjectCore {
        transfer_to_object(owner, weapon, hero);
        let hero_obj = borrow_global_mut<Hero>(object_address(hero));
        option::fill(&mut hero_obj.weapon, weapon);
        event::emit(
            HeroEquipEvent { weapon_id: option::some(weapon) },
        );
    }

    #[test_only]
    public fun hero_unequip(
        owner: &signer,
        hero: Object<Hero>,
        weapon: Object<Weapon>,
    ) acquires Hero, ObjectCore {
        transfer(owner, weapon, signer::address_of(owner));
        let hero = borrow_global_mut<Hero>(object_address(hero));
        option::extract(&mut hero.weapon);
        event::emit(
            HeroEquipEvent { weapon_id: option::none() },
        );
    }

    #[test(creator = @0x123)]
    fun test_object(creator: &signer) acquires Hero, ObjectCore {
        let (_, hero) = create_hero(creator);
        let (_, weapon) = create_weapon(creator);

        assert!(owns(weapon, @0x123), 0);
        hero_equip(creator, hero, weapon);
        assert!(owns(weapon, @0x123), 1);
        hero_unequip(creator, hero, weapon);
    }

    #[test(creator = @0x123)]
    fun test_linear_transfer(creator: &signer) acquires ObjectCore {
        let (hero_constructor, hero) = create_hero(creator);
        let transfer_ref = generate_transfer_ref(&hero_constructor);
        let linear_transfer_ref = generate_linear_transfer_ref(&transfer_ref);
        transfer_with_ref(linear_transfer_ref, @0x456);
        assert!(owner(hero) == @0x456, 0);
        assert!(owns(hero, @0x456), 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_bad_linear_transfer(creator: &signer) acquires ObjectCore {
        let (hero_constructor, hero) = create_hero(creator);
        let transfer_ref = generate_transfer_ref(&hero_constructor);
        let linear_transfer_ref_good = generate_linear_transfer_ref(&transfer_ref);
        // This will contain the address of the creator
        let linear_transfer_ref_bad = generate_linear_transfer_ref(&transfer_ref);
        transfer_with_ref(linear_transfer_ref_good, @0x456);
        assert!(owner(hero) == @0x456, 0);
        transfer_with_ref(linear_transfer_ref_bad, @0x789);
    }

    #[test(creator = @0x123)]
    fun test_burn_and_unburn(creator: &signer) acquires ObjectCore, TombStone {
        let (hero_constructor, hero) = create_hero(creator);
        // Freeze the object.
        let transfer_ref = generate_transfer_ref(&hero_constructor);
        disable_ungated_transfer(&transfer_ref);

        // Owner should be able to burn, despite ungated transfer disallowed.
        burn(creator, hero);
        assert!(owner(hero) == BURN_ADDRESS, 0);
        assert!(!ungated_transfer_allowed(hero), 0);

        // Owner should be able to reclaim.
        unburn(creator, hero);
        assert!(owner(hero) == signer::address_of(creator), 0);
        // Object still frozen.
        assert!(!ungated_transfer_allowed(hero), 0);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_burn_indirectly_owned_should_fail(creator: &signer) acquires ObjectCore {
        let (_, hero) = create_hero(creator);
        let (_, weapon) = create_weapon(creator);
        transfer_to_object(creator, weapon, hero);

        // Owner should be not be able to burn weapon directly.
        assert!(owner(weapon) == object_address(hero), 0);
        assert!(owns(weapon, signer::address_of(creator)), 0);
        burn(creator, weapon);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x10008, location = Self)]
    fun test_unburn_object_not_burnt_should_fail(creator: &signer) acquires ObjectCore, TombStone {
        let (_, hero) = create_hero(creator);
        unburn(creator, hero);
    }
}
