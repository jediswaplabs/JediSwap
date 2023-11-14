use starknet:: { ContractAddress, ClassHash };
use snforge_std::{ declare, ContractClassTrait };

use tests::utils::{ deployer_addr, token0, token1 };

#[starknet::interface]
trait IRouterC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    fn sort_tokens(self: @T, tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress);
}

#[starknet::interface]
trait IPairC1<T> {
    // view functions
    fn name(self: @T) -> felt252;
    fn symbol(self: @T) -> felt252;
    fn decimals(self: @T) -> u8;
}

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
}

#[test]
fn test_deployment_pair_factory_router() { // TODO Separate out once setup is available.
    let pair_class = declare('PairC1');

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
    let factory_class = declare('FactoryC1');
    let factory_address = factory_class.deploy(@factory_constructor_calldata).unwrap();

    let mut router_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref router_constructor_calldata);
    let router_class = declare('RouterC1');
    let router_address = router_class.deploy(@router_constructor_calldata).unwrap();

    // Create a Dispatcher object that will allow interacting with the deployed contract
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let result = router_dispatcher.factory();
    assert(result == factory_address, 'Invalid Factory');
}

#[test]
fn test_pair() {
    let pair_class = declare('PairC1');

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
    let factory_class = declare('FactoryC1');
    let factory_address = factory_class.deploy(@factory_constructor_calldata).unwrap();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    let pair_address: ContractAddress = factory_dispatcher.create_pair(token0(), token1());
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let name: felt252 = pair_dispatcher.name();
    assert(name == 'JediSwap Pair', 'Invalid name');

    let symbol: felt252 = pair_dispatcher.symbol();
    assert(symbol == 'JEDI-P', 'Invalid symbol');

    let decimals: u8 = pair_dispatcher.decimals();
    assert(decimals == 18, 'Invalid decimals');
}

#[test]
fn test_pair_in_factory() {
    let pair_class = declare('PairC1');

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
    let factory_class = declare('FactoryC1');
    let factory_address = factory_class.deploy(@factory_constructor_calldata).unwrap();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    let mut router_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref router_constructor_calldata);
    let router_class = declare('RouterC1');
    let router_address = router_class.deploy(@router_constructor_calldata).unwrap();
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let (token0_address, token1_address) = router_dispatcher.sort_tokens(token0(), token1());
    let pair_address = factory_dispatcher.create_pair(token0_address, token1_address);

    let pair_address_from_factory_1: ContractAddress = factory_dispatcher.get_pair(token0_address, token1_address);
    assert(pair_address == pair_address_from_factory_1, 'Invalid pair 1 address');
    let pair_address_from_factory_2: ContractAddress = factory_dispatcher.get_pair(token1_address, token0_address);
    assert(pair_address == pair_address_from_factory_2, 'Invalid pair 2 address');

    let (pairs_length, pairs) = factory_dispatcher.get_all_pairs();
    assert(pairs_length == 1, 'Invalid pairs length');
    assert(*pairs[0] == pair_address, 'Invalid pair address');
}
