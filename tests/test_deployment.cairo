use array::ArrayTrait;
use result::ResultTrait;
use starknet::ContractAddress;
use starknet::ClassHash;
use traits::TryInto;
use option::OptionTrait;

#[starknet::interface]
trait IRouterC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    fn sort_tokens(self: @T, tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress);
    fn quote(self: @T, amountA: u256, reserveA: u256, reserveB: u256) -> u256;
    fn get_amount_out(self: @T, amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256;
    fn get_amount_in(self: @T, amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256;
    fn get_amounts_out(self: @T, amountIn: u256, path: Array::<ContractAddress>) -> Array::<u256>;
    fn get_amounts_in(self: @T, amountOut: u256, path: Array::<ContractAddress>) -> Array::<u256>;
    // external functions
    fn add_liquidity(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress, amountADesired: u256, amountBDesired: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256, u256);
    fn remove_liquidity(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress, liquidity: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(ref self: T, amountIn: u256, amountOutMin: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
    fn swap_tokens_for_exact_tokens(ref self: T, amountOut: u256, amountInMax: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
}

#[test]
fn test_deployment_pair_factory_router() { // TODO Separate out once setup is available.
    let deployer_address = 123456789987654321;

    let declared_pair_class_hash = declare('PairC1');

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@declared_pair_class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_address, ref factory_constructor_calldata);
    let factory_class_hash = declare('FactoryC1');
    let factory_prepared = PreparedContract { class_hash: factory_class_hash, constructor_calldata: @factory_constructor_calldata };
    let factory_address = deploy(factory_prepared).unwrap();

    let mut router_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref router_constructor_calldata);
    let router_class_hash = declare('RouterC1');
    let router_prepared = PreparedContract { class_hash: router_class_hash, constructor_calldata: @router_constructor_calldata };
    let router_address = deploy(router_prepared).unwrap();

    // Create a Dispatcher object that will allow interacting with the deployed contract
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let result = router_dispatcher.factory();
    assert(result == factory_address, 'Invalid Factory');
}
