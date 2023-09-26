use starknet:: { ContractAddress };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_prank, stop_prank };

mod utils;
use utils::{ deployer_addr, user1, zero_addr };

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_fee_to(self: @T) -> ContractAddress;
    fn get_fee_to_setter(self: @T) -> ContractAddress;
    // external functions
    fn set_fee_to(ref self: T, new_fee_to: ContractAddress);
    fn set_fee_to_setter(ref self: T, new_fee_to_setter: ContractAddress);
}

#[starknet::interface]
trait IRouterC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    fn sort_tokens(self: @T, tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress);
}

fn deploy_factory() -> ContractAddress {
    let pair_class = declare('PairC1');

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
    let factory_class = declare('FactoryC1');
    
    factory_class.deploy(@factory_constructor_calldata).unwrap()
}

#[test]
#[should_panic(expected: ('must be fee to setter', ))]
fn test_create_pair_without_tokens() {
    let factory_address = deploy_factory();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    factory_dispatcher.set_fee_to(user1());
}

#[test]
fn test_set_fee_to() {
    let factory_address = deploy_factory();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    start_prank(factory_address, deployer_addr());
    factory_dispatcher.set_fee_to(user1());
    stop_prank(factory_address);

    let fee_to_address = factory_dispatcher.get_fee_to();
    assert(fee_to_address == user1(), 'fee_to should change');
}

#[test]
#[should_panic(expected: ('must be fee to setter', ))]
fn test_update_fee_to_setter_non_fee_to_setter() {
    let factory_address = deploy_factory();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    factory_dispatcher.set_fee_to_setter(user1());
}

#[test]
#[should_panic(expected: ('must be non zero', ))]
fn test_update_fee_to_setter_zero() {
    let factory_address = deploy_factory();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    start_prank(factory_address, deployer_addr());
    factory_dispatcher.set_fee_to_setter(zero_addr());
    stop_prank(factory_address);
}

#[test]
fn test_update_fee_to_setter() {
    let factory_address = deploy_factory();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    start_prank(factory_address, deployer_addr());
    factory_dispatcher.set_fee_to_setter(user1());
    stop_prank(factory_address);

    let fee_to_setter_address = factory_dispatcher.get_fee_to_setter();
    assert(fee_to_setter_address == user1(), 'fee_to_setter should change');
}