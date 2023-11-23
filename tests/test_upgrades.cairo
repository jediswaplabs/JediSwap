use starknet:: { ContractAddress, ClassHash, contract_address_const, contract_address_try_from_felt252, 
                 class_hash_to_felt252 };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_prank, stop_prank, get_class_hash };
use snforge_std::PrintTrait;
use tests::utils::{ token0, token1 };

#[starknet::interface]
trait IProxyC0<T> {
    // view functions
    fn get_admin(self: @T) -> felt252;
    fn get_implementation_hash(self: @T) -> felt252;
    // external functions
    fn upgrade(ref self: T, new_implementation: felt252);
}

#[starknet::interface]
trait IRouterC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    // external functions
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
}

#[starknet::interface]
trait IRouterTestC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    // external functions
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
}

#[starknet::interface]
trait IPairC1<T> {
    // view functions
    fn decimals(self: @T) -> u8;
    // external functions
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
}

#[starknet::interface]
trait IPairTestC1<T> {
    // view functions
    fn decimals(self: @T) -> u8;
    // external functions
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
}

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    fn get_pair_contract_class_hash(self: @T) -> felt252;
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
    fn replace_pair_contract_hash(ref self: T, new_pair_contract_class: ClassHash);
}

#[starknet::interface]
trait IFactoryTestC1<T> {
    // view functions
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    fn get_pair_contract_class_hash(self: @T) -> felt252;
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
    fn replace_pair_contract_hash(ref self: T, new_pair_contract_class: ClassHash);
}


fn get_factory_address_c0() -> ContractAddress {
    contract_address_const::<0x00dad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd>()
}


#[test]
#[fork("mainnet_fork")]
fn test_upgrade_factory_from_cairo_0_to_latest() {
    // Setup
    let factory_address_c0: ContractAddress = get_factory_address_c0();

    let pair_class = declare('PairC1');
    let pair_class_hash_c1: felt252 = class_hash_to_felt252(pair_class.class_hash);
    let factory_class_c1 = declare('FactoryC1');
    let factory_class_hash_c1: felt252 = class_hash_to_felt252(factory_class_c1.class_hash);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address_c0 };
    let proxy_dispatcher_c0 = IProxyC0Dispatcher { contract_address: factory_address_c0 };

    let proxy_admin_c0: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();

    let pair_class_hash_c0: felt252 = factory_dispatcher.get_pair_contract_class_hash();
    assert(pair_class_hash_c0 != pair_class_hash_c1, 'Incorrect pair class hash');

    let factory_implementation_hash_c0: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(factory_implementation_hash_c0 != factory_class_hash_c1, 'Incorrect class hash');

    // Upgrade factory
    start_prank(factory_address_c0, proxy_admin_c0);
    proxy_dispatcher_c0.upgrade(factory_class_hash_c1);
    stop_prank(factory_address_c0);

    let factory_implementation_hash_c1: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(factory_implementation_hash_c1 == factory_class_hash_c1, 'Incorrect class hash upgrade');

    let proxy_admin_c1: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();
    assert(proxy_admin_c0 == proxy_admin_c1, 'Incorrect proxy admin');

    // Update pair class hash
    start_prank(factory_address_c0, proxy_admin_c0);
    factory_dispatcher.replace_pair_contract_hash(pair_class.class_hash);
    stop_prank(factory_address_c0);

    let pair_class_hash_c1_after_upgrade: felt252 = factory_dispatcher.get_pair_contract_class_hash();
    assert(pair_class_hash_c1_after_upgrade == pair_class_hash_c1, 'Incorrect new pair class hash');

    // Create new pair after upgrade
    let pair_address: ContractAddress = factory_dispatcher.create_pair(token0(), token1());
    assert(pair_class.class_hash == get_class_hash(pair_address), 'Invalid created pair class hash');

    // Perform another factory upgrade
    let factory_class_test = declare('FactoryTestC1');
    let factory_class_hash_test: felt252 = class_hash_to_felt252(factory_class_test.class_hash);
    assert(factory_implementation_hash_c1 != factory_class_hash_test, 'Incorrect class hash 2');

    start_prank(factory_address_c0, proxy_admin_c0);
    proxy_dispatcher_c0.upgrade(factory_class_hash_test);
    stop_prank(factory_address_c0);

    let factory_implementation_hash_c1_after_upgrade: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(factory_implementation_hash_c1_after_upgrade == factory_class_hash_test, 'Incorrect class hash upgrade 2');

    let proxy_admin_c1_after_upgrade: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();
    assert(proxy_admin_c0 == proxy_admin_c1_after_upgrade, 'Incorrect proxy admin 2');

    // Upgrade back to FactoryC1 (test replace_implementation_class fn)
    assert(factory_implementation_hash_c1_after_upgrade != factory_class_hash_c1, 'Incorrect class hash 3');

    start_prank(factory_address_c0, proxy_admin_c0);
    factory_dispatcher.replace_implementation_class(factory_class_c1.class_hash);
    stop_prank(factory_address_c0);

    let (pairs_num, pairs) = factory_dispatcher.get_all_pairs();
    assert(pairs_num > 0, 'Incorrect pairs num');
}

#[test]
#[fork("mainnet_fork")]
fn test_upgrade_router_from_cairo_0_to_latest() {
    // Setup
    let router_address_c0: ContractAddress = contract_address_const::<0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023>();
   
    let router_class_c1 = declare('RouterC1');
    let router_class_hash_c1: felt252 = class_hash_to_felt252(router_class_c1.class_hash);

    let proxy_dispatcher_c0 = IProxyC0Dispatcher { contract_address: router_address_c0 };
    let proxy_admin_c0: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();

    // Upgrade router
    start_prank(router_address_c0, proxy_admin_c0);
    proxy_dispatcher_c0.upgrade(router_class_hash_c1);
    stop_prank(router_address_c0);

    let router_implementation_hash_c1: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(router_implementation_hash_c1 == router_class_hash_c1, 'Incorrect class hash upgrade');

    let proxy_admin_c1: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();
    assert(proxy_admin_c0 == proxy_admin_c1, 'Incorrect proxy admin');

    // Perform another router upgrade
    let router_class_test = declare('RouterTestC1');
    let router_class_hash_test: felt252 = class_hash_to_felt252(router_class_test.class_hash);
    assert(router_implementation_hash_c1 != router_class_hash_test, 'Incorrect class hash 2');

    start_prank(router_address_c0, proxy_admin_c0);
    proxy_dispatcher_c0.upgrade(router_class_hash_test);
    stop_prank(router_address_c0);

    let router_implementation_hash_c1_after_upgrade: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(router_implementation_hash_c1_after_upgrade == router_class_hash_test, 'Incorrect class hash upgrade 2');

    let proxy_admin_c1_after_upgrade: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();
    assert(proxy_admin_c0 == proxy_admin_c1_after_upgrade, 'Incorrect proxy admin 2');

    // Upgrade back to RouterC1 (test replace_implementation_class fn)
    assert(router_implementation_hash_c1_after_upgrade != router_class_hash_c1, 'Incorrect class hash 3');
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address_c0 };

    start_prank(router_address_c0, proxy_admin_c0);
    router_dispatcher.replace_implementation_class(router_class_c1.class_hash);
    stop_prank(router_address_c0);

    let router_factory_address: ContractAddress = router_dispatcher.factory();
    assert(router_factory_address == get_factory_address_c0(), 'Incorrect factory address');
}

#[test]
#[fork("mainnet_fork")]
fn test_upgrade_all_pairs_from_cairo_0_to_latest() {
    // Setup
    let factory_address_c0: ContractAddress = get_factory_address_c0();

    let pair_class = declare('PairC1');
    let pair_class_hash_c1: felt252 = class_hash_to_felt252(pair_class.class_hash);
    let pair_class_test = declare('PairTestC1');
    let pair_class_hash_test: felt252 = class_hash_to_felt252(pair_class_test.class_hash);
    let factory_class_c1 = declare('FactoryC1');
    let factory_class_hash_c1: felt252 = class_hash_to_felt252(factory_class_c1.class_hash);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address_c0 };
    let proxy_dispatcher_c0 = IProxyC0Dispatcher { contract_address: factory_address_c0 };

    let proxy_admin_c0: ContractAddress = contract_address_try_from_felt252(
        proxy_dispatcher_c0.get_admin()).unwrap();

    let factory_implementation_hash_c0: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(factory_implementation_hash_c0 != factory_class_hash_c1, 'Incorrect class hash');

    // Upgrade factory
    start_prank(factory_address_c0, proxy_admin_c0);
    proxy_dispatcher_c0.upgrade(factory_class_hash_c1);
    stop_prank(factory_address_c0);

    let factory_implementation_hash_c1: felt252 = proxy_dispatcher_c0.get_implementation_hash();
    assert(factory_implementation_hash_c1 == factory_class_hash_c1, 'Incorrect class hash upgrade');

    let (pairs_num, pairs) = factory_dispatcher.get_all_pairs();
    assert(pairs_num > 0, 'Incorrect pairs num');

    let mut current_index = 0_u32;
    loop {
        if current_index == pairs_num {
            break;
        }

        // Upgrade pair
        let pair_address_c0: ContractAddress = *pairs[current_index];

        // Uncomment for debugging
        // 'Upgrading the pair:'.print();
        // pair_address_c0.print();

        let proxy_dispatcher_c0 = IProxyC0Dispatcher { contract_address: pair_address_c0 };
        let proxy_admin_c0: ContractAddress = contract_address_try_from_felt252(
            proxy_dispatcher_c0.get_admin()).unwrap();

        let pair_implementation_hash_c0: felt252 = proxy_dispatcher_c0.get_implementation_hash();
        assert(pair_implementation_hash_c0 != pair_class_hash_c1, 'Incorrect class hash');

        start_prank(pair_address_c0, proxy_admin_c0);
        proxy_dispatcher_c0.upgrade(pair_class_hash_c1);
        stop_prank(pair_address_c0);

        let pair_implementation_hash_c1: felt252 = proxy_dispatcher_c0.get_implementation_hash();
        assert(pair_implementation_hash_c1 == pair_class_hash_c1, 'Incorrect class hash upgrade');

        let proxy_admin_c1: ContractAddress = contract_address_try_from_felt252(
            proxy_dispatcher_c0.get_admin()).unwrap();
        assert(proxy_admin_c0 == proxy_admin_c1, 'Incorrect proxy admin');

        // Perform another pair upgrade
        assert(pair_implementation_hash_c1 != pair_class_hash_test, 'Incorrect class hash 2');

        start_prank(pair_address_c0, proxy_admin_c0);
        proxy_dispatcher_c0.upgrade(pair_class_hash_test);
        stop_prank(pair_address_c0);

        let pair_implementation_hash_c1_after_upgrade: felt252 = proxy_dispatcher_c0.get_implementation_hash();
        assert(pair_implementation_hash_c1_after_upgrade == pair_class_hash_test, 'Incorrect class hash upgrade 2');

        let proxy_admin_c1_after_upgrade: ContractAddress = contract_address_try_from_felt252(
            proxy_dispatcher_c0.get_admin()).unwrap();
        assert(proxy_admin_c0 == proxy_admin_c1_after_upgrade, 'Incorrect proxy admin 2');

        // Upgrade back to PairC1 (test replace_implementation_class fn)
        assert(pair_implementation_hash_c1_after_upgrade != pair_class_hash_c1, 'Incorrect class hash 3');
        let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address_c0 };

        start_prank(pair_address_c0, proxy_admin_c0);
        pair_dispatcher.replace_implementation_class(pair_class.class_hash);
        stop_prank(pair_address_c0);

        let decimals = pair_dispatcher.decimals();
        assert(decimals > 0, 'Incorrect decimals');

        current_index += 1;
    }
}
