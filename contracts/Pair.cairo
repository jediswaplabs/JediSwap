%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address, get_block_timestamp
from starkware.cairo.common.math import assert_not_zero, assert_in_range, assert_le, assert_not_equal
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_sqrt, uint256_mul, uint256_unsigned_div_rem
)
from starkware.cairo.common.alloc import alloc

const MINIMUM_LIQUIDITY = 1000
const BURN_ADDRESS = 1


#
# Interfaces
#
@contract_interface
namespace IERC20:
    
    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end
end

@contract_interface
namespace IRegistry:
    func fee_to() -> (address: felt):
    end
end

#
# Storage ERC20
#

@storage_var
func _name() -> (res: felt):
end

@storage_var
func _symbol() -> (res: felt):
end

@storage_var
func _decimals() -> (res: felt):
end

@storage_var
func total_supply() -> (res: Uint256):
end

@storage_var
func balances(account: felt) -> (res: Uint256):
end

@storage_var
func allowances(owner: felt, spender: felt) -> (res: Uint256):
end

#
# Storage Pair
#

@storage_var
func _token0() -> (address: felt):
end

@storage_var
func _token1() -> (address: felt):
end

@storage_var
func _reserve0() -> (res: Uint256):
end

@storage_var
func _reserve1() -> (res: Uint256):
end

@storage_var
func _reserve0_last() -> (res: Uint256):
end

@storage_var
func _reserve1_last() -> (res: Uint256):
end

@storage_var
func _block_timestamp_last() -> (ts: felt):
end

@storage_var
func _price_0_cumulative_last() -> (res: Uint256):
end

@storage_var
func _price_1_cumulative_last() -> (res: Uint256):
end

@storage_var
func _klast() -> (res: Uint256):
end

@storage_var
func _locked() -> (res: felt):
end

@storage_var
func _registry() -> (address: felt):
end

# An event emitted whenever token is transferred.
@event
func Transfer(from_address: felt, to_address: felt, amount: Uint256):
end

# An event emitted whenever allowances is updated
@event
func Approval(owner: felt, spender: felt, amount: Uint256):
end

# An event emitted whenever mint() is called.
@event
func Mint(sender: felt, amount0: Uint256, amount1: Uint256):
end

# An event emitted whenever burn() is called.
@event
func Burn(sender: felt, amount0: Uint256, amount1: Uint256, to: felt):
end

# An event emitted whenever swap() is called.
@event
func Swap(sender: felt, amount0In: Uint256, amount1In: Uint256, amount0Out: Uint256, amount1Out: Uint256, to: felt):
end

# An event emitted whenever _update() is called.
@event
func Sync(reserve0: Uint256, reserve1: Uint256):
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
        name: felt,
        symbol: felt,
        token0: felt,
        token1: felt,
        registry: felt
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, fee_setter parameter is included
    assert_not_zero(name)
    _name.write(name)
    assert_not_zero(symbol)
    _symbol.write(symbol)
    _decimals.write(18)
    _locked.write(0)
    assert_not_zero(token0)
    _token0.write(token0)
    assert_not_zero(token1)
    _token1.write(token1)
    assert_not_zero(registry)
    _registry.write(registry)
    return ()
end

#
# Getters ERC20
#

@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = _name.read()
    return (name)
end

@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = total_supply.read()
    return (totalSupply)
end

@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = _decimals.read()
    return (decimals)
end

@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = balances.read(account=account)
    return (balance)
end

@view
func allowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end

#
# Getters Pair
#

@view
func token0{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _token0.read()
    return (address)
end

@view
func token1{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _token1.read()
    return (address)
end

@view
func get_reserves{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt):
    return _get_reserves()
end

@view
func reserve0_last{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res) = _reserve0_last.read()
    return (res)
end

@view
func reserve1_last{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res) = _reserve1_last.read()
    return (res)
end

@view
func price_0_cumulative_last{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res) = _price_0_cumulative_last.read()
    return (res)
end

@view
func price_1_cumulative_last{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res) = _price_1_cumulative_last.read()
    return (res)
end

@view
func klast{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: Uint256):
    let (res) = _klast.read()
    return (res)
end

#
# Externals ERC20
#

@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func transferFrom{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        sender: felt, 
        recipient: felt, 
        amount: Uint256
    ) -> (success: felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance: Uint256) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true   
    let (enough_balance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_balance)

    _transfer(sender, recipient, amount)

    # subtract allowance
    let (new_allowance: Uint256) = uint256_sub(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)
    Approval.emit(owner=sender, spender=caller, amount=new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_allowance: Uint256) = allowances.read(caller, spender)
    let (local mul_low: Uint256, local mul_high: Uint256) = uint256_mul(current_allowance, amount)
    let (either_current_allowance_or_amount_is_0) =  uint256_eq(mul_low, Uint256(0, 0))
    let (is_mul_high_0) =  uint256_eq(mul_high, Uint256(0, 0))
    assert either_current_allowance_or_amount_is_0 = 1
    assert is_mul_high_0 = 1
    _approve(caller, spender, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func increaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(added_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(caller, spender)

    # add allowance
    let (local new_allowance: Uint256, is_overflow) = uint256_add(current_allowance, added_value)
    assert (is_overflow) = 0

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func decreaseAllowance{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    alloc_locals
    uint256_check(subtracted_value)
    let (local caller) = get_caller_address()
    let (local current_allowance: Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance: Uint256) = uint256_sub(current_allowance, subtracted_value)

    # validates new_allowance < current_allowance and returns 1 if true   
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

#
# Externals Pair
#

@external
func mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to: felt) -> (liquidity: Uint256):
    alloc_locals
    _check_and_lock()
    let (local reserve0: Uint256, local reserve1: Uint256, _) = _get_reserves()
    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)
    
    let (local amount0: Uint256) = uint256_sub(balance0, reserve0)
    let (local amount1: Uint256) = uint256_sub(balance1, reserve1)

    let (fee_on) = _mint_protocol_fee(reserve0, reserve1)

    let (local _total_supply: Uint256) = total_supply.read()
    let (is_total_supply_equal_to_zero) =  uint256_eq(_total_supply, Uint256(0, 0))

    local liquidity: Uint256

    if is_total_supply_equal_to_zero == 1:
        let (mul_low: Uint256, mul_high: Uint256) = uint256_mul(amount0, amount1)
        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1

        let (mul_sqrt: Uint256) = uint256_sqrt(mul_low)

        # local mul_sqrt: Uint256
        # assert mul_sqrt = amount0

        let (initial_liquidity: Uint256) = uint256_sub(mul_sqrt, Uint256(MINIMUM_LIQUIDITY, 0))
        assert liquidity = initial_liquidity
        _mint(BURN_ADDRESS, Uint256(MINIMUM_LIQUIDITY, 0))
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (mul_low0: Uint256, mul_high0: Uint256) = uint256_mul(amount0, _total_supply)
        let (is_equal_to_zero0) =  uint256_eq(mul_high0, Uint256(0, 0))
        assert is_equal_to_zero0 = 1
        let (liquidity0: Uint256, _) = uint256_unsigned_div_rem(mul_low0, reserve0)

        let (mul_low1: Uint256, mul_high1: Uint256) = uint256_mul(amount1, _total_supply)
        let (is_equal_to_zero1) =  uint256_eq(mul_high1, Uint256(0, 0))
        assert is_equal_to_zero1 = 1
        let (liquidity1: Uint256, _) = uint256_unsigned_div_rem(mul_low1, reserve1)

        let (is_liquidity0_less_than_liquidity1) = uint256_lt(liquidity0, liquidity1)
        if is_liquidity0_less_than_liquidity1 == 1:
            assert liquidity = liquidity0
        else:
            assert liquidity = liquidity1
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    local syscall_ptr: felt* = syscall_ptr
    local pedersen_ptr: HashBuiltin* = pedersen_ptr

    let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)
    assert is_liquidity_greater_than_zero = 1

    _mint(to, liquidity)
    
    _update(balance0, balance1, reserve0, reserve1)

    if fee_on == 1:
        let (klast: Uint256, mul_high: Uint256) = uint256_mul(balance0, balance1)
        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1
        _klast.write(klast)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (caller) = get_caller_address()
    
    Mint.emit(sender=caller, amount0=amount0, amount1=amount1)
    
    _unlock()
    return (liquidity)
end

@external
func burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to: felt) -> (amount0: Uint256, amount1: Uint256):
    alloc_locals
    _check_and_lock()
    let (local reserve0: Uint256, local reserve1: Uint256, _) = _get_reserves()
    
    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)
    
    let (local liquidity: Uint256) = balances.read(self_address)

    let (fee_on) = _mint_protocol_fee(reserve0, reserve1)

    let (local _total_supply: Uint256) = total_supply.read()
    let (is_total_supply_equal_to_zero) =  uint256_eq(_total_supply, Uint256(0, 0))

    let (mul_low0: Uint256, mul_high0: Uint256) = uint256_mul(liquidity, balance0)
    let (is_equal_to_zero0) =  uint256_eq(mul_high0, Uint256(0, 0))
    assert is_equal_to_zero0 = 1
    let (local amount0: Uint256, _) = uint256_unsigned_div_rem(mul_low0, _total_supply)
    let (is_amount0_greater_than_zero) = uint256_lt(Uint256(0, 0), amount0)
    assert is_amount0_greater_than_zero = 1

    let (mul_low1: Uint256, mul_high1: Uint256) = uint256_mul(liquidity, balance1)
    let (is_equal_to_zero1) =  uint256_eq(mul_high1, Uint256(0, 0))
    assert is_equal_to_zero1 = 1
    let (local amount1: Uint256, _) = uint256_unsigned_div_rem(mul_low1, _total_supply)
    let (is_amount1_greater_than_zero) = uint256_lt(Uint256(0, 0), amount1)
    assert is_amount1_greater_than_zero = 1

    _burn(self_address, liquidity)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    let (local final_balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (local final_balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    _update(final_balance0, final_balance1, reserve0, reserve1)

    if fee_on == 1:
        let (klast: Uint256, mul_high: Uint256) = uint256_mul(final_balance0, final_balance1)
        let (is_equal_to_zero) =  uint256_eq(mul_high, Uint256(0, 0))
        assert is_equal_to_zero = 1
        _klast.write(klast)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (caller) = get_caller_address()
    
    Burn.emit(sender=caller, amount0=amount0, amount1=amount1, to=to)
    
    _unlock()
    return (amount0, amount1)
end

@external
func swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(amount0Out: Uint256, amount1Out: Uint256, to: felt):
    alloc_locals
    _check_and_lock()
    local sufficient_output_amount
    let (local is_amount0out_greater_than_zero) = uint256_lt(Uint256(0, 0), amount0Out)
    let (local is_amount1out_greater_than_zero) = uint256_lt(Uint256(0, 0), amount1Out)
    if is_amount0out_greater_than_zero == 1:
        assert sufficient_output_amount = 1
    else:
        if is_amount1out_greater_than_zero == 1:
            assert sufficient_output_amount = 1
        else:
            assert sufficient_output_amount = 0
        end
    end
    assert sufficient_output_amount = 1
    
    let (local reserve0: Uint256, local reserve1: Uint256, _) = _get_reserves()
    let (is_amount0out_lesser_than_reserve0) = uint256_lt(amount0Out, reserve0)
    assert is_amount0out_lesser_than_reserve0 = 1
    let (is_amount1out_lesser_than_reserve0) = uint256_lt(amount1Out, reserve1)
    assert is_amount1out_lesser_than_reserve0 = 1

    let (local token0) = _token0.read()
    assert_not_equal(token0, 0)
    
    let (local token1) = _token1.read()
    assert_not_equal(token1, 0)

    let (self_address) = get_contract_address()

    if is_amount0out_greater_than_zero == 1:
        IERC20.transfer(contract_address=token0, recipient=to, amount=amount0Out)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    if is_amount1out_greater_than_zero == 1:
        IERC20.transfer(contract_address=token1, recipient=to, amount=amount1Out)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    local syscall_ptr: felt* = syscall_ptr
    local pedersen_ptr: HashBuiltin* = pedersen_ptr

    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local expected_balance0: Uint256) = uint256_sub(reserve0, amount0Out)
    let (local expected_balance1: Uint256) = uint256_sub(reserve1, amount1Out)
    
    local sufficient_input_amount
    let (local is_balance0_greater_than_expected_balance0) = uint256_lt(expected_balance0, balance0)
    let (local is_balance1_greater_than_expected_balance1) = uint256_lt(expected_balance1, balance1)
    if is_balance0_greater_than_expected_balance0 == 1:
        assert sufficient_input_amount = 1
    else:
        if is_balance1_greater_than_expected_balance1 == 1:
            assert sufficient_input_amount = 1
        else:
            assert sufficient_input_amount = 0
        end
    end
    assert sufficient_input_amount = 1

    let (local amount0In: Uint256) = uint256_sub(balance0, expected_balance0)
    let (local amount1In: Uint256) = uint256_sub(balance1, expected_balance1)

    let (mul_low00: Uint256, mul_high00: Uint256) = uint256_mul(balance0, Uint256(1000, 0))
    let (is_equal_to_zero00) =  uint256_eq(mul_high00, Uint256(0, 0))
    assert is_equal_to_zero00 = 1
    let (mul_low01: Uint256, mul_high01: Uint256) = uint256_mul(amount0In, Uint256(3, 0))
    let (is_equal_to_zero01) =  uint256_eq(mul_high01, Uint256(0, 0))
    assert is_equal_to_zero01 = 1
    let (local balance0Adjusted: Uint256) = uint256_sub(mul_low00, mul_low01)

    let (mul_low10: Uint256, mul_high10: Uint256) = uint256_mul(balance1, Uint256(1000, 0))
    let (is_equal_to_zero10) =  uint256_eq(mul_high10, Uint256(0, 0))
    assert is_equal_to_zero10 = 1
    let (mul_low11: Uint256, mul_high11: Uint256) = uint256_mul(amount1In, Uint256(3, 0))
    let (is_equal_to_zero11) =  uint256_eq(mul_high11, Uint256(0, 0))
    assert is_equal_to_zero11 = 1
    let (local balance1Adjusted: Uint256) = uint256_sub(mul_low10, mul_low11)

    let (balance_mul_low: Uint256, balance_mul_high: Uint256) = uint256_mul(balance0Adjusted, balance1Adjusted)
    let (is_balance_mul_high_equal_to_zero) =  uint256_eq(balance_mul_high, Uint256(0, 0))
    assert is_balance_mul_high_equal_to_zero = 1

    let (reserve_mul_low: Uint256, reserve_mul_high: Uint256) = uint256_mul(reserve0, reserve1)
    let (is_reserve_mul_high_equal_to_zero) =  uint256_eq(reserve_mul_high, Uint256(0, 0))
    assert is_reserve_mul_high_equal_to_zero = 1

    let (local multiplier) = pow(1000, 2)
    let (final_reserve_mul_low: Uint256, final_reserve_mul_high: Uint256) = uint256_mul(reserve_mul_low, Uint256(multiplier, 0))
    let (is_final_reserve_mul_high_equal_to_zero) =  uint256_eq(final_reserve_mul_high, Uint256(0, 0))
    assert is_final_reserve_mul_high_equal_to_zero = 1

    let (is_balance_adjusted_mul_greater_than_equal_final_reserve_mul) = uint256_le(final_reserve_mul_low, balance_mul_low)
    assert is_balance_adjusted_mul_greater_than_equal_final_reserve_mul = 1

    _update(balance0, balance1, reserve0, reserve1)

    let (caller) = get_caller_address()
    
    Swap.emit(sender=caller, amount0In=amount0In, amount1In=amount1In, amount0Out=amount0Out, amount1Out=amount1Out, to=to)
    
    _unlock()
    
    return ()
end

@external
func skim{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to: felt):
    alloc_locals
    _check_and_lock()
    let (local reserve0: Uint256, local reserve1: Uint256, _) = _get_reserves()
    
    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local amount0: Uint256) = uint256_sub(balance0, reserve0)
    let (local amount1: Uint256) = uint256_sub(balance1, reserve1)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    _unlock()

    return ()
end

@external
func sync{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    _check_and_lock()
    
    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local reserve0: Uint256) = _reserve0.read()
    let (local reserve1: Uint256) = _reserve1.read()

    _update(balance0, balance1, reserve0, reserve1)

    _unlock()

    return ()
end

#
# Internals ERC20
#

func _mint{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(recipient)
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance, _: Uint256) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply: Uint256) = total_supply.read()
    let (local new_supply: Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    total_supply.write(new_supply)
    return ()
end

func _transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, recipient: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)
    uint256_check(amount) # almost surely not needed, might remove after confirmation

    let (local sender_balance: Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    # subtract from sender
    let (new_sender_balance: Uint256) = uint256_sub(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance: Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance, _: Uint256) = uint256_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)

    Transfer.emit(from_address=sender, to_address=recipient, amount=amount)
    return ()
end

func _approve{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(caller: felt, spender: felt, amount: Uint256):
    assert_not_zero(caller)
    assert_not_zero(spender)
    uint256_check(amount)
    allowances.write(caller, spender, amount)
    Approval.emit(owner=caller, spender=spender, amount=amount)
    return ()
end

func _burn{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt, amount: Uint256):
    alloc_locals
    assert_not_zero(account)
    uint256_check(amount)

    let (balance: Uint256) = balances.read(account)
    # validates amount <= balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance)
    assert_not_zero(enough_balance)
    
    let (new_balance: Uint256) = uint256_sub(balance, amount)
    balances.write(account, new_balance)

    let (supply: Uint256) = total_supply.read()
    let (new_supply: Uint256) = uint256_sub(supply, amount)
    total_supply.write(new_supply)
    return ()
end

#
# Internals Pair
#

func _check_and_lock{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (locked) = _locked.read()
    assert locked = 0
    _locked.write(1)
    return ()
end

func _unlock{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (locked) = _locked.read()
    assert locked = 1
    _locked.write(0)
    return ()
end

func _mint_protocol_fee{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(reserve0: Uint256, reserve1: Uint256) -> (fee_on: felt):
    alloc_locals
    let (local registry) = _registry.read()
    let (local fee_to) = IRegistry.fee_to(contract_address=registry)
    let (local fee_on) =  is_not_zero(fee_to)
    
    let (local klast: Uint256) = _klast.read()
    let (local is_klast_equal_to_zero) =  uint256_eq(klast, Uint256(0, 0))

    if fee_on == 1:
        if is_klast_equal_to_zero == 0:
            let (reserve_mul_low: Uint256, reserve_mul_high: Uint256) = uint256_mul(reserve0, reserve1)
            let (is_reserve_mul_high_equal_to_zero) =  uint256_eq(reserve_mul_high, Uint256(0, 0))
            assert is_reserve_mul_high_equal_to_zero = 1
            let (local rootk: Uint256) = uint256_sqrt(reserve_mul_low)
            let (local rootklast: Uint256) = uint256_sqrt(klast)
            let (is_rootk_greater_than_rootklast) = uint256_lt(rootklast, rootk)
            if is_rootk_greater_than_rootklast == 1:
                let (local rootkdiff: Uint256) = uint256_sub(rootk, rootklast)
                let (local _total_supply: Uint256) = total_supply.read()
                let (numerator_mul_low: Uint256, numerator_mul_high: Uint256) = uint256_mul(rootkdiff, _total_supply)
                let (is_numerator_mul_high_equal_to_zero) =  uint256_eq(numerator_mul_high, Uint256(0, 0))
                assert is_numerator_mul_high_equal_to_zero = 1
                let (denominator_mul_low: Uint256, denominator_mul_high: Uint256) = uint256_mul(rootk, Uint256(5, 0))
                let (is_denominator_mul_high_equal_to_zero) =  uint256_eq(denominator_mul_high, Uint256(0, 0))
                assert is_denominator_mul_high_equal_to_zero = 1
                let (local denominator: Uint256, is_overflow) = uint256_add(denominator_mul_low, rootklast)
                assert (is_overflow) = 0
                let (liquidity: Uint256, _) = uint256_unsigned_div_rem(numerator_mul_low, denominator)
                let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)
                if is_liquidity_greater_than_zero == 1:
                    _mint(fee_to, liquidity)
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                else:
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                end
            else:
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            end
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    else:
        if is_klast_equal_to_zero == 0:
            _klast.write(Uint256(0, 0))
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    end
    return (fee_on)
end

func _get_reserves{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt):
    let (reserve0) = _reserve0.read()
    let (reserve1) = _reserve1.read()
    let (block_timestamp_last) = _block_timestamp_last.read()
    return (reserve0, reserve1, block_timestamp_last)
end

func _update{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(balance0: Uint256, balance1: Uint256, reserve0: Uint256, reserve1: Uint256):
    alloc_locals
    assert balance0.high = 0
    assert balance1.high = 0
    let (block_timestamp) = get_block_timestamp()
    let (block_timestamp_last) = _block_timestamp_last.read()
    let (is_block_timestamp_greater_than_equal_to_last) = is_le(block_timestamp_last, block_timestamp)
    if is_block_timestamp_greater_than_equal_to_last == 1:
        let (is_block_timestamp_not_equal_to_last) = is_not_zero(block_timestamp - block_timestamp_last)
        if is_block_timestamp_not_equal_to_last == 1:
            let (is_reserve0_equal_to_zero) = uint256_eq(reserve0, Uint256(0, 0)) 
            if is_reserve0_equal_to_zero == 0:
                let (is_reserve1_equal_to_zero) = uint256_eq(reserve1, Uint256(0, 0)) 
                if is_reserve1_equal_to_zero == 0:
                    let (price_0_cumulative_last) = _price_0_cumulative_last.read()
                    let (reserve1by0: Uint256, _) = uint256_unsigned_div_rem(reserve1, reserve0)
                    let (reserve1by0multime: Uint256, mul_high0: Uint256) = uint256_mul(reserve1by0, Uint256(block_timestamp - block_timestamp_last, 0))
                    let (is_equal_to_zero0) =  uint256_eq(mul_high0, Uint256(0, 0))
                    assert is_equal_to_zero0 = 1
                    let (new_price_0_cumulative: Uint256, is_overflow0) = uint256_add(price_0_cumulative_last, reserve1by0multime)
                    assert (is_overflow0) = 0
                    _price_0_cumulative_last.write(new_price_0_cumulative)
                    _reserve0_last.write(reserve0)
                    
                    let (price_1_cumulative_last) = _price_1_cumulative_last.read()
                    let (reserve0by1: Uint256, _) = uint256_unsigned_div_rem(reserve0, reserve1)
                    let (reserve0by1multime: Uint256, mul_high1: Uint256) = uint256_mul(reserve0by1, Uint256(block_timestamp - block_timestamp_last, 0))
                    let (is_equal_to_zero1) =  uint256_eq(mul_high1, Uint256(0, 0))
                    assert is_equal_to_zero1 = 1
                    let (new_price_1_cumulative: Uint256, is_overflow1) = uint256_add(price_1_cumulative_last, reserve0by1multime)
                    assert (is_overflow1) = 0
                    _price_1_cumulative_last.write(new_price_1_cumulative)
                    _reserve1_last.write(reserve1)
                    
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                else:
                    tempvar syscall_ptr = syscall_ptr
                    tempvar pedersen_ptr = pedersen_ptr
                    tempvar range_check_ptr = range_check_ptr
                end
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            else:
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
            end
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    _reserve0.write(balance0)
    _reserve1.write(balance1)
    _block_timestamp_last.write(block_timestamp)

    Sync.emit(reserve0=balance0, reserve1=balance1)
    return ()
end
