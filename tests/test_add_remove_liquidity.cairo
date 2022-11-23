%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt
from starkware.cairo.common.pow import pow

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
}

@contract_interface
namespace IFactory {
    func create_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_all_pairs() -> (all_pairs_len: felt, all_pairs: felt*) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address = 123456789987654321;
    tempvar user_1_address = 987654321123456789;
    tempvar factory_address;
    tempvar router_address;
    tempvar token_0_address;
    tempvar token_1_address;
    %{
        context.deployer_address = ids.deployer_address
        context.user_1_address = ids.user_1_address
        context.declared_pair_proxy_class_hash = declare("contracts/PairProxy.cairo").class_hash
        context.declared_pair_class_hash = declare("contracts/Pair.cairo").class_hash
        context.declared_factory_class_hash = declare("contracts/Factory.cairo").class_hash
        context.factory_address = deploy_contract("contracts/FactoryProxy.cairo", [context.declared_factory_class_hash, context.declared_pair_proxy_class_hash, context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.declared_router_class_hash = declare("contracts/Router.cairo").class_hash
        context.router_address = deploy_contract("contracts/RouterProxy.cairo", [context.declared_router_class_hash, context.factory_address, context.deployer_address]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}
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
    return ();
}

@external
func test_add_liquidity_expired_deadline{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    local token_0_address;
    local token_1_address;
    local router_address;

    %{
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.router_address = context.router_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);

    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address);
    let (token_1_multiplier) = pow(10, token_1_decimals);

    let amount_token_0 = 2 * token_0_multiplier;
    let amount_token_1 = 4 * token_1_multiplier;

    %{ stop_warp = warp(1, target_contract_address=ids.router_address) %}
    %{ expect_revert(error_message="Router::_ensure_deadline::expired") %}
    IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=100,
        deadline=0,
    );
    %{ stop_warp() %}

    return ();
}

@external
func test_add_remove_liquidity_created_pair{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    local token_0_address;
    local token_1_address;
    local router_address;
    local user_1_address;
    local pair_address;

    %{
        ids.token_0_address = context.sorted_token_0_address
        ids.token_1_address = context.sorted_token_1_address
        ids.router_address = context.router_address
        ids.user_1_address = context.user_1_address
        ids.pair_address = context.pair_address
    %}

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);

    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address);
    let (token_1_multiplier) = pow(10, token_1_decimals);

    let amount_to_mint_token_0 = 100 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(
        contract_address=token_0_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_0, 0),
    );
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(
        contract_address=token_1_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_1, 0),
    );
    %{ stop_prank() %}

    // ## Add liquidity for first time

    let amount_token_0 = 2 * token_0_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(
        contract_address=token_0_address, spender=router_address, amount=Uint256(amount_token_0, 0)
    );
    %{ stop_prank() %}

    let amount_token_1 = 4 * token_1_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(
        contract_address=token_1_address, spender=router_address, amount=Uint256(amount_token_1, 0)
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA: Uint256, amountB: Uint256, liquidity: Uint256) = IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    assert amountA = Uint256(amount_token_0, 0);
    assert amountB = Uint256(amount_token_1, 0);
    // assert float(liquidity) == pytest.approx(
    //     math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY)
    %{ expect_events({"name": "Mint", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA.low, ids.amountA.high, ids.amountB.low, ids.amountB.high]}) %}

    let (reserve_0: Uint256, reserve_1: Uint256, block_timestamp_last) = IPair.get_reserves(
        contract_address=pair_address
    );
    let (totalSupply: Uint256) = IERC20.totalSupply(contract_address=pair_address);

    let (totalSupply_mul_totalSupply: Uint256) = uint256_checked_mul(totalSupply, totalSupply);
    let (reserve_0_mul_reserve_1: Uint256) = uint256_checked_mul(reserve_0, reserve_1);

    let (is_total_supply_mul_lesser_than_equal_reserve_mul) = uint256_le(
        totalSupply_mul_totalSupply, reserve_0_mul_reserve_1
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul = 1;

    let (totalSupply_plus_1: Uint256) = uint256_checked_add(totalSupply, Uint256(1, 0));

    let (totalSupply1_mul_totalSupply1: Uint256) = uint256_checked_mul(
        totalSupply_plus_1, totalSupply_plus_1
    );

    let (is_total_supply_1_mul_greater_than_reserve_mul) = uint256_lt(
        reserve_0_mul_reserve_1, totalSupply1_mul_totalSupply1
    );
    assert is_total_supply_1_mul_greater_than_reserve_mul = 1;

    // ## Add liquidity to pair which already has liquidity

    let amount_token_0_again = 2 * token_0_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(
        contract_address=token_0_address, spender=router_address, amount=Uint256(amount_token_0, 0)
    );
    %{ stop_prank() %}

    let amount_token_1_again = 4 * token_1_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(
        contract_address=token_1_address, spender=router_address, amount=Uint256(amount_token_1, 0)
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (
        amountA_again: Uint256, amountB_again: Uint256, liquidity_again: Uint256
    ) = IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    assert amountA_again = Uint256(amount_token_0_again, 0);
    assert amountB_again = Uint256(amount_token_1_again, 0);
    // assert float(liquidity) == pytest.approx(
    //     math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY)
    %{ expect_events({"name": "Mint", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA_again.low, ids.amountA_again.high, ids.amountB_again.low, ids.amountB_again.high]}) %}

    let (
        reserve_0_again: Uint256, reserve_1_again: Uint256, block_timestamp_last_again
    ) = IPair.get_reserves(contract_address=pair_address);
    let (totalSupply_again: Uint256) = IERC20.totalSupply(contract_address=pair_address);

    let (totalSupply_mul_totalSupply_again: Uint256) = uint256_checked_mul(
        totalSupply_again, totalSupply_again
    );
    let (reserve_0_mul_reserve_1_again: Uint256) = uint256_checked_mul(
        reserve_0_again, reserve_1_again
    );

    let (is_total_supply_mul_lesser_than_equal_reserve_mul_again) = uint256_le(
        totalSupply_mul_totalSupply, reserve_0_mul_reserve_1
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul_again = 1;

    let (user_1_token_0_balance: Uint256) = IERC20.balanceOf(
        contract_address=token_0_address, account=user_1_address
    );

    let (expected_reserve_0: Uint256) = uint256_checked_sub_le(
        Uint256(amount_to_mint_token_0, 0), user_1_token_0_balance
    );
    assert expected_reserve_0 = reserve_0_again;

    let (user_1_token_1_balance: Uint256) = IERC20.balanceOf(
        contract_address=token_1_address, account=user_1_address
    );

    let (expected_reserve_1: Uint256) = uint256_checked_sub_le(
        Uint256(amount_to_mint_token_1, 0), user_1_token_1_balance
    );
    assert expected_reserve_1 = reserve_1_again;

    let (user_1_pair_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=user_1_address
    );

    let (expected_total_supply: Uint256) = uint256_checked_add(
        Uint256(MINIMUM_LIQUIDITY, 0), user_1_pair_balance
    );
    assert expected_total_supply = totalSupply_again;

    // ## Remove liquidity

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

    %{ expect_events({"name": "Burn", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA_burn.low, ids.amountA_burn.high, ids.amountB_burn.low, ids.amountB_burn.high, ids.user_1_address]}) %}

    let (user_1_pair_balance_burn: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=user_1_address
    );
    assert user_1_pair_balance_burn = Uint256(0, 0);

    let (totalSupply_burn: Uint256) = IERC20.totalSupply(contract_address=pair_address);
    assert totalSupply_burn = Uint256(MINIMUM_LIQUIDITY, 0);

    let (burn_address_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=BURN_ADDRESS
    );
    assert totalSupply_burn = burn_address_balance;

    let (
        reserve_0_burn: Uint256, reserve_1_burn: Uint256, block_timestamp_last_burn
    ) = IPair.get_reserves(contract_address=pair_address);

    let (totalSupply_mul_totalSupply_burn: Uint256) = uint256_checked_mul(
        totalSupply_burn, totalSupply_burn
    );
    let (reserve_0_mul_reserve_1_burn: Uint256) = uint256_checked_mul(
        reserve_0_burn, reserve_1_burn
    );

    let (is_total_supply_mul_lesser_than_equal_reserve_mul_burn) = uint256_le(
        totalSupply_mul_totalSupply_burn, reserve_0_mul_reserve_1_burn
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul_burn = 1;

    return ();
}

@external
func test_add_remove_liquidity_for_non_created_pair{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    local unsorted_token_0_address;
    local unsorted_token_1_address;
    local factory_address;
    local router_address;
    local user_1_address;

    %{
        ids.unsorted_token_0_address = context.token_0_address
        ids.unsorted_token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [33, 3, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.user_1_address = context.user_1_address
    %}

    let (token_0_address, token_1_address) = IRouter.sort_tokens(
        contract_address=router_address,
        tokenA=unsorted_token_0_address,
        tokenB=unsorted_token_1_address,
    );

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address);
    let (token_0_multiplier) = pow(10, token_0_decimals);

    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address);
    let (token_1_multiplier) = pow(10, token_1_decimals);

    let amount_to_mint_token_0 = 100 * token_0_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(
        contract_address=token_0_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_0, 0),
    );
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier;
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(
        contract_address=token_1_address,
        recipient=user_1_address,
        amount=Uint256(amount_to_mint_token_1, 0),
    );
    %{ stop_prank() %}

    // ## Add liquidity for first time

    let amount_token_0 = 2 * token_0_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(
        contract_address=token_0_address, spender=router_address, amount=Uint256(amount_token_0, 0)
    );
    %{ stop_prank() %}

    let amount_token_1 = 4 * token_1_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(
        contract_address=token_1_address, spender=router_address, amount=Uint256(amount_token_1, 0)
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA: Uint256, amountB: Uint256, liquidity: Uint256) = IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    assert amountA = Uint256(amount_token_0, 0);
    assert amountB = Uint256(amount_token_1, 0);
    // assert float(liquidity) == pytest.approx(
    //     math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY)

    let (pair_address) = IFactory.get_pair(
        contract_address=factory_address, token0=token_1_address, token1=token_0_address
    );

    %{ expect_events({"name": "Mint", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA.low, ids.amountA.high, ids.amountB.low, ids.amountB.high]}) %}

    let (reserve_0: Uint256, reserve_1: Uint256, block_timestamp_last) = IPair.get_reserves(
        contract_address=pair_address
    );
    let (totalSupply: Uint256) = IERC20.totalSupply(contract_address=pair_address);

    let (totalSupply_mul_totalSupply: Uint256) = uint256_checked_mul(totalSupply, totalSupply);
    let (reserve_0_mul_reserve_1: Uint256) = uint256_checked_mul(reserve_0, reserve_1);

    let (is_total_supply_mul_lesser_than_equal_reserve_mul) = uint256_le(
        totalSupply_mul_totalSupply, reserve_0_mul_reserve_1
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul = 1;

    let (totalSupply_plus_1: Uint256) = uint256_checked_add(totalSupply, Uint256(1, 0));

    let (totalSupply1_mul_totalSupply1: Uint256) = uint256_checked_mul(
        totalSupply_plus_1, totalSupply_plus_1
    );

    let (is_total_supply_1_mul_greater_than_reserve_mul) = uint256_lt(
        reserve_0_mul_reserve_1, totalSupply1_mul_totalSupply1
    );
    assert is_total_supply_1_mul_greater_than_reserve_mul = 1;

    // ## Add liquidity to pair which already has liquidity

    let amount_token_0_again = 2 * token_0_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(
        contract_address=token_0_address, spender=router_address, amount=Uint256(amount_token_0, 0)
    );
    %{ stop_prank() %}

    let amount_token_1_again = 4 * token_1_multiplier;
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(
        contract_address=token_1_address, spender=router_address, amount=Uint256(amount_token_1, 0)
    );
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (
        amountA_again: Uint256, amountB_again: Uint256, liquidity_again: Uint256
    ) = IRouter.add_liquidity(
        contract_address=router_address,
        tokenA=token_0_address,
        tokenB=token_1_address,
        amountADesired=Uint256(amount_token_0, 0),
        amountBDesired=Uint256(amount_token_1, 0),
        amountAMin=Uint256(1, 0),
        amountBMin=Uint256(1, 0),
        to=user_1_address,
        deadline=0,
    );
    %{ stop_prank() %}

    assert amountA_again = Uint256(amount_token_0_again, 0);
    assert amountB_again = Uint256(amount_token_1_again, 0);
    // assert float(liquidity) == pytest.approx(
    //     math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY)
    %{ expect_events({"name": "Mint", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA_again.low, ids.amountA_again.high, ids.amountB_again.low, ids.amountB_again.high]}) %}

    let (
        reserve_0_again: Uint256, reserve_1_again: Uint256, block_timestamp_last_again
    ) = IPair.get_reserves(contract_address=pair_address);
    let (totalSupply_again: Uint256) = IERC20.totalSupply(contract_address=pair_address);

    let (totalSupply_mul_totalSupply_again: Uint256) = uint256_checked_mul(
        totalSupply_again, totalSupply_again
    );
    let (reserve_0_mul_reserve_1_again: Uint256) = uint256_checked_mul(
        reserve_0_again, reserve_1_again
    );

    let (is_total_supply_mul_lesser_than_equal_reserve_mul_again) = uint256_le(
        totalSupply_mul_totalSupply, reserve_0_mul_reserve_1
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul_again = 1;

    let (user_1_token_0_balance: Uint256) = IERC20.balanceOf(
        contract_address=token_0_address, account=user_1_address
    );

    let (expected_reserve_0: Uint256) = uint256_checked_sub_le(
        Uint256(amount_to_mint_token_0, 0), user_1_token_0_balance
    );
    assert expected_reserve_0 = reserve_0_again;

    let (user_1_token_1_balance: Uint256) = IERC20.balanceOf(
        contract_address=token_1_address, account=user_1_address
    );

    let (expected_reserve_1: Uint256) = uint256_checked_sub_le(
        Uint256(amount_to_mint_token_1, 0), user_1_token_1_balance
    );
    assert expected_reserve_1 = reserve_1_again;

    let (user_1_pair_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=user_1_address
    );

    let (expected_total_supply: Uint256) = uint256_checked_add(
        Uint256(MINIMUM_LIQUIDITY, 0), user_1_pair_balance
    );
    assert expected_total_supply = totalSupply_again;

    // ## Remove liquidity

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

    %{ expect_events({"name": "Burn", "from_address": ids.pair_address, "data": [ids.router_address, ids.amountA_burn.low, ids.amountA_burn.high, ids.amountB_burn.low, ids.amountB_burn.high, ids.user_1_address]}) %}

    let (user_1_pair_balance_burn: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=user_1_address
    );
    assert user_1_pair_balance_burn = Uint256(0, 0);

    let (totalSupply_burn: Uint256) = IERC20.totalSupply(contract_address=pair_address);
    assert totalSupply_burn = Uint256(MINIMUM_LIQUIDITY, 0);

    let (burn_address_balance: Uint256) = IERC20.balanceOf(
        contract_address=pair_address, account=BURN_ADDRESS
    );
    assert totalSupply_burn = burn_address_balance;

    let (
        reserve_0_burn: Uint256, reserve_1_burn: Uint256, block_timestamp_last_burn
    ) = IPair.get_reserves(contract_address=pair_address);

    let (totalSupply_mul_totalSupply_burn: Uint256) = uint256_checked_mul(
        totalSupply_burn, totalSupply_burn
    );
    let (reserve_0_mul_reserve_1_burn: Uint256) = uint256_checked_mul(
        reserve_0_burn, reserve_1_burn
    );

    let (is_total_supply_mul_lesser_than_equal_reserve_mul_burn) = uint256_le(
        totalSupply_mul_totalSupply_burn, reserve_0_mul_reserve_1_burn
    );
    assert is_total_supply_mul_lesser_than_equal_reserve_mul_burn = 1;

    return ();
}
