%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt
from starkware.cairo.common.pow import pow
from starkware.cairo.common.alloc import alloc

from contracts.utils.math import uint256_checked_add, uint256_checked_mul, uint256_checked_sub_le

const MINIMUM_LIQUIDITY = 1000
const BURN_ADDRESS = 1

@contract_interface
namespace IERC20:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func mint(recipient : felt, amount : Uint256):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end
end

@contract_interface
namespace IPair:
    func get_reserves() -> (reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt):
    end

    func swap(amount0Out : Uint256, amount1Out : Uint256, to : felt, data_len : felt, data : felt*):
    end
end

@contract_interface
namespace IRouter:
    func factory() -> (address : felt):
    end

    func sort_tokens(tokenA : felt, tokenB : felt) -> (token0 : felt, token1 : felt):
    end

    func add_liquidity(tokenA : felt, tokenB : felt, amountADesired : Uint256, amountBDesired : Uint256,
    amountAMin : Uint256, amountBMin : Uint256, to : felt, deadline : felt) -> (amountA : Uint256, amountB : Uint256, liquidity : Uint256):
    end

    func remove_liquidity(tokenA : felt, tokenB : felt, liquidity : Uint256, amountAMin : Uint256,
    amountBMin : Uint256, to : felt, deadline : felt) -> (amountA : Uint256, amountB : Uint256):
    end

    func swap_exact_tokens_for_tokens(amountIn : Uint256, amountOutMin : Uint256, path_len : felt,
    path : felt*, to : felt, deadline : felt) -> (amounts_len : felt, amounts : Uint256*):
    end

    func swap_tokens_for_exact_tokens(amountOut : Uint256, amountInMax : Uint256, path_len : felt,
    path : felt*, to : felt, deadline : felt) -> (amounts_len : felt, amounts : Uint256*):
    end
end

@contract_interface
namespace IFactory:
    func create_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end
    
    func get_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end

    func get_all_pairs() -> (all_pairs_len : felt, all_pairs : felt*):
    end
end

@external
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals

    tempvar deployer_address = 123456789987654321
    tempvar user_1_address = 987654321123456789
    tempvar user_2_address = 987654331133456789
    tempvar factory_address
    local router_address
    local token_0_address
    local token_1_address
    local flash_swap_test_address
    %{ 
        context.deployer_address = ids.deployer_address
        context.user_1_address = ids.user_1_address
        context.user_2_address = ids.user_2_address
        context.declared_class_hash = declare("contracts/Pair.cairo").class_hash
        context.factory_address = deploy_contract("contracts/Factory.cairo", [context.declared_class_hash, context.deployer_address]).contract_address
        context.router_address = deploy_contract("contracts/Router.cairo", [context.factory_address]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.flash_swap_test_address = deploy_contract("contracts/test/FlashSwapTest.cairo", [context.factory_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}
    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address)
    
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = sorted_token_0_address, token1 = sorted_token_1_address)

    %{
        context.sorted_token_0_address = ids.sorted_token_0_address
        context.sorted_token_1_address = ids.sorted_token_1_address
        context.pair_address = ids.pair_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=sorted_token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=sorted_token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)

    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.sorted_token_0_address) %}
    IERC20.mint(contract_address = sorted_token_0_address, recipient = user_1_address, amount = Uint256(amount_to_mint_token_0, 0))
    IERC20.mint(contract_address = sorted_token_0_address, recipient = user_2_address, amount = Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.sorted_token_1_address) %}
    IERC20.mint(contract_address = sorted_token_1_address, recipient = user_1_address, amount = Uint256(amount_to_mint_token_1, 0))
    IERC20.mint(contract_address = sorted_token_1_address, recipient = user_2_address, amount = Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}

    ### Add liquidity for first time
    
    let amount_token_0 = 20 * token_0_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.sorted_token_0_address) %}
    IERC20.approve(contract_address = sorted_token_0_address, spender = router_address, amount = Uint256(amount_token_0, 0))
    %{ stop_prank() %}
    
    let amount_token_1 = 40 * token_1_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.sorted_token_1_address) %}
    IERC20.approve(contract_address = sorted_token_1_address, spender = router_address, amount = Uint256(amount_token_1, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = sorted_token_0_address, tokenB = sorted_token_1_address, amountADesired = Uint256(amount_token_0, 0), amountBDesired = Uint256(amount_token_1, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_1_address, deadline = 0)
    %{ stop_prank() %}

    return ()
end

@external
func test_flash_swap_not_enough_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local token_0_address
    local token_1_address
    local router_address
    local user_2_address
    local pair_address
    local flash_swap_test_address

    %{  
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_2_address = context.user_2_address
        ids.pair_address = context.pair_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}

    let (user_2_token_0_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_0_address, account = user_2_address)
    let (user_2_token_1_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_1_address, account = user_2_address)
    let (reserve_0_initial : Uint256, reserve_1_initial : Uint256, _) = IPair.get_reserves(contract_address = pair_address)

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    local amount_token_0 = 200 * token_0_multiplier

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.pair_address) %}
    let data : felt* = alloc()
    assert [data] = 0
    %{ expect_revert(error_message="Pair::swap::insufficient liquidity") %}
    IPair.swap(contract_address = pair_address, amount0Out = Uint256(amount_token_0, 0), amount1Out = Uint256(0, 0), to = flash_swap_test_address, data_len = 1, data=data)
    %{ stop_prank() %}

    return()
end

@external
func test_flash_swap_no_repayment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local token_0_address
    local token_1_address
    local router_address
    local user_2_address
    local pair_address
    local flash_swap_test_address

    %{  
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_2_address = context.user_2_address
        ids.pair_address = context.pair_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}

    let (user_2_token_0_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_0_address, account = user_2_address)
    let (user_2_token_1_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_1_address, account = user_2_address)
    let (reserve_0_initial : Uint256, reserve_1_initial : Uint256, _) = IPair.get_reserves(contract_address = pair_address)

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    local amount_token_0 = 2 * token_0_multiplier

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.pair_address) %}
    let data : felt* = alloc()
    assert [data] = 0
    %{ expect_revert(error_message="Pair::swap::invariant K") %}
    IPair.swap(contract_address = pair_address, amount0Out = Uint256(amount_token_0, 0), amount1Out = Uint256(0, 0), to = flash_swap_test_address, data_len = 1, data=data)
    %{ stop_prank() %}

    return()
end

@external
func test_flash_swap_not_enough_repayment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local token_0_address
    local token_1_address
    local router_address
    local user_2_address
    local pair_address
    local flash_swap_test_address

    %{  
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_2_address = context.user_2_address
        ids.pair_address = context.pair_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}

    let (user_2_token_0_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_0_address, account = user_2_address)
    let (user_2_token_1_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_1_address, account = user_2_address)
    let (reserve_0_initial : Uint256, reserve_1_initial : Uint256, _) = IPair.get_reserves(contract_address = pair_address)

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    local amount_token_0 = 2 * token_0_multiplier

    let amount_to_mint_token_0 = amount_token_0 * 2 / 1000
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address = token_0_address, recipient = flash_swap_test_address, amount = Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.pair_address) %}
    let data : felt* = alloc()
    assert [data] = 0
    %{ expect_revert(error_message="Pair::swap::invariant K") %}
    IPair.swap(contract_address = pair_address, amount0Out = Uint256(amount_token_0, 0), amount1Out = Uint256(0, 0), to = flash_swap_test_address, data_len = 1, data=data)
    %{ stop_prank() %}

    return()
end

@external
func test_flash_swap_same_token_repayment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local token_0_address
    local token_1_address
    local router_address
    local user_2_address
    local pair_address
    local flash_swap_test_address

    %{  
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_2_address = context.user_2_address
        ids.pair_address = context.pair_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}

    let (user_2_token_0_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_0_address, account = user_2_address)
    let (user_2_token_1_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_1_address, account = user_2_address)
    let (reserve_0_initial : Uint256, reserve_1_initial : Uint256, _) = IPair.get_reserves(contract_address = pair_address)

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    local amount_token_0 = 2 * token_0_multiplier

    let amount_to_mint_token_0 = amount_token_0 * 4 / 1000
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address = token_0_address, recipient = flash_swap_test_address, amount = Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.pair_address) %}
    let data : felt* = alloc()
    assert [data] = 0
    IPair.swap(contract_address = pair_address, amount0Out = Uint256(amount_token_0, 0), amount1Out = Uint256(0, 0), to = flash_swap_test_address, data_len = 1, data=data)
    %{ stop_prank() %}

    %{ expect_events({"name": "Swap", "from_address": ids.pair_address, "data": [ids.user_2_address, ids.amount_token_0 + ids.amount_to_mint_token_0, 0, 0, 0, ids.amount_token_0, 0, 0, 0, ids.flash_swap_test_address]}) %}

    return()
end

@external
func test_flash_swap_other_token_repayment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local token_0_address
    local token_1_address
    local router_address
    local user_2_address
    local pair_address
    local flash_swap_test_address

    %{  
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_2_address = context.user_2_address
        ids.pair_address = context.pair_address
        ids.flash_swap_test_address = context.flash_swap_test_address
    %}

    let (user_2_token_0_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_0_address, account = user_2_address)
    let (user_2_token_1_balance_initial : Uint256) = IERC20.balanceOf(contract_address = token_1_address, account = user_2_address)
    let (reserve_0_initial : Uint256, reserve_1_initial : Uint256, _) = IPair.get_reserves(contract_address = pair_address)

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    local amount_token_0 = 2 * token_0_multiplier

    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)
    local amount_token_1 = 4 * token_1_multiplier
    let amount_to_mint_token_1 = amount_token_1 * 4 / 1000
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address = token_1_address, recipient = flash_swap_test_address, amount = Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.pair_address) %}
    let data : felt* = alloc()
    assert [data] = 0
    IPair.swap(contract_address = pair_address, amount0Out = Uint256(amount_token_0, 0), amount1Out = Uint256(0, 0), to = flash_swap_test_address, data_len = 1, data=data)
    %{ stop_prank() %}

    %{ expect_events({"name": "Swap", "from_address": ids.pair_address, "data": [ids.user_2_address, ids.amount_token_0, 0, ids.amount_to_mint_token_1, 0, ids.amount_token_0, 0, 0, 0, ids.flash_swap_test_address]}) %}

    return()
end