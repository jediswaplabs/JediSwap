use starknet:: { ContractAddress, ClassHash };
use snforge_std::{ declare, get_class_hash, ContractClassTrait, ContractClass };

mod utils;
use utils::{ token0, token1, zero_addr };

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    fn get_num_of_pairs(self: @T) -> u32;
    fn get_fee_to(self: @T) -> ContractAddress;
    fn get_fee_to_setter(self: @T) -> ContractAddress;
    fn get_pair_contract_class_hash(self: @T) -> ClassHash;
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
    fn set_fee_to(ref self: T, new_fee_to: ContractAddress);
    fn set_fee_to_setter(ref self: T, new_fee_to_setter: ContractAddress);
    fn replace_implementation_class(ref self: T, new_implementation_class: ClassHash);
    fn replace_pair_contract_hash(ref self: T, new_pair_contract_class: ClassHash);
}

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

fn deploy_factory(pair_class: ContractClass) -> ContractAddress {
    let deployer_address = 123456789987654321;

    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
    Serde::serialize(@deployer_address, ref factory_constructor_calldata);
    let factory_class = declare('FactoryC1');
    
    factory_class.deploy(@factory_constructor_calldata).unwrap()
}

#[test]
#[should_panic(expected: ('must be non zero', ))]
fn test_create_pair_without_tokens() {
    let pair_class = declare('PairC1');
    let factory_address = deploy_factory(pair_class);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    factory_dispatcher.create_pair(zero_addr(), zero_addr());
    factory_dispatcher.create_pair(token0(), zero_addr());
    factory_dispatcher.create_pair(zero_addr(), token0());
}

#[test]
#[should_panic(expected: ('must be different', ))]
fn test_create_pair_same_tokens() {
    let pair_class = declare('PairC1');
    let factory_address = deploy_factory(pair_class);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    factory_dispatcher.create_pair(token0(), token0());
}

#[test]
#[should_panic(expected: ('pair already exists', ))]
fn test_create_pair_same_pair() {
    let pair_class = declare('PairC1');
    let factory_address = deploy_factory(pair_class);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    let pair_address = factory_dispatcher.create_pair(token0(), token1());
    assert(pair_address != zero_addr(), 'result shouldn`t be 0');

    let pair_address = factory_dispatcher.create_pair(token0(), token1());
    let pair_address = factory_dispatcher.create_pair(token1(), token0());
}

#[test]
fn test_create2_deployed_pair() {
    let pair_class = declare('PairC1');
    let pair_class_class_hash = pair_class.class_hash;
    let factory_address = deploy_factory(pair_class);

    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };

    let pair_address = factory_dispatcher.create_pair(token0(), token1());
    assert(pair_class_class_hash == get_class_hash(pair_address), 'Incorrect class hash');
}