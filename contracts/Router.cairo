%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (Uint256, uint256_eq, uint256_le, uint256_lt, 
    uint256_add, uint256_sub, uint256_mul, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc

#
# Interfaces
#
@contract_interface
namespace IERC20:

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end
end

@contract_interface
namespace IPair:
    
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256):
    end

    func mint(to: felt) -> (liquidity: Uint256):
    end

    func burn(to: felt) -> (amount0: Uint256, amount1: Uint256):
    end

    func swap(amount0Out: Uint256, amount1Out: Uint256, to: felt):
    end
end

@contract_interface
namespace IRegistry:
    func get_pair_for(token0: felt, token1: felt) -> (pair: felt):
    end
end

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
func sort_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(tokenA: felt, tokenB: felt) -> (token0: felt, token1: felt):
    return _sort_tokens(tokenA, tokenB)
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
    let (is_amount_last_greater_than_equal_amountOutMin) = uint256_le(amountOutMin, [amounts + (path_len - 1) * Uint256.SIZE])
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
        assert amount1Out = [amounts + Uint256.SIZE]
    else:
        assert amount0Out = [amounts + Uint256.SIZE]
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
    return _swap(current_index + 1, amounts_len, amounts + Uint256.SIZE, path + 1, _to)
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

#
# Internals LIBRARY
#

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
        let (local amountOut: Uint256) = _get_amount_out([amounts - Uint256.SIZE], reserveIn, reserveOut)
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
    let (amounts_start_temp: Uint256*) = _build_amounts_in(registry, amountOut, path_len - 1, path_len, path + (path_len - 1), amounts_start + (path_len - 1) * Uint256.SIZE)
    
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
        let (local amountIn: Uint256) = _get_amount_in([amounts + Uint256.SIZE], reserveIn, reserveOut)
        assert [amounts] = amountIn
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    if current_index == 0:
        return (amounts)
    end
    
    return _build_amounts_in(registry, amountOut, current_index - 1, path_len, path - 1, amounts - Uint256.SIZE)
end
