%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt
from starkware.cairo.common.pow import pow
from starkware.cairo.common.alloc import alloc

from contracts.utils.math import uint256_checked_add, uint256_checked_mul, uint256_checked_sub_le

const MINIMUM_LIQUIDITY = 1000;
const BURN_ADDRESS = 1;

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
namespace IPair {
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt) {
    }
}

@contract_interface
namespace IRouter {
    func factory() -> (address: felt) {
    }

    func sort_tokens(tokenA: felt, tokenB: felt) -> (token0: felt, token1: felt) {
    }

    func add_liquidity(
        tokenA: felt,
        tokenB: felt,
        amountADesired: Uint256,
        amountBDesired: Uint256,
        amountAMin: Uint256,
        amountBMin: Uint256,
        to: felt,
        deadline: felt,
    ) -> (amountA: Uint256, amountB: Uint256, liquidity: Uint256) {
    }

    func remove_liquidity(
        tokenA: felt,
        tokenB: felt,
        liquidity: Uint256,
        amountAMin: Uint256,
        amountBMin: Uint256,
        to: felt,
        deadline: felt,
    ) -> (amountA: Uint256, amountB: Uint256) {
    }

    func swap_exact_tokens_for_tokens(
        amountIn: Uint256,
        amountOutMin: Uint256,
        path_len: felt,
        path: felt*,
        to: felt,
        deadline: felt,
    ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func swap_tokens_for_exact_tokens(
        amountOut: Uint256,
        amountInMax: Uint256,
        path_len: felt,
        path: felt*,
        to: felt,
        deadline: felt,
    ) -> (amounts_len: felt, amounts: Uint256*) {
    }
}

@contract_interface
namespace IFactory {
    func create_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_all_pairs() -> (all_pairs_len: felt, all_pairs: felt*) {
    }

    func set_fee_to(new_fee_to: felt) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    tempvar deployer_address = 123456789987654321;
    tempvar user_1_address = 987654321123456789;
    tempvar user_2_address = 987654331133456789;
    tempvar fee_recipient_address = 987654301103456789;
    local factory_address;
    local router_address;
    local token_0_address;
    local token_1_address;
    %{
        context.deployer_address = ids.deployer_address
        context.user_1_address = ids.user_1_address
        context.user_2_address = ids.user_2_address
        context.fee_recipient_address = ids.fee_recipient_address
        context.declared_pair_class_hash = declare("contracts/Pair.cairo").class_hash
        stop_prank = start_prank(context.deployer_address)
        declared_factory = declare("contracts/Factory.cairo")
        prepared_factory = prepare(declared_factory, [context.declared_pair_class_hash])
        context.factory_address = prepared_factory.contract_address
        stop_prank = start_prank(ids.deployer_address, target_contract_address=context.factory_address)
        deploy(prepared_factory)
        stop_prank()
        context.router_address = deploy_contract("contracts/Router.cairo", [context.factory_address]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.factory_address) %}
    IFactory.set_fee_to(contract_address=factory_address, new_fee_to=fee_recipient_address);
    %{ stop_prank() %}

    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(
        contract_address=router_address, tokenA=token_0_address, tokenB=token_1_address
    );

    let (pair_address) = IFactory.create_pair(
        contract_address=factory_address,
        token0=sorted_token_0_address,
        token1=sorted_token_1_address,
    );

    %{
        context.sorted_token_0_address = ids.sorted_token_0_address
        context.sorted_token_1_address = ids.sorted_token_1_address
        context.pair_address = ids.pair_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=sorted_token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);

    let (token_1_decimals) = IERC20.decimals(contract_address=sorted_token_1_address);
    let (token_1_multiplier) = pow(10, token_1_decimals);

    let amount_to_mint_token_0 = 100 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.sorted_token_0_address) %}
    IERC20.mint(
        contract_address=sorted_token_0_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_0, 0),
    );
    IERC20.mint(
        contract_address=sorted_token_0_address,
        recipient=user_2_address,
        amount=Uint256(amount_to_mint_token_0, 0),
    );
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.sorted_token_1_address) %}
    IERC20.mint(
        contract_address=sorted_token_1_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_1, 0),
    );
    IERC20.mint(
        contract_address=sorted_token_1_address,
        recipient=user_2_address,
        amount=Uint256(amount_to_mint_token_1, 0),
    );
    %{ stop_prank() %}

    // ## Add liquidity for first time

    let amount_token_0 = 20 * token_0_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.sorted_token_0_address) %}
    IERC20.approve(
        contract_address=sorted_token_0_address,
        spender=router_address,
        amount=Uint256(amount_token_0, 0),
    );
    %{ stop_prank() %}

    let amount_token_1 = 40 * token_1_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.sorted_token_1_address) %}
    IERC20.approve(
        contract_address=sorted_token_1_address,
        spender=router_address,
        amount=Uint256(amount_token_1, 0),
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA: Uint256, amountB: Uint256, liquidity: Uint256) = IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=sorted_token_0_address,
        tokenB=sorted_token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    return ();
}

@external
func test_protocol_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local token_0_address;
    local token_1_address;
    local router_address;
    local user_1_address;
    local user_2_address;
    local fee_recipient_address;
    local pair_address;

    %{
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
        ids.fee_recipient_address = context.fee_recipient_address
        ids.pair_address = context.pair_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);
    local amount_token_0 = 2 * token_0_multiplier;

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(
        contract_address=token_0_address, spender=router_address, amount=Uint256(amount_token_0, 0)
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.router_address) %}
    let path: felt* = alloc();
    assert [path] = token_0_address;
    assert [path + 1] = token_1_address;
    let (amounts_len: felt, amounts: Uint256*) = IRouter.swap_exact_tokens_for_tokens(
        contract_address=router_address,
        amountIn=Uint256(amount_token_0, 0),
        amountOutMin=Uint256(0, 0),
        path_len=2,
        path=path,
        to=user_2_address,
        deadline=0,
    );
    %{ stop_prank() %}

    // ## Remove liquidity

    let (user_1_pair_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=user_1_address
    );

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.pair_address) %}
    IERC20.approve(
        contract_address=pair_address, spender=router_address, amount=user_1_pair_balance
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA_burn: Uint256, amountB_burn: Uint256) = IRouter.remove_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        liquidity=user_1_pair_balance,
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    let (fee_recipient_pair_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=fee_recipient_address
    );

    let (is_fee_recipient_pair_balance_greater_than_0) = uint256_lt(
        Uint256(0, 0), fee_recipient_pair_balance
    );
    assert is_fee_recipient_pair_balance_greater_than_0 = 1;

    return ();
}
