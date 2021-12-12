%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal, assert_not_zero, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (Uint256, uint256_eq, uint256_lt, uint256_mul, uint256_add, uint256_sub, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc

from interfaces.IRegistry import IRegistry
from interfaces.IPair import IPair


func _sort_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(tokenA: felt, tokenB: felt) -> (token0: felt, token1: felt):
    alloc_locals
    local token0
    local token1
    assert_not_equal(tokenA, tokenB)
    let (is_tokenA_less_than_tokenB) = is_le(tokenA, tokenB)
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

func _pair_for{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, tokenA: felt, tokenB: felt) -> (pair: felt):
    alloc_locals
    let (local token0, local token1) = _sort_tokens(tokenA, tokenB)
    let (local pair) = IRegistry.get_pair_for(contract_address=registry, token0=token0, token1=token1)
    return (pair)
end

func _get_reserves{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, tokenA: felt, tokenB: felt) -> (reserveA: Uint256, reserveB: Uint256):
    alloc_locals
    let (local token0, _) = _sort_tokens(tokenA, tokenB)
    let (local pair) = _pair_for(registry, tokenA, tokenB)
    let (local reserve0: Uint256, local reserve1: Uint256) = IPair.get_reserves(contract_address=pair)
    if tokenA == token0:
        return (reserve0, reserve1)
    else:
        return (reserve1, reserve0)
    end
end

func _quote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountA: Uint256, reserveA: Uint256, reserveB: Uint256) -> (amountB: Uint256):
    alloc_locals
    let (is_amountA_greater_than_zero) = uint256_lt(Uint256(0, 0), amountA)
    assert is_amountA_greater_than_zero = 1
    let (is_reserveA_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveA)
    assert is_reserveA_greater_than_zero = 1
    let (is_reserveB_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveB)
    assert is_reserveB_greater_than_zero = 1

    let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amountA, reserveB)
    let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
    assert is_equal_to_zero = 1
    let (amountB: Uint256, _) = uint256_unsigned_div_rem(mul_low, reserveA)
    return (amountB)
end

func _get_amount_out{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountIn: Uint256, reserveIn: Uint256, reserveOut: Uint256) -> (amountOut: Uint256):
    alloc_locals
    let (is_amountIn_greater_than_zero) = uint256_lt(Uint256(0, 0), amountIn)
    assert is_amountIn_greater_than_zero = 1
    let (is_reserveIn_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveIn)
    assert is_reserveIn_greater_than_zero = 1
    let (is_reserveOut_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveOut)
    assert is_reserveOut_greater_than_zero = 1

    let (mul_low_amountIn_fee: Uint256, mul_high_amountIn_fee: Uint256) = uint256_mul(amountIn, Uint256(997, 0))
    let (is_equal_to_zero_amountIn_fee) =  uint256_eq(mul_high_amountIn_fee, Uint256(0, 0))
    assert is_equal_to_zero_amountIn_fee = 1
    let (mul_low_numerator: Uint256, mul_high_numerator: Uint256) = uint256_mul(mul_low_amountIn_fee, reserveOut)
    let (is_equal_to_zero_numerator) =  uint256_eq(mul_high_numerator, Uint256(0, 0))
    assert is_equal_to_zero_numerator = 1

    let (mul_low_denominator_0: Uint256, mul_high_denominator_0: Uint256) = uint256_mul(reserveIn, Uint256(1000, 0))
    let (is_equal_to_zero_denominator_0) =  uint256_eq(mul_high_denominator_0, Uint256(0, 0))
    assert is_equal_to_zero_denominator_0 = 1
    let (local denominator: Uint256, is_overflow) = uint256_add(mul_low_denominator_0, mul_low_amountIn_fee)
    assert (is_overflow) = 0
    
    let (amountIn: Uint256, _) = uint256_unsigned_div_rem(mul_low_numerator, denominator)
    return (amountIn)
end

func _get_amount_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amountOut: Uint256, reserveIn: Uint256, reserveOut: Uint256) -> (amountIn: Uint256):
    alloc_locals
    let (is_amountOut_greater_than_zero) = uint256_lt(Uint256(0, 0), amountOut)
    assert is_amountOut_greater_than_zero = 1
    let (is_reserveIn_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveIn)
    assert is_reserveIn_greater_than_zero = 1
    let (is_reserveOut_greater_than_zero) = uint256_lt(Uint256(0, 0), reserveOut)
    assert is_reserveOut_greater_than_zero = 1

    let (mul_low_numerator_0: Uint256, mul_high_numerator_0: Uint256) = uint256_mul(amountOut, reserveIn)
    let (is_equal_to_zero_numerator_0) =  uint256_eq(mul_high_numerator_0, Uint256(0, 0))
    assert is_equal_to_zero_numerator_0 = 1
    let (mul_low_numerator: Uint256, mul_high_numerator: Uint256) = uint256_mul(mul_low_numerator_0, Uint256(1000, 0))
    let (is_equal_to_zero_numerator) =  uint256_eq(mul_high_numerator, Uint256(0, 0))
    assert is_equal_to_zero_numerator = 1

    let (denominator_0: Uint256) = uint256_sub(reserveOut, amountOut)
    let (mul_low_denominator: Uint256, mul_high_denominator: Uint256) = uint256_mul(denominator_0, Uint256(997, 0))
    let (is_equal_to_zero_denominator) =  uint256_eq(mul_high_denominator, Uint256(0, 0))
    assert is_equal_to_zero_denominator = 1
    
    let (amountIn_0: Uint256, _) = uint256_unsigned_div_rem(mul_low_numerator, mul_low_denominator)
    let (local amountIn: Uint256, is_overflow) = uint256_add(amountIn_0, Uint256(1, 0))
    assert (is_overflow) = 0
    
    return (amountIn)
end

func _get_amounts_out{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, amountIn: Uint256, path_len: felt, path: felt*) -> (amounts: Uint256*):
    alloc_locals
    assert_le(2, path_len)
    let (local amounts_start : Uint256*) = alloc()
    let (amounts_end: Uint256*) = _build_amounts_out(registry, amountIn, 0, path_len, path, amounts_start)
    
    return (amounts_start)
end

func _build_amounts_out{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, amountIn: Uint256, current_index: felt, path_len: felt, path: felt*, amounts: Uint256*) -> (amounts: Uint256*):
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
        let (local reserveIn: Uint256, local reserveOut: Uint256) = _get_reserves(registry, [path - 1], [path])
        let (local amountOut: Uint256) = _get_amount_out([amounts - 1], reserveIn, reserveOut)
        assert [amounts] = amountOut
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    return _build_amounts_out(registry, amountIn, current_index + 1, path_len, path + 1, amounts + Uint256.SIZE)
end

func _get_amounts_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, amountOut: Uint256, path_len: felt, path: felt*) -> (amounts: Uint256*):
    alloc_locals
    assert_le(2, path_len)
    let (local amounts_start : Uint256*) = alloc()
    let (amounts_start_temp: Uint256*) = _build_amounts_in(registry, amountOut, path_len - 1, path_len, path + path_len, amounts_start + path_len * Uint256.SIZE)
    
    return (amounts_start)
end

func _build_amounts_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(registry: felt, amountOut: Uint256, current_index: felt, path_len: felt, path: felt*, amounts: Uint256*) -> (amounts: Uint256*):
    alloc_locals

    if current_index == path_len - 1:
        assert [amounts] = amountOut
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (local reserveIn: Uint256, local reserveOut: Uint256) = _get_reserves(registry, [path], [path + 1])
        let (local amountIn: Uint256) = _get_amount_in([amounts + 1], reserveIn, reserveOut)
        assert [amounts] = amountIn
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    if current_index == 0:
        return (amounts)
    end
    
    return _build_amounts_out(registry, amountOut, current_index - 1, path_len, path - 1, amounts - Uint256.SIZE)
end
