use starknet:: { ContractAddress, ClassHash, contract_address_try_from_felt252 };
use snforge_std::{ declare, ContractClassTrait, ContractClass, start_prank, stop_prank,
                   spy_events, SpyOn, EventSpy, EventFetcher, Event, EventAssertions };

use jediswap::PairC1;
use tests::utils::{ deployer_addr, user1, user2, TOKEN_MULTIPLIER, TOKEN0_NAME,
                    TOKEN1_NAME, SYMBOL };

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
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IFactoryC1<T> {
    // view functions
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    fn get_all_pairs(self: @T) -> (u32, Array::<ContractAddress>);
    fn create_pair(ref self: T, tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress;
}

#[starknet::interface]
trait IPairC1<T> {
    // view functions
    fn get_reserves(self: @T) -> (u256, u256, u64);
    // external functions
    fn swap(ref self: T, amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>);
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

#[starknet::interface]
trait IFlashSwapTest<T> {
    // external functions
    fn jediswap_call(ref self: T, sender: ContractAddress, amount0Out: u256, amount1Out: u256, data: Array::<felt252>);
}

fn fee_recipient() -> ContractAddress {
    contract_address_try_from_felt252('fee recipient').unwrap()
}


fn deploy_erc20(erc20_amount_per_user: u256) -> (ContractAddress, ContractAddress) {
    let erc20_class = declare('ERC20');
    let initial_supply: u256 = erc20_amount_per_user * 2;

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


#[test]
fn test_flash_swap_not_enough_liquidity(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let mut flash_swap_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref flash_swap_constructor_calldata);
    let flash_swap_class = declare('FlashSwapTest');
    let flash_swap_address = flash_swap_class.deploy(@flash_swap_constructor_calldata).unwrap();

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    // Need to use transfer method becuase calling the _mint internal method on erc20 is not supported yet
    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token0_address);

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token1_address);

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(router_address);

    // Actual test

    let amount_token_0: u256 = 200 * TOKEN_MULTIPLIER;
    let pair_safe_dispatcher = IPairC1SafeDispatcher { contract_address: pair_address };

    let mut data = ArrayTrait::<felt252>::new();
    data.append(0);
    start_prank(pair_address, user2());
        match pair_safe_dispatcher.swap(amount_token_0, 0, flash_swap_address, data) {
            Result::Ok(_) => panic_with_felt252('Should have panicked'),
            Result::Err(panic_data) => {
                assert(*panic_data.at(0) == 'insufficient liquidity', *panic_data.at(0));
            }
        };
    stop_prank(pair_address);
}

#[test]
fn test_flash_swap_no_repayment(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let mut flash_swap_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref flash_swap_constructor_calldata);
    let flash_swap_class = declare('FlashSwapTest');
    let flash_swap_address = flash_swap_class.deploy(@flash_swap_constructor_calldata).unwrap();

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    // Need to use transfer method becuase calling the _mint internal method on erc20 is not supported yet
    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token0_address);

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token1_address);

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(router_address);

    // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;
    let pair_safe_dispatcher = IPairC1SafeDispatcher { contract_address: pair_address };

    let mut data = ArrayTrait::<felt252>::new();
    data.append(0);
    start_prank(pair_address, user2());
        match pair_safe_dispatcher.swap(amount_token_0, 0, flash_swap_address, data) {
            Result::Ok(_) => panic_with_felt252('Should have panicked'),
            Result::Err(panic_data) => {
                assert(*panic_data.at(0) == 'invariant K', *panic_data.at(0));
            }
        };
    stop_prank(pair_address);
}

#[test]
fn test_flash_swap_not_enough_repayment(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let mut flash_swap_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref flash_swap_constructor_calldata);
    let flash_swap_class = declare('FlashSwapTest');
    let flash_swap_address = flash_swap_class.deploy(@flash_swap_constructor_calldata).unwrap();

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    // Need to use transfer method becuase calling the _mint internal method on erc20 is not supported yet
    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token0_address);

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token1_address);

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(router_address);

    // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;
    let amount_to_transfer_token_0: u256 = (amount_token_0 * 2) / 1000;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(flash_swap_address, amount_to_transfer_token_0);
    stop_prank(token0_address);

    let flash_swap_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(flash_swap_address);
    assert(flash_swap_token_0_balance_initial == amount_to_transfer_token_0, 'swapflash token0 eq init amount');

    let pair_safe_dispatcher = IPairC1SafeDispatcher { contract_address: pair_address };

    let mut data = ArrayTrait::<felt252>::new();
    data.append(0);
    start_prank(pair_address, user2());
        match pair_safe_dispatcher.swap(amount_token_0, 0, flash_swap_address, data) {
            Result::Ok(_) => panic_with_felt252('Should have panicked'),
            Result::Err(panic_data) => {
                assert(*panic_data.at(0) == 'invariant K', *panic_data.at(0));
            }
        };
    stop_prank(pair_address);
}

#[test]
fn test_flash_swap_same_token_repayment(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let mut flash_swap_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref flash_swap_constructor_calldata);
    let flash_swap_class = declare('FlashSwapTest');
    let flash_swap_address = flash_swap_class.deploy(@flash_swap_constructor_calldata).unwrap();

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    // Need to use transfer method becuase calling the _mint internal method on erc20 is not supported yet
    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token0_address);

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token1_address);

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(router_address);

    // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;
    let amount_to_transfer_token_0: u256 = (amount_token_0 * 4) / 1000;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(flash_swap_address, amount_to_transfer_token_0);
    stop_prank(token0_address);

    let flash_swap_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(flash_swap_address);
    assert(flash_swap_token_0_balance_initial == amount_to_transfer_token_0, 'swapflash token0 eq init amount');

    let mut data = ArrayTrait::<felt252>::new();
    data.append(0);
    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(pair_address, user2());
    pair_dispatcher.swap(amount_token_0, 0, flash_swap_address, data);
    stop_prank(pair_address);

    let amount0In: u256 = amount_token_0 + amount_to_transfer_token_0;

    spy.assert_emitted(@array![
        (
            pair_address,
            PairC1::PairC1::Event::Swap(
                PairC1::PairC1::Swap {sender: user2(), amount0In: amount0In, amount1In: 0_u256, 
                                      amount0Out: amount_token_0, amount1Out: 0_u256, to: flash_swap_address}
            )
        )
    ]);
}

#[test]
fn test_flash_swap_other_token_repayment(){
    // Setup
    let (factory_address, router_address) = deploy_contracts();
    let factory_dispatcher = IFactoryC1Dispatcher { contract_address: factory_address };
    let router_dispatcher = IRouterC1Dispatcher { contract_address: router_address };

    let mut flash_swap_constructor_calldata = Default::default();
    Serde::serialize(@factory_address, ref flash_swap_constructor_calldata);
    let flash_swap_class = declare('FlashSwapTest');
    let flash_swap_address = flash_swap_class.deploy(@flash_swap_constructor_calldata).unwrap();

    let erc20_amount_per_user: u256 = 100 * TOKEN_MULTIPLIER;
    let (token0_address, token1_address) = deploy_erc20(erc20_amount_per_user);
    let (sorted_token0_address, sorted_token1_address) = router_dispatcher.sort_tokens(token0_address, token1_address);
    let pair_address = factory_dispatcher.create_pair(sorted_token0_address, sorted_token1_address);
    let pair_dispatcher = IPairC1Dispatcher { contract_address: pair_address };

    let (token0_address, token1_address) = (sorted_token0_address, sorted_token1_address);
    let token0_erc20_dispatcher = IERC20Dispatcher { contract_address: token0_address };
    let token1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1_address };

    // Need to use transfer method becuase calling the _mint internal method on erc20 is not supported yet
    start_prank(token0_address, user1());
    token0_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token0_address);

    let user_1_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user1());
    let user_2_token_0_balance_initial: u256 = token0_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_0_balance_initial == erc20_amount_per_user, 'user1 token0 eq initial amount');
    assert(user_2_token_0_balance_initial == erc20_amount_per_user, 'user2 token0 eq initial amount');

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(user2(), erc20_amount_per_user);
    stop_prank(token1_address);

    let user_1_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user1());
    let user_2_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(user2());
    assert(user_1_token_1_balance_initial == erc20_amount_per_user, 'user1 token1 eq initial amount');
    assert(user_2_token_1_balance_initial == erc20_amount_per_user, 'user2 token1 eq initial amount');

    let amount_token0_liq: u256 = 20 * TOKEN_MULTIPLIER;
    let amount_token1_liq: u256 = 40 * TOKEN_MULTIPLIER;

    start_prank(token0_address, user1());
    token0_erc20_dispatcher.approve(router_address, amount_token0_liq);
    stop_prank(token0_address);

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.approve(router_address, amount_token1_liq);
    stop_prank(token1_address);

    start_prank(router_address, user1());
    let (amountA, amountB, liquidity) = router_dispatcher.add_liquidity(
        token0_address, token1_address, amount_token0_liq, amount_token1_liq, 1, 1, user1(), 0);
    stop_prank(router_address);

    // Actual test

    let amount_token_0: u256 = 2 * TOKEN_MULTIPLIER;
    let amount_token_1: u256 = 4 * TOKEN_MULTIPLIER;
    let amount_to_transfer_token_1: u256 = (amount_token_1 * 4) / 1000;

    start_prank(token1_address, user1());
    token1_erc20_dispatcher.transfer(flash_swap_address, amount_to_transfer_token_1);
    stop_prank(token1_address);

    let flash_swap_token_1_balance_initial: u256 = token1_erc20_dispatcher.balance_of(flash_swap_address);
    assert(flash_swap_token_1_balance_initial == amount_to_transfer_token_1, 'swapflash token0 eq init amount');

    let mut data = ArrayTrait::<felt252>::new();
    data.append(0);
    let mut spy = spy_events(SpyOn::One(pair_address));
    start_prank(pair_address, user2());
    pair_dispatcher.swap(amount_token_0, 0, flash_swap_address, data);
    stop_prank(pair_address);

    spy.assert_emitted(@array![
        (
            pair_address,
            PairC1::PairC1::Event::Swap(
                PairC1::PairC1::Swap {sender: user2(), amount0In: amount_token_0, amount1In: amount_to_transfer_token_1, 
                                      amount0Out: amount_token_0, amount1Out: 0_u256, to: flash_swap_address}
            )
        )
    ]);
}