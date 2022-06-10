%lang starknet

# @title JediSwap router for stateless execution of swaps
# @author Mesh Finance
# @license MIT
# @dev Based on the Uniswap V2 Router
#       https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_le,
    uint256_lt,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from contracts.utils.math import (
    uint256_checked_add,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_felt_checked_mul,
)

#
# Interfaces
#
@contract_interface
namespace IERC20:
    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end
end

@contract_interface
namespace IPair:
    func get_reserves() -> (reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt):
    end

    func mint(to : felt) -> (liquidity : Uint256):
    end

    func burn(to : felt) -> (amount0 : Uint256, amount1 : Uint256):
    end

    func swap(amount0Out : Uint256, amount1Out : Uint256, to : felt, data_len : felt):
    end
end

@contract_interface
namespace IFactory:
    func get_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end

    func create_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end
end

#
# Storage
#

# @dev Factory contract address
@storage_var
func _factory() -> (address : felt):
end

#
# Constructor
#

# @notice Contract constructor
# @param factory Address of factory contract
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(factory : felt):
    with_attr error_message("Router::constructor::factory can not be zero"):
        assert_not_zero(factory)
    end
    _factory.write(factory)
    return ()
end

#
# Getters
#

# @notice factory address
# @return address
@view
func factory{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _factory.read()
    return (address)
end

# @notice Sort tokens `tokenA` and `tokenB` by address
# @param tokenA Address of tokenA
# @param tokenB Address of tokenB
# @return token0 First token
# @return token1 Second token
@view
func sort_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt, tokenB : felt
) -> (token0 : felt, token1 : felt):
    return _sort_tokens(tokenA, tokenB)
end

# @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
# @param amountA Amount of tokenA
# @param reserveA Reserves for tokenA
# @param reserveB Reserves for tokenB
# @return amountB Amount of tokenB
@view
func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountA : Uint256, reserveA : Uint256, reserveB : Uint256
) -> (amountB : Uint256):
    return _quote(amountA, reserveA, reserveB)
end

# @notice Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
# @param amountIn Input Amount
# @param reserveIn Reserves for input token
# @param reserveOut Reserves for output token
# @return amountOut Maximum output amount
@view
func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountOut : Uint256):
    return _get_amount_out(amountIn, reserveIn, reserveOut)
end

# @notice Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
# @param amountOut Output Amount
# @param reserveIn Reserves for input token
# @param reserveOut Reserves for output token
# @return amountIn Required input amount
@view
func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountIn : Uint256):
    return _get_amount_in(amountOut, reserveIn, reserveOut)
end

# @notice Performs chained get_amount_out calculations on any number of pairs
# @param amountIn Input Amount
# @param path_len Length of path array
# @param path Array of pair addresses through which swaps are chained
# @return amounts_len Required output amount array's length
# @return amounts Required output amount array
@view
func get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, path_len : felt, path : felt*
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = _get_amounts_out(factory, amountIn, path_len, path)
    return (path_len, amounts)
end

# @notice Performs chained get_amount_in calculations on any number of pairs
# @param amountOut Output Amount
# @param path_len Length of path array
# @param path Array of pair addresses through which swaps are chained
# @return amounts_len Required input amount array's length
# @return amounts Required input amount array
@view
func get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, path_len : felt, path : felt*
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = _get_amounts_in(factory, amountOut, path_len, path)
    return (path_len, amounts)
end

#
# Externals
#

# @notice Add liquidity to a pool
# @dev `caller` should have already given the router an allowance of at least amountADesired/amountBDesired on tokenA/tokenB
# @param tokenA Address of tokenA
# @param tokenB Address of tokenB
# @param amountADesired The amount of tokenA to add as liquidity
# @param amountBDesired The amount of tokenB to add as liquidity
# @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts. Must be <= amountADesired
# @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts. Must be <= amountBDesired
# @param to Recipient of liquidity tokens
# @param deadline Timestamp after which the transaction will revert
# @return amountA The amount of tokenA sent to the pool
# @return amountB The amount of tokenB sent to the pool
# @return liquidity The amount of liquidity tokens minted
@external
func add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    amountADesired : Uint256,
    amountBDesired : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
    to : felt,
    deadline : felt,
) -> (amountA : Uint256, amountB : Uint256, liquidity : Uint256):
    alloc_locals
    _ensure_deadline(deadline)
    let (local factory) = _factory.read()
    let (local amountA : Uint256, local amountB : Uint256) = _add_liquidity(
        tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
    )
    let (local pair) = _pair_for(factory, tokenA, tokenB)
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=tokenA, sender=sender, recipient=pair, amount=amountA)
    IERC20.transferFrom(contract_address=tokenB, sender=sender, recipient=pair, amount=amountB)
    let (local liquidity : Uint256) = IPair.mint(contract_address=pair, to=to)
    return (amountA, amountB, liquidity)
end

# @notice Remove liquidity from a pool
# @dev `caller` should have already given the router an allowance of at least liquidity on the pool
# @param tokenA Address of tokenA
# @param tokenB Address of tokenB
# @param tokenB Address of tokenB
# @param liquidity The amount of liquidity tokens to remove
# @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert
# @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert
# @param to Recipient of the underlying tokens
# @param deadline Timestamp after which the transaction will revert
# @return amountA The amount of tokenA received
# @return amountB The amount of tokenA received
@external
func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    liquidity : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
    to : felt,
    deadline : felt,
) -> (amountA : Uint256, amountB : Uint256):
    alloc_locals
    _ensure_deadline(deadline)
    let (local factory) = _factory.read()
    let (local pair) = _pair_for(factory, tokenA, tokenB)
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=pair, sender=sender, recipient=pair, amount=liquidity)
    let (local amount0 : Uint256, local amount1 : Uint256) = IPair.burn(
        contract_address=pair, to=to
    )
    let (local token0, _) = _sort_tokens(tokenA, tokenB)
    local amountA : Uint256
    local amountB : Uint256
    if tokenA == token0:
        assert amountA = amount0
        assert amountB = amount1
    else:
        assert amountA = amount1
        assert amountB = amount0
    end

    let (is_amountA_greater_than_equal_amountAMin) = uint256_le(amountAMin, amountA)
    with_attr error_message("Router::remove_liquidity::insufficient A amount"):
        assert is_amountA_greater_than_equal_amountAMin = 1
    end
    let (is_amountB_greater_than_equal_amountBMin) = uint256_le(amountBMin, amountB)
    with_attr error_message("Router::remove_liquidity::insufficient B amount"):
        assert is_amountB_greater_than_equal_amountBMin = 1
    end

    return (amountA, amountB)
end

# @notice Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path
# @dev `caller` should have already given the router an allowance of at least amountIn on the input token
# @param amountIn The amount of input tokens to send
# @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert
# @param path_len Length of path array
# @param path Array of pair addresses through which swaps are chained
# @param to Recipient of the output tokens
# @param deadline Timestamp after which the transaction will revert
# @return amounts_len Length of amounts array
# @return amounts The input token amount and all subsequent output token amounts
@external
func swap_exact_tokens_for_tokens{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    amountIn : Uint256,
    amountOutMin : Uint256,
    path_len : felt,
    path : felt*,
    to : felt,
    deadline : felt,
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    _ensure_deadline(deadline)
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = _get_amounts_out(factory, amountIn, path_len, path)
    let (is_amount_last_greater_than_equal_amountOutMin) = uint256_le(
        amountOutMin, [amounts + (path_len - 1) * Uint256.SIZE]
    )
    with_attr error_message("Router::swap_exact_tokens_for_tokens::insufficient output amount"):
        assert is_amount_last_greater_than_equal_amountOutMin = 1
    end
    let (local pair) = _pair_for(factory, [path], [path + 1])
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=[path], sender=sender, recipient=pair, amount=[amounts])
    _swap(0, path_len, amounts, path, to)
    return (path_len, amounts)
end

# @notice Receive an exact amount of output tokens for as few input tokens as possible, along the route determined by the path
# @dev `caller` should have already given the router an allowance of at least amountInMax on the input token
# @param amountOut The amount of output tokens to receive
# @param amountInMax The maximum amount of input tokens that can be required before the transaction reverts
# @param path_len Length of path array
# @param path Array of pair addresses through which swaps are chained
# @param to Recipient of the output tokens
# @param deadline Timestamp after which the transaction will revert
# @return amounts_len Length of amounts array
# @return amounts The input token amount and all subsequent output token amounts
@external
func swap_tokens_for_exact_tokens{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    amountOut : Uint256,
    amountInMax : Uint256,
    path_len : felt,
    path : felt*,
    to : felt,
    deadline : felt,
) -> (amounts_len : felt, amounts : Uint256*):
    alloc_locals
    _ensure_deadline(deadline)
    let (local factory) = _factory.read()
    let (local amounts : Uint256*) = _get_amounts_in(factory, amountOut, path_len, path)
    let (is_amount_first_less_than_equal_amountInMax) = uint256_le([amounts], amountInMax)
    with_attr error_message("Router::swap_tokens_for_exact_tokens::excessive input amount"):
        assert is_amount_first_less_than_equal_amountInMax = 1
    end
    let (local pair) = _pair_for(factory, [path], [path + 1])
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=[path], sender=sender, recipient=pair, amount=[amounts])
    _swap(0, path_len, amounts, path, to)
    return (path_len, amounts)
end

#
# Internals
#

func _ensure_deadline{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    deadline : felt
):
    let (block_timestamp) = get_block_timestamp()
    with_attr error_message("Router::_ensure_deadline::expired"):
        assert_le(block_timestamp, deadline)
    end
    return ()
end

func _add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt,
    tokenB : felt,
    amountADesired : Uint256,
    amountBDesired : Uint256,
    amountAMin : Uint256,
    amountBMin : Uint256,
) -> (amountA : Uint256, amountB : Uint256):
    alloc_locals
    let (local factory) = _factory.read()
    let (local pair) = IFactory.get_pair(contract_address=factory, token0=tokenA, token1=tokenB)

    if pair == 0:
        let (new_pair) = IFactory.create_pair(
            contract_address=factory, token0=tokenA, token1=tokenB
        )
    end

    let (local reserveA : Uint256, local reserveB : Uint256) = _get_reserves(
        factory, tokenA, tokenB
    )
    let (reserveA_mul_reserveB : Uint256) = uint256_checked_mul(reserveA, reserveB)
    let (is_reserveA_mul_reserveB_equal_to_zero) = uint256_eq(reserveA_mul_reserveB, Uint256(0, 0))

    if is_reserveA_mul_reserveB_equal_to_zero == 1:
        return (amountADesired, amountBDesired)
    else:
        let (local amountBOptimal : Uint256) = _quote(amountADesired, reserveA, reserveB)
        let (is_amountBOptimal_less_than_equal_amountBDesired) = uint256_le(
            amountBOptimal, amountBDesired
        )
        if is_amountBOptimal_less_than_equal_amountBDesired == 1:
            let (is_amountBOptimal_greater_than_equal_amountBMin) = uint256_le(
                amountBMin, amountBOptimal
            )
            with_attr error_message("Router::_add_liquidity::insufficient B amount"):
                assert is_amountBOptimal_greater_than_equal_amountBMin = 1
            end
            return (amountADesired, amountBOptimal)
        else:
            let (local amountAOptimal : Uint256) = _quote(amountBDesired, reserveB, reserveA)
            let (is_amountAOptimal_less_than_equal_amountADesired) = uint256_le(
                amountAOptimal, amountADesired
            )
            assert is_amountAOptimal_less_than_equal_amountADesired = 1
            let (is_amountAOptimal_greater_than_equal_amountAMin) = uint256_le(
                amountAMin, amountAOptimal
            )
            with_attr error_message("Router::_add_liquidity::insufficient A amount"):
                assert is_amountAOptimal_greater_than_equal_amountAMin = 1
            end
            return (amountAOptimal, amountBDesired)
        end
    end
end

func _swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_index : felt, amounts_len : felt, amounts : Uint256*, path : felt*, _to : felt
):
    alloc_locals
    let (local factory) = _factory.read()
    if current_index == amounts_len - 1:
        return ()
    end
    let (local token0, _) = _sort_tokens([path], [path + 1])
    local amount0Out : Uint256
    local amount1Out : Uint256
    if [path] == token0:
        assert amount0Out = Uint256(0, 0)
        assert amount1Out = [amounts + Uint256.SIZE]
    else:
        assert amount0Out = [amounts + Uint256.SIZE]
        assert amount1Out = Uint256(0, 0)
    end
    local to
    let (is_current_index_less_than_len_2) = is_le(current_index, amounts_len - 3)
    if is_current_index_less_than_len_2 == 1:
        let (local pair) = _pair_for(factory, [path + 1], [path + 2])
        assert to = pair
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert to = _to
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    let (local pair) = _pair_for(factory, [path], [path + 1])
    IPair.swap(
        contract_address=pair, amount0Out=amount0Out, amount1Out=amount1Out, to=to, data_len=0
    )
    return _swap(current_index + 1, amounts_len, amounts + Uint256.SIZE, path + 1, _to)
end

func _sort_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenA : felt, tokenB : felt
) -> (token0 : felt, token1 : felt):
    alloc_locals
    local token0
    local token1
    assert_not_equal(tokenA, tokenB)
    let (is_tokenA_less_than_tokenB) = is_le_felt(tokenA, tokenB)
    if is_tokenA_less_than_tokenB == 1:
        assert token0 = tokenA
        assert token1 = tokenB
    else:
        assert token0 = tokenB
        assert token1 = tokenA
    end

    assert_not_zero(token0)
    return (token0, token1)
end

func _pair_for{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, tokenA : felt, tokenB : felt
) -> (pair : felt):
    alloc_locals
    let (local token0, local token1) = _sort_tokens(tokenA, tokenB)
    let (local pair) = IFactory.get_pair(contract_address=factory, token0=token0, token1=token1)
    return (pair)
end

func _get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, tokenA : felt, tokenB : felt
) -> (reserveA : Uint256, reserveB : Uint256):
    alloc_locals
    let (local token0, _) = _sort_tokens(tokenA, tokenB)
    let (local pair) = _pair_for(factory, tokenA, tokenB)
    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = IPair.get_reserves(
        contract_address=pair
    )
    if tokenA == token0:
        return (reserve0, reserve1)
    else:
        return (reserve1, reserve0)
    end
end

#
# Internals LIBRARY
#

func _quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountA : Uint256, reserveA : Uint256, reserveB : Uint256
) -> (amountB : Uint256):
    alloc_locals
    let (is_amountA_greater_than_zero) = uint256_lt(Uint256(0, 0), amountA)
    with_attr error_message("Router::_quote::insufficient amount"):
        assert is_amountA_greater_than_zero = 1
    end
    let (is_reserveA_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveA)
    let (is_reserveB_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveB)
    with_attr error_message("Router::_quote::insufficient liquidity"):
        assert is_reserveA_greater_than_zero = 1
        assert is_reserveB_greater_than_zero = 1
    end

    let (amountA_mul_reserveB : Uint256) = uint256_checked_mul(amountA, reserveB)
    let (amountB : Uint256, _) = uint256_unsigned_div_rem(amountA_mul_reserveB, reserveA)
    return (amountB)
end

func _get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountIn : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountOut : Uint256):
    alloc_locals
    let (is_amountIn_greater_than_zero) = uint256_lt(Uint256(0, 0), amountIn)
    with_attr error_message("Router::_get_amount_out::insufficient input amount"):
        assert is_amountIn_greater_than_zero = 1
    end
    let (is_reserveIn_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveIn)
    let (is_reserveOut_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveOut)
    with_attr error_message("Router::_get_amount_out::insufficient liquidity"):
        assert is_reserveIn_greater_than_zero = 1
        assert is_reserveOut_greater_than_zero = 1
    end

    let (amountIn_with_fee : Uint256) = uint256_felt_checked_mul(amountIn, 997)
    let (numerator : Uint256) = uint256_checked_mul(amountIn_with_fee, reserveOut)
    let (reserveIn_mul_1000 : Uint256) = uint256_felt_checked_mul(reserveIn, 1000)
    let (local denominator : Uint256) = uint256_checked_add(reserveIn_mul_1000, amountIn_with_fee)

    let (amountOut : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
    return (amountOut)
end

func _get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amountOut : Uint256, reserveIn : Uint256, reserveOut : Uint256
) -> (amountIn : Uint256):
    alloc_locals
    let (is_amountOut_greater_than_zero) = uint256_lt(Uint256(0, 0), amountOut)
    with_attr error_message("Router::_get_amount_in::insufficient output amount"):
        assert is_amountOut_greater_than_zero = 1
    end
    let (is_reserveIn_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveIn)
    let (is_reserveOut_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveOut)
    with_attr error_message("Router::_get_amount_in::insufficient liquidity"):
        assert is_reserveIn_greater_than_zero = 1
        assert is_reserveOut_greater_than_zero = 1
    end

    let (amountOut_mul_reserveIn : Uint256) = uint256_checked_mul(amountOut, reserveIn)
    let (numerator : Uint256) = uint256_felt_checked_mul(amountOut_mul_reserveIn, 1000)
    let (denominator_0 : Uint256) = uint256_checked_sub_lt(reserveOut, amountOut)
    let (denominator : Uint256) = uint256_felt_checked_mul(denominator_0, 997)

    let (amountIn_0 : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
    let (local amountIn : Uint256) = uint256_checked_add(amountIn_0, Uint256(1, 0))

    return (amountIn)
end

func _get_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, amountIn : Uint256, path_len : felt, path : felt*
) -> (amounts : Uint256*):
    alloc_locals
    with_attr error_message("Router::_get_amounts_out::invalid path"):
        assert_le(2, path_len)
    end
    let (local amounts_start : Uint256*) = alloc()
    let (amounts_end : Uint256*) = _build_amounts_out(
        factory, amountIn, 0, path_len, path, amounts_start
    )

    return (amounts_start)
end

func _build_amounts_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt,
    amountIn : Uint256,
    current_index : felt,
    path_len : felt,
    path : felt*,
    amounts : Uint256*,
) -> (amounts : Uint256*):
    alloc_locals
    if current_index == path_len:
        return (amounts)
    end

    if current_index == 0:
        assert [amounts] = amountIn
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (local reserveIn : Uint256, local reserveOut : Uint256) = _get_reserves(
            factory, [path - 1], [path]
        )
        let (local amountOut : Uint256) = _get_amount_out(
            [amounts - Uint256.SIZE], reserveIn, reserveOut
        )
        assert [amounts] = amountOut
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return _build_amounts_out(
        factory, amountIn, current_index + 1, path_len, path + 1, amounts + Uint256.SIZE
    )
end

func _get_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt, amountOut : Uint256, path_len : felt, path : felt*
) -> (amounts : Uint256*):
    alloc_locals
    with_attr error_message("Router::_get_amounts_in::invalid path"):
        assert_le(2, path_len)
    end
    let (local amounts_start : Uint256*) = alloc()
    let (amounts_start_temp : Uint256*) = _build_amounts_in(
        factory,
        amountOut,
        path_len - 1,
        path_len,
        path + (path_len - 1),
        amounts_start + (path_len - 1) * Uint256.SIZE,
    )

    return (amounts_start)
end

func _build_amounts_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    factory : felt,
    amountOut : Uint256,
    current_index : felt,
    path_len : felt,
    path : felt*,
    amounts : Uint256*,
) -> (amounts : Uint256*):
    alloc_locals

    if current_index == path_len - 1:
        assert [amounts] = amountOut
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (local reserveIn : Uint256, local reserveOut : Uint256) = _get_reserves(
            factory, [path], [path + 1]
        )
        let (local amountIn : Uint256) = _get_amount_in(
            [amounts + Uint256.SIZE], reserveIn, reserveOut
        )
        assert [amounts] = amountIn
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if current_index == 0:
        return (amounts)
    end

    return _build_amounts_in(
        factory, amountOut, current_index - 1, path_len, path - 1, amounts - Uint256.SIZE
    )
end
