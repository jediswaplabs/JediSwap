%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_le, assert_not_zero
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (Uint256, uint256_eq, uint256_le, uint256_mul)
from starkware.cairo.common.alloc import alloc

from libraries.Library import _pair_for, _get_reserves, _quote, _sort_tokens, _get_amount_out, _get_amounts_out, _get_amount_in, _get_amounts_in
from interfaces.IERC20 import IERC20
from interfaces.IPair import IPair
from interfaces.IRegistry import IRegistry

#
# Storage
#

@storage_var
func _registry() -> (address: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        registry: felt
    ):
    assert_not_zero(registry)
    _registry.write(registry)
    return ()
end

#
# Getters
#

@view
func registry{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _registry.read()
    return (address)
end

@view
func quote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountA: Uint256, reserveA: Uint256, reserveB: Uint256) -> (amountB: Uint256):
    return _quote(amountA, reserveA, reserveB)
end

@view
func get_amount_out{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountIn: Uint256, reserveIn: Uint256, reserveOut: Uint256) -> (amountOut: Uint256):
    return _get_amount_out(amountIn, reserveIn, reserveOut)
end

@view
func get_amount_in{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountOut: Uint256, reserveIn: Uint256, reserveOut: Uint256) -> (amountIn: Uint256):
    return _get_amount_in(amountOut, reserveIn, reserveOut)
end

@view
func get_amounts_out{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountIn: Uint256, path_len: felt, path: felt*) -> (amounts_len: felt, amounts: felt*):
    alloc_locals
    let (local registry) = _registry.read()
    let (local amounts: Uint256*) = _get_amounts_out(registry, amountIn, path_len, path)
    let (local amounts_in_felt: felt*) = alloc()
    let (amounts_in_felt_end: felt*) = _convert_uint256_array_to_felt_array(0, path_len, amounts, amounts_in_felt)
    return (path_len, amounts_in_felt)
end

@view
func get_amounts_in{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountOut: Uint256, path_len: felt, path: felt*) -> (amounts_len: felt, amounts: felt*):
    alloc_locals
    let (local registry) = _registry.read()
    let (local amounts: Uint256*) = _get_amounts_in(registry, amountOut, path_len, path)
    let (local amounts_in_felt: felt*) = alloc()
    let (amounts_in_felt_end: felt*) = _convert_uint256_array_to_felt_array(0, path_len, amounts, amounts_in_felt)
    return (path_len, amounts_in_felt)
end

#
# Externals
#

@external
func add_liquidity{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(tokenA: felt, tokenB: felt, amountADesired: Uint256, amountBDesired: Uint256,
    amountAMin: Uint256, amountBMin: Uint256, to: felt, deadline: felt) -> (amountA: Uint256, amountB: Uint256, liquidity: Uint256):
    alloc_locals
    _ensure_deadline(deadline)
    let (local registry) = _registry.read()
    let (local amountA: Uint256, local amountB: Uint256) = _add_liquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin)
    let (local pair) = _pair_for(registry, tokenA, tokenB)
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=tokenA, sender=sender, recipient=pair, amount=amountA)
    IERC20.transferFrom(contract_address=tokenB, sender=sender, recipient=pair, amount=amountB)
    let (local liquidity: Uint256) = IPair.mint(contract_address=pair, to=to)
    return (amountA, amountB, liquidity)
end

@external
func remove_liquidity{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(tokenA: felt, tokenB: felt, liquidity: Uint256, amountAMin: Uint256, amountBMin: Uint256, 
    to: felt, deadline: felt) -> (amountA: Uint256, amountB: Uint256):
    alloc_locals
    _ensure_deadline(deadline)
    let (local registry) = _registry.read()
    let (local pair) = _pair_for(registry, tokenA, tokenB)
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=pair, sender=sender, recipient=pair, amount=liquidity)
    let (local amount0: Uint256, local amount1: Uint256) = IPair.burn(contract_address=pair, to=to)
    let (local token0, _) = _sort_tokens(tokenA, tokenB)
    local amountA: Uint256
    local amountB: Uint256
    if tokenA == token0:
        assert amountA = amount0
        assert amountB = amount1
    else:
        assert amountA = amount1
        assert amountB = amount0
    end
    
    let (is_amountA_greater_than_equal_amountAMin) = uint256_le(amountAMin, amountA)
    assert is_amountA_greater_than_equal_amountAMin = 1
    let (is_amountB_greater_than_equal_amountBMin) = uint256_le(amountBMin, amountB)
    assert is_amountB_greater_than_equal_amountBMin = 1
    
    return (amountA, amountB)
end

@external
func swap_exact_tokens_for_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountIn: Uint256, amountOutMin: Uint256, path_len: felt, path: felt*, 
    to: felt, deadline: felt) -> (amounts_len: felt, amounts: felt*):
    alloc_locals
    _ensure_deadline(deadline)
    let (local registry) = _registry.read()
    let (local amounts: Uint256*) = _get_amounts_out(registry, amountIn, path_len, path)
    let (is_amount_last_greater_than_equal_amountOutMin) = uint256_le(amountOutMin, [amounts + path_len * Uint256.SIZE])
    assert is_amount_last_greater_than_equal_amountOutMin = 1
    let (local pair) = _pair_for(registry, [path], [path + 1])
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=[path], sender=sender, recipient=pair, amount=[amounts])
    _swap(0, path_len, amounts, path, to)
    let (local amounts_in_felt: felt*) = alloc()
    let (amounts_in_felt_end: felt*) = _convert_uint256_array_to_felt_array(0, path_len, amounts, amounts_in_felt)
    return (path_len, amounts_in_felt)
end

@external
func swap_tokens_for_exact_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountOut: Uint256, amountInMax: Uint256, path_len: felt, path: felt*, 
    to: felt, deadline: felt) -> (amounts_len: felt, amounts: felt*):
    alloc_locals
    _ensure_deadline(deadline)
    let (local registry) = _registry.read()
    let (local amounts: Uint256*) = _get_amounts_in(registry, amountOut, path_len, path)
    let (is_amount_first_less_than_equal_amountInMax) = uint256_le([amounts], amountInMax)
    assert is_amount_first_less_than_equal_amountInMax = 1
    let (local pair) = _pair_for(registry, [path], [path + 1])
    let (sender) = get_caller_address()
    IERC20.transferFrom(contract_address=[path], sender=sender, recipient=pair, amount=[amounts])
    _swap(0, path_len, amounts, path, to)
    let (local amounts_in_felt: felt*) = alloc()
    let (amounts_in_felt_end: felt*) = _convert_uint256_array_to_felt_array(0, path_len, amounts, amounts_in_felt)
    return (path_len, amounts_in_felt)
end

#
# Internals
#

func _ensure_deadline{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(deadline: felt):
    # assert_le(timestamp, deadline) ## TODO, when timestamp is available, change this.
    return ()
end

func _add_liquidity{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(tokenA: felt, tokenB: felt, amountADesired: Uint256, amountBDesired: Uint256, 
    amountAMin: Uint256, amountBMin: Uint256) -> (amountA: Uint256, amountB: Uint256):
    alloc_locals
    let (local registry) = _registry.read()
    let (local pair) = IRegistry.get_pair_for(contract_address=registry, token0=tokenA, token1=tokenB)
    assert_not_zero(pair)  ## This will be changed when factory pattern is allowed and we can create pair on the fly
    let (local reserveA: Uint256, local reserveB: Uint256) = _get_reserves(registry, tokenA, tokenB)
    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(reserveA, reserveB)
    let (is_mul_high_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_mul_high_equal_to_zero = 1
    let (is_mul_low_equal_to_zero) =  uint256_eq(mul_low, Uint256(0, 0))

    if is_mul_low_equal_to_zero == 1:
        return (amountADesired, amountBDesired)
    else:
        let (local amountBOptimal: Uint256) = _quote(amountADesired, reserveA, reserveB)
        let (is_amountBOptimal_less_than_equal_amountBDesired) = uint256_le(amountBOptimal, amountBDesired)
        if is_amountBOptimal_less_than_equal_amountBDesired == 1:
            let (is_amountBOptimal_greater_than_equal_amountBMin) = uint256_le(amountBMin, amountBOptimal)
            assert is_amountBOptimal_greater_than_equal_amountBMin = 1
            return (amountADesired, amountBOptimal)
        else:
            let (local amountAOptimal: Uint256) = _quote(amountBDesired, reserveB, reserveA)
            let (is_amountAOptimal_less_than_equal_amountADesired) = uint256_le(amountAOptimal, amountADesired)
            assert is_amountAOptimal_less_than_equal_amountADesired = 1
            let (is_amountAOptimal_greater_than_equal_amountAMin) = uint256_le(amountAMin, amountAOptimal)
            assert is_amountAOptimal_greater_than_equal_amountAMin = 1
            return (amountAOptimal, amountBDesired)
        end
    end
end

func _swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, amounts_len: felt, amounts: Uint256*, path: felt*, _to: felt):
    alloc_locals
    let (local registry) = _registry.read()
    if current_index == amounts_len - 1:
        return ()
    end
    let (local token0, _) = _sort_tokens([path], [path + 1])
    local amount0Out: Uint256
    local amount1Out: Uint256
    if [path] == token0:
        assert amount0Out = Uint256(0, 0)
        assert amount1Out = [amounts + 1]
    else:
        assert amount0Out = [amounts + 1]
        assert amount1Out = Uint256(0, 0)
    end
    local to
    let (is_current_index_less_than_len_2) = is_le(current_index, amounts_len - 3)
    if is_current_index_less_than_len_2 == 1:
        let (local pair) = _pair_for(registry, [path + 1], [path + 2])
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
    let (local pair) = _pair_for(registry, [path], [path + 1])
    IPair.swap(contract_address=pair, amount0Out=amount0Out, amount1Out=amount1Out, to=to)
    return ()
end

func _convert_uint256_array_to_felt_array{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, path_len: felt, amounts: Uint256*, amounts_in_felt: felt*) -> (amounts_in_felt: felt*):
    alloc_locals
    if current_index == path_len:
        return (amounts_in_felt)
    end
    assert [amounts_in_felt] = [amounts].low
    return _convert_uint256_array_to_felt_array(current_index + 1, path_len, amounts + Uint256.SIZE, amounts_in_felt + 1)
end
