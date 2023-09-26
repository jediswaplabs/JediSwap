use starknet:: { ContractAddress, ClassHash };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };
use JediSwap::utils::erc20::ERC20;
use JediSwap::utils::erc20::ERC20::InternalImpl;
use starknet::{SyscallResult, SyscallResultTrait, get_caller_address, get_contract_address, get_block_timestamp, contract_address_const};
use integer::{u128_try_from_felt252, u256_sqrt, u256_from_felt252};
use starknet::syscalls::{replace_class_syscall, call_contract_syscall};
mod utils;
use utils::{ deployer_addr, token0, token1, burn_addr, user1, user2 };
use starknet::testing;

// fn deploy_erc20(initial_supply: u256) -> (ContractAddress, ContractAddress) {
//     let erc20_class = declare('ERC20');

//     let mut token0_constructor_calldata = Default::default();
//     Serde::serialize(@TOKEN0_NAME, ref token0_constructor_calldata);
//     Serde::serialize(@SYMBOL, ref token0_constructor_calldata);
//     Serde::serialize(@initial_supply, ref token0_constructor_calldata);
//     Serde::serialize(@user1(), ref token0_constructor_calldata);
//     let token0_address = erc20_class.deploy(@token0_constructor_calldata).unwrap();

//     let mut token1_constructor_calldata = Default::default();
//     Serde::serialize(@TOKEN1_NAME, ref token1_constructor_calldata);
//     Serde::serialize(@SYMBOL, ref token1_constructor_calldata);
//     Serde::serialize(@initial_supply, ref token1_constructor_calldata);
//     Serde::serialize(@user1(), ref token1_constructor_calldata);
//     let token1_address = erc20_class.deploy(@token1_constructor_calldata).unwrap();

//     (token0_address, token1_address)
// }

#[starknet::interface]
trait IERC20<TContractState> {
    // view functions
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    // external functions
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn _mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    // external functions
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
}

#[starknet::interface]
trait IPairC1<T> {
    // view functions
    fn get_reserves(self: @T) -> (u256, u256, u64);
}

#[starknet::interface]
trait IRouterC1<T> {
    // view functions
    fn factory(self: @T) -> ContractAddress;
    fn sort_tokens(self: @T, tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress);
    // external functions
    fn add_liquidity(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress, amountADesired: u256, amountBDesired: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256, u256);
    fn remove_liquidity(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress, liquidity: u256, amountAMin: u256, amountBMin: u256, to: ContractAddress, deadline: u64) -> (u256, u256);
    fn swap_exact_tokens_for_tokens(ref self: T, amountIn: u256, amountOutMin: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
    fn swap_tokens_for_exact_tokens(ref self: T, amountOut: u256, amountInMax: u256, path: Array::<ContractAddress>, to: ContractAddress, deadline: u64) -> Array::<u256>;
}


const TOKEN_MULTIPLIER: u256 = 1000000000000000000;
const TOKEN0_NAME: felt252 = 'TOKEN0';
const TOKEN1_NAME: felt252 = 'TOKEN1';
const SYMBOL: felt252 = 'SYMBOL';
const MINIMUM_LIQUIDITY: u256 = 1000;

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

#[test]
fn test_erc20(){
    let initial_supply: u256 = 100 * TOKEN_MULTIPLIER;
    let mut erc20_state = ERC20::unsafe_new_contract_state();
    ERC20::InternalImpl::initializer(ref erc20_state, 'name', 'symbol');
    ERC20::InternalImpl::_mint(ref erc20_state, OWNER(), initial_supply);
}


// fn deploy_contracts() -> (ContractAddress, ContractAddress) {
//     let pair_class = declare('PairC1');

//     let mut factory_constructor_calldata = Default::default();
//     Serde::serialize(@pair_class.class_hash, ref factory_constructor_calldata);
//     Serde::serialize(@deployer_addr(), ref factory_constructor_calldata);
//     let factory_class = declare('FactoryC1');
    
//     let factory_address = factory_class.deploy(@factory_constructor_calldata).unwrap();

//     let mut router_constructor_calldata = Default::default();
//     Serde::serialize(@factory_address, ref router_constructor_calldata);
//     let router_class = declare('RouterC1');

//     let router_address = router_class.deploy(@router_constructor_calldata).unwrap();

//     (factory_address, router_address)
// }

// #[test]
// fn test_swap_exact_0_to_1(){
//     // Setup
//     let initial_supply: u256 = 100 * TOKEN_MULTIPLIER;
//     // let (factory_address, router_address) = deploy_contracts();
//     // let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
//     // let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

//     let mut erc20_state = ERC20::contract_state_for_testing();
//     ERC20::constructor(ref erc20_state, 'lol', 'SYMBOL', initial_supply, OWNER());
//     // ERC20::InternalImpl::initializer(ref erc20_state, 'name', 'symbol');
//     // ERC20::InternalImpl::_mint(ref erc20_state, OWNER(), initial_supply);
//     // erc20_state._mint(user2(), initial_supply);

//     // let initial_supply: u256 = 100 * TOKEN_MULTIPLIER;
//     // let (token0_address, token1_address) = deploy_erc20(initial_supply);
//     // let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
//     // let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
//     // let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

//     // // let mut erc20_state = ERC20::unsafe_new_contract_state();
//     // let mut erc20_state = ERC20::contract_state_for_testing();
//     // erc20_state.initializer('JediSwap Pair', 'JEDI-P');
//     // ERC20::InternalImpl::initializer(ref erc20_state, 'JediSwap Pair', 'JEDI-P');

//     // let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
//     // let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
//     // let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };
//     // let mut erc20_state = ERC20::contract_state_for_testing();
//     // ERC20::constructor(ref erc20_state, 'lol', 'SYMBOL', 1000, user1());
//     // InternalImpl::initializer(ref erc20_state, TOKEN0_NAME, SYMBOL);
//     // ERC20::InternalImpl::_mint(ref erc20_state, user2(), initial_supply);
//     // token0_erc20_dispatcher._mint(user2(), initial_supply);
//     // token1_erc20_dispatcher._mint(user2(), initial_supply);

//     // let amount_token0: u256 = 2 * TOKEN_MULTIPLIER;
//     // let amount_token1: u256 = 4 * TOKEN_MULTIPLIER;

//     // start_prank(token0_address, user1());
//     // token0_erc20_dispatcher.approve(router_address, amount_token0);
//     // stop_prank(token0_address);

//     // start_prank(token1_address, user1());
//     // token1_erc20_dispatcher.approve(router_address, amount_token1);
//     // stop_prank(token1_address);

//     // start_prank(router_address, user1());
//     // let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
//     //     token0_address, token1_address, amount_token0, amount_token1, 1, 1, user1(), 0);
//     // stop_prank(router_address);
// }