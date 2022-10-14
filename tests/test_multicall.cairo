%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_number

@contract_interface
namespace IERC20 {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func mint(recipient: felt, amount: Uint256) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }
}

@contract_interface
namespace IMulticall {
    func aggregate(calls_len: felt, calls: felt*) -> (block_number: felt, result_len: felt, result: felt*) {
    }

    func get_current_block_timestamp() -> (block_timestamp: felt) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address = 123456789987654321;
    tempvar user_0_address = 987654321123456789;
    tempvar user_1_address = 987654331133456789;
    tempvar multicall_address;
    tempvar token_0_address;
    tempvar token_1_address;
    %{
        context.deployer_address = ids.deployer_address
        context.user_0_address = ids.user_0_address
        context.user_1_address = ids.user_1_address
        context.multicall_address = deploy_contract("contracts/utils/Multicall.cairo").contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.multicall_address = context.multicall_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    let amount_to_mint_token = 1000;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(
        contract_address=token_0_address,
        recipient=user_0_address,
        amount=Uint256(amount_to_mint_token, 0),
    );
    %{ stop_prank() %}
    
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(
        contract_address=token_1_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token, 0),
    );
    %{ stop_prank() %}
    return ();
}

@external
func test_multicall{syscall_ptr: felt*, range_check_ptr}() {
    tempvar user_0_address;
    tempvar user_1_address;
    tempvar multicall_address;
    tempvar token_0_address;
    tempvar token_1_address;

    %{ 
        ids.user_0_address = context.user_0_address
        ids.user_1_address = context.user_1_address
        ids.multicall_address = context.multicall_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    let calls: felt* = alloc();
    let call_1: felt* = alloc();
    let call_2: felt* = alloc();
    let call_3: felt* = alloc();
    let call_4: felt* = alloc();

    assert [calls] = token_0_address;
    assert [calls + 1] = 134830404806214277570220174593674215737759987247891306080029841794115377321;   // get_selector_from_name('decimals')
    assert [calls + 2] = 0;

    assert [calls + 3] = token_1_address;
    assert [calls + 4] = 134830404806214277570220174593674215737759987247891306080029841794115377321;   // get_selector_from_name('decimals')
    assert [calls + 5] = 0;

    assert [calls + 6] = token_0_address;
    assert [calls + 7] = 1307730684388977109649524593492043083703013045633289330664425380824804018030;   // get_selector_from_name('balanceOf')
    assert [calls + 8] = 1;
    assert [calls + 9] = user_0_address;

    assert [calls + 10] = token_1_address;
    assert [calls + 11] = 1307730684388977109649524593492043083703013045633289330664425380824804018030;   // get_selector_from_name('balanceOf')
    assert [calls + 12] = 1;
    assert [calls + 13] = user_1_address;
    

    %{ stop_roll = roll(123, target_contract_address=ids.multicall_address) %}
    let (block_number: felt, result_len: felt, result: felt*) = IMulticall.aggregate(
        contract_address=multicall_address, calls_len=14, calls=calls
    );
    %{ stop_roll() %}

    assert block_number = 123;
    assert [result] = 18;
    assert [result + 1] = 6;
    assert [result + 2] = 1000;
    assert [result + 4] = 1000;

    return ();
}

@external
func test_multicall_timestamp{syscall_ptr: felt*, range_check_ptr}() {
    tempvar multicall_address;

    %{ 
        ids.multicall_address = context.multicall_address
    %}

    %{ stop_warp = warp(123456, target_contract_address=ids.multicall_address) %}
    let (block_timestamp: felt) = IMulticall.get_current_block_timestamp(
        contract_address=multicall_address
    );
    %{ stop_warp() %}

    assert block_timestamp = 123456;

    return ();
}
