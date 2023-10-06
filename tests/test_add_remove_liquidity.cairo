use starknet:: { ContractAddress, ClassHash };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_warp, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };

use tests::utils::{ deployer_addr, token0, token1, burn_addr, user1, TOKEN_MULTIPLIER, TOKEN0_NAME,
                    TOKEN1_NAME, SYMBOL, MINIMUM_LIQUIDITY };

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
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
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
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn get_reserves(self: @T) -> (u256, u256, u64);
    fn total_supply(self: @T) -> u256;
    // external functions
    fn approve(ref self: T, spender: ContractAddress, amount: u256) -> bool;
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

fn deploy_contracts() -> (ContractAddress, ContractAddress) {
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

    (factory_address, router_address)
}

fn deploy_erc20(initial_supply: u256) -> (ContractAddress, ContractAddress) {
    let erc20_class = declare('ERC20');

    let mut token0_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN0_NAME, ref token0_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token0_constructor_calldata);
    Serde::serialize(@initial_supply, ref token0_constructor_calldata);
    Serde::serialize(@user1(), ref token0_constructor_calldata);
    let token0_address = erc20_class.deploy(@token0_constructor_calldata).unwrap();

    let mut token1_constructor_calldata = Default::default();
    Serde::serialize(@TOKEN1_NAME, ref token1_constructor_calldata);
    Serde::serialize(@SYMBOL, ref token1_constructor_calldata);
    Serde::serialize(@initial_supply, ref token1_constructor_calldata);
    Serde::serialize(@user1(), ref token1_constructor_calldata);
    let token1_address = erc20_class.deploy(@token1_constructor_calldata).unwrap();

    (token0_address, token1_address)
}

#[test]
fn test_add_liquidity_expired_deadline() {
    let (_, router_address) = deploy_contracts();
    let router_safe_dispatcher = IRouterC1SafeDispatcher { contract_address: router_address };

    let token_amount: u256 = 1;
    let min_amount: u256 = 1;
    let deadline: u64 = 0;

    start_warp(router_address, 1);
     match router_safe_dispatcher.add_liquidity(token0(), token1(), token_amount, token_amount, 
                                                min_amount, min_amount, user1(), deadline) {
        Result::Ok(_) => panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'expired', *panic_data.at(0));
        }
    };

}

#[test]
fn test_add_remove_liquidity_created_pair(){
    // Setup

    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let initial_supply: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(initial_supply);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    let amount_token0: u256 = 2 * TOKEN_MULTIPLIER;
    let amount_token1: u256 = 4 * TOKEN_MULTIPLIER;

    // Add liquidity for first time

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1);
    stop_prank(token1_address);

    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(pair_address, user1());
    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0, amount_token1, 1, 1, user1(), 0);
    stop_prank(pair_address);
    stop_prank(router_address);

    assert(amountA == amount_token0, 'amountA should be equal');
    assert(amountB == amount_token1, 'amountB should be equal');

    let mut event_data = Default::default();
    Serde::serialize(@user1(), ref event_data);
    Serde::serialize(@amount_token0, ref event_data);
    Serde::serialize(@amount_token1, ref event_data);
    spy.assert_emitted(@array![
        Event { from: pair_address, name: 'Mint', keys: array![], data: event_data }
    ]);

    let (reserve_0, reserve_1, _) = pair_dispatcher.get_reserves();
    let totalSupply: u256 = pair_dispatcher.total_supply();

    let totalSupply_mul_totalSupply: u256 = totalSupply * totalSupply;
    let reserve_0_mul_reserve_1: u256 = reserve_0 * reserve_1;
    assert(totalSupply_mul_totalSupply <= reserve_0_mul_reserve_1, 'totalSupply_mul less or equal');

    let totalSupply1_mul_totalSupply1: u256 = (totalSupply + 1_u256) * (totalSupply + 1_u256);
    assert(totalSupply1_mul_totalSupply1 > reserve_0_mul_reserve_1, 'totalSupply_mul greater');

    // Add liquidity to pair which already has liquidity

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1);
    stop_prank(token1_address);

    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(pair_address, user1());
    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0, amount_token1, 1, 1, user1(), 0);
    stop_prank(pair_address);
    stop_prank(router_address);

    assert(amountA == amount_token0, 'amountA again should be equal');
    assert(amountB == amount_token1, 'amountB again should be equal');

    let mut event_data = Default::default();
    Serde::serialize(@user1(), ref event_data);
    Serde::serialize(@amount_token0, ref event_data);
    Serde::serialize(@amount_token1, ref event_data);
    spy.assert_emitted(@array![
        Event { from: pair_address, name: 'Mint', keys: array![], data: event_data }
    ]);

    let (reserve_0, reserve_1, _) = pair_dispatcher.get_reserves();
    let totalSupply: u256 = pair_dispatcher.total_supply();

    let totalSupply_mul_totalSupply: u256 = totalSupply * totalSupply;
    let reserve_0_mul_reserve_1: u256 = reserve_0 * reserve_1;
    assert(totalSupply_mul_totalSupply <= reserve_0_mul_reserve_1, 'totalSupply_mul again less');

    let user_1_token_0_balance: u256 = token0_erc20_dispatcher.balance_of(user1());
    let expected_reserve_0: u256 = initial_supply - user_1_token_0_balance;
    assert(expected_reserve_0 == reserve_0, 'reserve_0 should be equal');

    let user_1_token_1_balance: u256 = token1_erc20_dispatcher.balance_of(user1());
    let expected_reserve_1: u256 = initial_supply - user_1_token_1_balance;
    assert(expected_reserve_1 == reserve_1, 'reserve_1 should be equal');

    let user_1_pair_balance: u256 = pair_dispatcher.balance_of(user1());
    let expected_total_supply: u256 = MINIMUM_LIQUIDITY + user_1_pair_balance;
    assert(expected_total_supply == totalSupply, 'totalSupply should be equal');

    // Remove liquidity

    start_prank(pair_address, user1());
    pair_dispatcher.approve(router_address, user_1_pair_balance);
    stop_prank(pair_address);

    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(router_address, user1());
    let (amountA_burn, amountB_burn) = router_dispatcher.remove_liquidity(
        token0_address, token1_address, user_1_pair_balance, 1, 1, user1(), 0);
    stop_prank(router_address);

    let mut event_data = Default::default();
    Serde::serialize(@router_address, ref event_data);
    Serde::serialize(@amountA_burn, ref event_data);
    Serde::serialize(@amountB_burn, ref event_data);
    Serde::serialize(@user1(), ref event_data);
    spy.assert_emitted(@array![
        Event { from: pair_address, name: 'Burn', keys: array![], data: event_data }
    ]);

    let user_1_pair_balance_burn: u256 = pair_dispatcher.balance_of(user1());
    assert(user_1_pair_balance_burn == 0, 'user balance should be zero');

    let totalSupply_burn: u256 = pair_dispatcher.total_supply();
    assert(totalSupply_burn == MINIMUM_LIQUIDITY, 'totalSupply should be min liq');

    let burn_address_balance: u256 = pair_dispatcher.balance_of(burn_addr());
    assert(totalSupply_burn == burn_address_balance, 'totalSupply == burn balance');

    let (reserve_0_burn, reserve_1_burn, _) = pair_dispatcher.get_reserves();
    let totalSupply_mul_totalSupply_burn: u256 = totalSupply_burn * totalSupply_burn;
    let reserve_0_mul_reserve_1_burn: u256 = reserve_0_burn * reserve_1_burn;
    assert(totalSupply_mul_totalSupply_burn <= reserve_0_mul_reserve_1_burn, 'totalSupply mul <= reserve')
}


#[test]
fn test_add_remove_liquidity_for_non_created_pair(){
    // Setup

    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let initial_supply: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(initial_supply);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    let amount_token0: u256 = 2 * TOKEN_MULTIPLIER;
    let amount_token1: u256 = 4 * TOKEN_MULTIPLIER;

    // Add liquidity for first time

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0, amount_token1, 1, 1, user1(), 0);
    stop_prank(router_address);

    assert(amountA == amount_token0, 'amountA again should be equal');
    assert(amountB == amount_token1, 'amountB again should be equal');

    let pair_address: ContractAddress = factory_dispatcher.get_pair(token1_address, token0_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (reserve_0, reserve_1, _) = pair_dispatcher.get_reserves();
    let totalSupply: u256 = pair_dispatcher.total_supply();

    let totalSupply_mul_totalSupply: u256 = totalSupply * totalSupply;
    let reserve_0_mul_reserve_1: u256 = reserve_0 * reserve_1;
    assert(totalSupply_mul_totalSupply <= reserve_0_mul_reserve_1, 'totalSupply_mul less or equal');

    let totalSupply1_mul_totalSupply1: u256 = (totalSupply + 1_u256) * (totalSupply + 1_u256);
    assert(totalSupply1_mul_totalSupply1 > reserve_0_mul_reserve_1, 'totalSupply_mul greater');

    // Add liquidity to pair which already has liquidity

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1);
    stop_prank(token1_address);

    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(pair_address, user1());
    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0, amount_token1, 1, 1, user1(), 0);
    stop_prank(pair_address);
    stop_prank(router_address);

    assert(amountA == amount_token0, 'amountA again should be equal');
    assert(amountB == amount_token1, 'amountB again should be equal');

    let mut event_data = Default::default();
    Serde::serialize(@user1(), ref event_data);
    Serde::serialize(@amount_token0, ref event_data);
    Serde::serialize(@amount_token1, ref event_data);
    spy.assert_emitted(@array![
        Event { from: pair_address, name: 'Mint', keys: array![], data: event_data }
    ]);

    let (reserve_0, reserve_1, _) = pair_dispatcher.get_reserves();
    let totalSupply: u256 = pair_dispatcher.total_supply();

    let totalSupply_mul_totalSupply: u256 = totalSupply * totalSupply;
    let reserve_0_mul_reserve_1: u256 = reserve_0 * reserve_1;
    assert(totalSupply_mul_totalSupply <= reserve_0_mul_reserve_1, 'totalSupply_mul again less');

    let user_1_token_0_balance: u256 = token0_erc20_dispatcher.balance_of(user1());
    let expected_reserve_0: u256 = initial_supply - user_1_token_0_balance;
    assert(expected_reserve_0 == reserve_0, 'reserve_0 should be equal');

    let user_1_token_1_balance: u256 = token1_erc20_dispatcher.balance_of(user1());
    let expected_reserve_1: u256 = initial_supply - user_1_token_1_balance;
    assert(expected_reserve_1 == reserve_1, 'reserve_1 should be equal');

    let user_1_pair_balance: u256 = pair_dispatcher.balance_of(user1());
    let expected_total_supply: u256 = MINIMUM_LIQUIDITY + user_1_pair_balance;
    assert(expected_total_supply == totalSupply, 'totalSupply should be equal');

    // Remove liquidity

    start_prank(pair_address, user1());
    pair_dispatcher.approve(router_address, user_1_pair_balance);
    stop_prank(pair_address);

    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(router_address, user1());
    let (amountA_burn, amountB_burn) = router_dispatcher.remove_liquidity(
        token0_address, token1_address, user_1_pair_balance, 1, 1, user1(), 0);
    stop_prank(router_address);

    let mut event_data = Default::default();
    Serde::serialize(@router_address, ref event_data);
    Serde::serialize(@amountA_burn, ref event_data);
    Serde::serialize(@amountB_burn, ref event_data);
    Serde::serialize(@user1(), ref event_data);
    spy.assert_emitted(@array![
        Event { from: pair_address, name: 'Burn', keys: array![], data: event_data }
    ]);

    let user_1_pair_balance_burn: u256 = pair_dispatcher.balance_of(user1());
    assert(user_1_pair_balance_burn == 0, 'user balance should be zero');

    let totalSupply_burn: u256 = pair_dispatcher.total_supply();
    assert(totalSupply_burn == MINIMUM_LIQUIDITY, 'totalSupply should be min liq');

    let burn_address_balance: u256 = pair_dispatcher.balance_of(burn_addr());
    assert(totalSupply_burn == burn_address_balance, 'totalSupply == burn balance');

    let (reserve_0_burn, reserve_1_burn, _) = pair_dispatcher.get_reserves();
    let totalSupply_mul_totalSupply_burn: u256 = totalSupply_burn * totalSupply_burn;
    let reserve_0_mul_reserve_1_burn: u256 = reserve_0_burn * reserve_1_burn;
    assert(totalSupply_mul_totalSupply_burn <= reserve_0_mul_reserve_1_burn, 'totalSupply mul <= reserve')
}