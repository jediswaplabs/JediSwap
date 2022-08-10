%lang starknet

# @title JediSwap Pair
# @author Mesh Finance
# @license MIT
# @notice Low level pair contract
# @dev Based on the Uniswap V2 pair
#      https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
#      Also an ERC20 token

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_in_range,
    assert_le,
    assert_not_equal,
)
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_sqrt,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from openzeppelin.token.erc20.library import ERC20
from contracts.utils.math import (
    uint256_checked_add,
    uint256_checked_sub_lt,
    uint256_checked_sub_le,
    uint256_checked_mul,
    uint256_felt_checked_mul,
)


const MINIMUM_LIQUIDITY = 1000
const BURN_ADDRESS = 1

#
# Interfaces
#
@contract_interface
namespace IERC20:
    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end
end

@contract_interface
namespace IFactory:
    func get_fee_to() -> (address : felt):
    end
end

@contract_interface
namespace IJediSwapCallee:
    func jediswap_call(
        sender : felt, amount0Out : Uint256, amount1Out : Uint256, data_len : felt, data : felt*
    ):
    end
end

#
# Storage Pair
#

# @dev token0 address
@storage_var
func _token0() -> (address : felt):
end

# @dev token1 address
@storage_var
func _token1() -> (address : felt):
end

# @dev reserve for token0
@storage_var
func _reserve0() -> (res : Uint256):
end

# @dev reserve for token1
@storage_var
func _reserve1() -> (res : Uint256):
end

# @dev block timestamp for last update
@storage_var
func _block_timestamp_last() -> (ts : felt):
end

# @dev cumulative price for token0 on last update
@storage_var
func _price_0_cumulative_last() -> (res : Uint256):
end

# @dev cumulative price for token1 on last update
@storage_var
func _price_1_cumulative_last() -> (res : Uint256):
end

# @dev reserve0 * reserve1, as of immediately after the most recent liquidity event
@storage_var
func _klast() -> (res : Uint256):
end

# @dev Boolean to check reentrancy
@storage_var
func _locked() -> (res : felt):
end

# @dev Factory contract address
@storage_var
func _factory() -> (address : felt):
end

# @notice An event emitted whenever token is transferred.
@event
func Transfer(from_address : felt, to_address : felt, amount : Uint256):
end

# @notice An event emitted whenever allowances is updated
@event
func Approval(owner : felt, spender : felt, amount : Uint256):
end

# @notice An event emitted whenever mint() is called.
@event
func Mint(sender : felt, amount0 : Uint256, amount1 : Uint256):
end

# @notice An event emitted whenever burn() is called.
@event
func Burn(sender : felt, amount0 : Uint256, amount1 : Uint256, to : felt):
end

# @notice An event emitted whenever swap() is called.
@event
func Swap(
    sender : felt,
    amount0In : Uint256,
    amount1In : Uint256,
    amount0Out : Uint256,
    amount1Out : Uint256,
    to : felt,
):
end

# @notice An event emitted whenever _update() is called.
@event
func Sync(reserve0 : Uint256, reserve1 : Uint256):
end

#
# Constructor
#

# @notice Contract constructor
# @param name Name of the pair token
# @param symbol Symbol of the pair token
# @param token0 Address of token0
# @param token1 Address of token1
# @param factory Address of factory contract
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token0 : felt, token1 : felt, factory : felt
):
    with_attr error_message("Pair::constructor::all arguments must be non zero"):
        assert_not_zero(token0)
        assert_not_zero(token1)
    end
    ERC20.initializer('JediSwap Pair', 'JEDI-P', 18)
    _locked.write(0)
    _token0.write(token0)
    _token1.write(token1)
    _factory.write(factory)
    return ()
end

#
# Getters ERC20
#

# @notice Name of the token
# @return name
@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC20.name()
    return (name)
end

# @notice Symbol of the token
# @return symbol
@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

# @notice Total Supply of the token
# @return totalSupply
@view
func totalSupply{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20.total_supply()
    return (totalSupply)
end

# @notice Decimals of the token
# @return decimals
@view
func decimals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

# @notice Balance of `account`
# @param account Account address whose balance is fetched
# @return balance Balance of `account`
@view
func balanceOf{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20.balance_of(account)
    return (balance)
end

# @notice Allowance which `spender` can spend on behalf of `owner`
# @param owner Account address whose tokens are spent
# @param spender Account address which can spend the tokens
# @return remaining
@view
func allowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt, spender: felt) -> (remaining: Uint256):
    let (remaining: Uint256) = ERC20.allowance(owner, spender)
    return (remaining)
end

#
# Getters Pair
#

# @notice token0 address
# @return address
@view
func token0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token0.read()
    return (address)
end

# @notice token1 address
# @return address
@view
func token1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = _token1.read()
    return (address)
end

# @notice Current reserves for tokens in the pair
# @return reserve0 reserve for token0
# @return reserve1 reserve for token1
# @return block_timestamp_last block timestamp for last update
@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt
):
    return _get_reserves()
end

# @notice cumulative price for token0 on last update
# @return res
@view
func price_0_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : Uint256):
    let (res) = _price_0_cumulative_last.read()
    return (res)
end

# @notice cumulative price for token1 on last update
# @return res
@view
func price_1_cumulative_last{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : Uint256):
    let (res) = _price_1_cumulative_last.read()
    return (res)
end

# @notice reserve0 * reserve1, as of immediately after the most recent liquidity event
# @return res
@view
func klast{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : Uint256):
    let (res) = _klast.read()
    return (res)
end

#
# Externals ERC20
#

# @notice Transfer `amount` tokens from `caller` to `recipient`
# @param recipient Account address to which tokens are transferred
# @param amount Amount of tokens to transfer
# @return success 0 or 1
@external
func transfer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

# @notice Transfer `amount` tokens from `sender` to `recipient`
# @dev Checks for allowance.
# @param sender Account address from which tokens are transferred
# @param recipient Account address to which tokens are transferred
# @param amount Amount of tokens to transfer
# @return success 0 or 1
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
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

# @notice Approve `spender` to transfer `amount` tokens on behalf of `caller`
# @param spender The address which will spend the funds
# @param amount The amount of tokens to be spent
# @return success 0 or 1
@external
func approve{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, amount: Uint256) -> (success: felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

# @notice Increase allowance of `spender` to transfer `added_value` more tokens on behalf of `caller`
# @param spender The address which will spend the funds
# @param added_value The increased amount of tokens to be spent
# @return success 0 or 1
@external
func increaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, added_value: Uint256) -> (success: felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

# @notice Decrease allowance of `spender` to transfer `subtracted_value` less tokens on behalf of `caller`
# @param spender The address which will spend the funds
# @param subtracted_value The decreased amount of tokens to be spent
# @return success 0 or 1
@external
func decreaseAllowance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(spender: felt, subtracted_value: Uint256) -> (success: felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end

#
# Externals Pair
#

# @notice Mint tokens and assign them to `to`
# @dev This low-level function should be called from a contract which performs important safety checks
# @param to The account that will receive the created tokens
# @return liquidity New tokens created
@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt) -> (
    liquidity : Uint256
):
    alloc_locals
    _check_and_lock()
    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local amount0 : Uint256) = uint256_checked_sub_lt(balance0, reserve0)
    let (local amount1 : Uint256) = uint256_checked_sub_lt(balance1, reserve1)

    let (fee_on) = _mint_protocol_fee(reserve0, reserve1)

    let (local _total_supply : Uint256) = totalSupply()
    let (is_total_supply_equal_to_zero) = uint256_eq(_total_supply, Uint256(0, 0))

    local liquidity : Uint256

    if is_total_supply_equal_to_zero == 1:
        let (amount0_mul_amount1 : Uint256) = uint256_checked_mul(amount0, amount1)

        let (mul_sqrt : Uint256) = uint256_sqrt(amount0_mul_amount1)

        # local mul_sqrt: Uint256
        # assert mul_sqrt = amount0

        let (initial_liquidity : Uint256) = uint256_checked_sub_lt(
            mul_sqrt, Uint256(MINIMUM_LIQUIDITY, 0)
        )
        assert liquidity = initial_liquidity
        ERC20._mint(BURN_ADDRESS, Uint256(MINIMUM_LIQUIDITY, 0))
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (amount0_mul_total_supply : Uint256) = uint256_checked_mul(amount0, _total_supply)
        let (liquidity0 : Uint256, _) = uint256_unsigned_div_rem(amount0_mul_total_supply, reserve0)

        let (amount1_mul_total_supply : Uint256) = uint256_checked_mul(amount1, _total_supply)
        let (liquidity1 : Uint256, _) = uint256_unsigned_div_rem(amount1_mul_total_supply, reserve1)

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

    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)
    with_attr error_message("Pair::mint::insufficient liquidity minted"):
        assert is_liquidity_greater_than_zero = 1
    end

    ERC20._mint(to, liquidity)

    _update(balance0, balance1, reserve0, reserve1)

    if fee_on == 1:
        let (klast : Uint256) = uint256_checked_mul(balance0, balance1)
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

# @notice Burn tokens belonging to `to`
# @dev This low-level function should be called from a contract which performs important safety checks
# @param to The account that will receive the created tokens
# @return amount0 Amount of token0 received
# @return amount1 Amount of token1 received
@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt) -> (
    amount0 : Uint256, amount1 : Uint256
):
    alloc_locals
    _check_and_lock()
    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()

    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local liquidity : Uint256) = balanceOf(self_address)

    let (fee_on) = _mint_protocol_fee(reserve0, reserve1)

    let (local _total_supply : Uint256) = totalSupply()
    let (is_total_supply_greater_than_zero) = uint256_lt(Uint256(0, 0), _total_supply)

    assert is_total_supply_greater_than_zero = 1

    let (liquidity_mul_balance0 : Uint256) = uint256_checked_mul(liquidity, balance0)
    let (local amount0 : Uint256, _) = uint256_unsigned_div_rem(
        liquidity_mul_balance0, _total_supply
    )
    let (is_amount0_greater_than_zero) = uint256_lt(Uint256(0, 0), amount0)

    let (liquidity_mul_balance1 : Uint256) = uint256_checked_mul(liquidity, balance1)
    let (local amount1 : Uint256, _) = uint256_unsigned_div_rem(
        liquidity_mul_balance1, _total_supply
    )
    let (is_amount1_greater_than_zero) = uint256_lt(Uint256(0, 0), amount1)

    with_attr error_message("Pair::burn::insufficient liquidity burned"):
        assert is_amount0_greater_than_zero = 1
        assert is_amount1_greater_than_zero = 1
    end

    ERC20._burn(self_address, liquidity)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    let (local final_balance0 : Uint256) = IERC20.balanceOf(
        contract_address=token0, account=self_address
    )
    let (local final_balance1 : Uint256) = IERC20.balanceOf(
        contract_address=token1, account=self_address
    )

    _update(final_balance0, final_balance1, reserve0, reserve1)

    if fee_on == 1:
        let (klast : Uint256) = uint256_checked_mul(final_balance0, final_balance1)
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

# @notice Swaps from one token to another
# @dev This low-level function should be called from a contract which performs important safety checks
# @param amount0Out Amount of token0 received
# @param amount1Out Amount of token1 received
# @param to The account that will receive the tokens
@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount0Out : Uint256, amount1Out : Uint256, to : felt, data_len : felt, data : felt*
):
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
    with_attr error_message("Pair::swap::insufficient output amount"):
        assert sufficient_output_amount = 1
    end

    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()
    let (is_amount0out_lesser_than_reserve0) = uint256_lt(amount0Out, reserve0)
    let (is_amount1out_lesser_than_reserve0) = uint256_lt(amount1Out, reserve1)
    with_attr error_message("Pair::swap::insufficient liquidity"):
        assert is_amount0out_lesser_than_reserve0 = 1
        assert is_amount1out_lesser_than_reserve0 = 1
    end

    let (local token0) = _token0.read()
    let (local token1) = _token1.read()
    with_attr error_message("Pair::swap::invalid to"):
        assert_not_equal(token0, to)
        assert_not_equal(token1, to)
    end

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

    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    let (caller_address) = get_caller_address()

    let (data_len_greater_than_zero) = is_le(1, data_len)
    if data_len_greater_than_zero == 1:
        IJediSwapCallee.jediswap_call(
            contract_address=to,
            sender=caller_address,
            amount0Out=amount0Out,
            amount1Out=amount1Out,
            data_len=data_len,
            data=data,
        )
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local expected_balance0 : Uint256) = uint256_checked_sub_le(reserve0, amount0Out)
    let (local expected_balance1 : Uint256) = uint256_checked_sub_le(reserve1, amount1Out)

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
    with_attr error_message("Pair::swap::insufficient input amount"):
        assert sufficient_input_amount = 1
    end

    let (local amount0In : Uint256) = uint256_checked_sub_le(balance0, expected_balance0)
    let (local amount1In : Uint256) = uint256_checked_sub_le(balance1, expected_balance1)

    let (balance0_mul_1000 : Uint256) = uint256_felt_checked_mul(balance0, 1000)
    let (amount0In_mul_3 : Uint256) = uint256_felt_checked_mul(amount0In, 3)
    let (local balance0Adjusted : Uint256) = uint256_checked_sub_lt(
        balance0_mul_1000, amount0In_mul_3
    )

    let (balance1_mul_1000 : Uint256) = uint256_felt_checked_mul(balance1, 1000)
    let (amount1In_mul_3 : Uint256) = uint256_felt_checked_mul(amount1In, 3)
    let (local balance1Adjusted : Uint256) = uint256_checked_sub_lt(
        balance1_mul_1000, amount1In_mul_3
    )

    let (balance0Adjusted_mul_balance1Adjusted : Uint256) = uint256_checked_mul(
        balance0Adjusted, balance1Adjusted
    )

    let (reserve0_mul_reserve1 : Uint256) = uint256_checked_mul(reserve0, reserve1)

    let (local multiplier) = pow(1000, 2)
    let (reserve0_mul_reserve1_mul_multiplier : Uint256) = uint256_felt_checked_mul(
        reserve0_mul_reserve1, multiplier
    )

    let (is_balance_adjusted_mul_greater_than_equal_final_reserve_mul) = uint256_le(
        reserve0_mul_reserve1_mul_multiplier, balance0Adjusted_mul_balance1Adjusted
    )
    with_attr error_message("Pair::swap::invariant K"):
        assert is_balance_adjusted_mul_greater_than_equal_final_reserve_mul = 1
    end

    _update(balance0, balance1, reserve0, reserve1)

    let (caller) = get_caller_address()

    Swap.emit(
        sender=caller,
        amount0In=amount0In,
        amount1In=amount1In,
        amount0Out=amount0Out,
        amount1Out=amount1Out,
        to=to,
    )

    _unlock()

    return ()
end

# @notice force balances to match reserves
# @param to The account that will receive the balance tokens
@external
func skim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt):
    alloc_locals
    _check_and_lock()
    let (local reserve0 : Uint256, local reserve1 : Uint256, _) = _get_reserves()

    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local amount0 : Uint256) = uint256_checked_sub_lt(balance0, reserve0)
    let (local amount1 : Uint256) = uint256_checked_sub_lt(balance1, reserve1)

    IERC20.transfer(contract_address=token0, recipient=to, amount=amount0)
    IERC20.transfer(contract_address=token1, recipient=to, amount=amount1)

    _unlock()

    return ()
end

# @notice Force reserves to match balances
@external
func sync{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    _check_and_lock()

    let (self_address) = get_contract_address()
    let (token0) = _token0.read()
    let (local balance0 : Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (token1) = _token1.read()
    let (local balance1 : Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    let (local reserve0 : Uint256) = _reserve0.read()
    let (local reserve1 : Uint256) = _reserve1.read()

    _update(balance0, balance1, reserve0, reserve1)

    _unlock()

    return ()
end

#
# Internals Pair
#

# @dev Check if the entry is not locked, and lock it
func _check_and_lock{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (locked) = _locked.read()
    with_attr error_message("Pair::_check_and_lock::locked"):
        assert locked = 0
    end
    _locked.write(1)
    return ()
end

# @dev Unlock the entry
func _unlock{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (locked) = _locked.read()
    with_attr error_message("Pair::_unlock::not locked"):
        assert locked = 1
    end
    _locked.write(0)
    return ()
end

# @dev If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
func _mint_protocol_fee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve0 : Uint256, reserve1 : Uint256
) -> (fee_on : felt):
    alloc_locals
    let (local factory) = _factory.read()
    let (local fee_to) = IFactory.get_fee_to(contract_address=factory)
    let (local fee_on) = is_not_zero(fee_to)

    let (local klast : Uint256) = _klast.read()
    let (local is_klast_equal_to_zero) = uint256_eq(klast, Uint256(0, 0))

    if fee_on == 1:
        if is_klast_equal_to_zero == 0:
            let (reserve0_mul_reserve1 : Uint256) = uint256_checked_mul(reserve0, reserve1)
            let (local rootk : Uint256) = uint256_sqrt(reserve0_mul_reserve1)
            let (local rootklast : Uint256) = uint256_sqrt(klast)
            let (is_rootk_greater_than_rootklast) = uint256_lt(rootklast, rootk)
            if is_rootk_greater_than_rootklast == 1:
                let (local rootkdiff : Uint256) = uint256_checked_sub_le(rootk, rootklast)
                let (local _total_supply : Uint256) = totalSupply()
                let (numerator : Uint256) = uint256_checked_mul(rootkdiff, _total_supply)
                let (rootk_mul_5 : Uint256) = uint256_felt_checked_mul(rootk, 5)
                let (local denominator : Uint256) = uint256_checked_add(rootk_mul_5, rootklast)
                let (liquidity : Uint256, _) = uint256_unsigned_div_rem(numerator, denominator)
                let (is_liquidity_greater_than_zero) = uint256_lt(Uint256(0, 0), liquidity)
                if is_liquidity_greater_than_zero == 1:
                    ERC20._mint(fee_to, liquidity)
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

func _get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt
):
    let (reserve0) = _reserve0.read()
    let (reserve1) = _reserve1.read()
    let (block_timestamp_last) = _block_timestamp_last.read()
    return (reserve0, reserve1, block_timestamp_last)
end

# @dev Update reserves and, on the first call per block, price accumulators
func _update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    balance0 : Uint256, balance1 : Uint256, reserve0 : Uint256, reserve1 : Uint256
):
    alloc_locals
    with_attr error_message("Pair::_update::overflow"):
        assert balance0.high = 0
        assert balance1.high = 0
    end
    let (block_timestamp) = get_block_timestamp()
    let (block_timestamp_last) = _block_timestamp_last.read()
    let (is_block_timestamp_greater_than_equal_to_last) = is_le(
        block_timestamp_last, block_timestamp
    )
    if is_block_timestamp_greater_than_equal_to_last == 1:
        let (is_block_timestamp_not_equal_to_last) = is_not_zero(
            block_timestamp - block_timestamp_last
        )
        if is_block_timestamp_not_equal_to_last == 1:
            let (is_reserve0_equal_to_zero) = uint256_eq(reserve0, Uint256(0, 0))
            if is_reserve0_equal_to_zero == 0:
                let (is_reserve1_equal_to_zero) = uint256_eq(reserve1, Uint256(0, 0))
                if is_reserve1_equal_to_zero == 0:
                    let (price_0_cumulative_last) = _price_0_cumulative_last.read()
                    let (reserve1by0 : Uint256, _) = uint256_unsigned_div_rem(reserve1, reserve0)
                    let (reserve1by0_mul_time : Uint256) = uint256_felt_checked_mul(
                        reserve1by0, block_timestamp - block_timestamp_last
                    )
                    let (new_price_0_cumulative : Uint256) = uint256_checked_add(
                        price_0_cumulative_last, reserve1by0_mul_time
                    )
                    _price_0_cumulative_last.write(new_price_0_cumulative)

                    let (price_1_cumulative_last) = _price_1_cumulative_last.read()
                    let (reserve0by1 : Uint256, _) = uint256_unsigned_div_rem(reserve0, reserve1)
                    let (reserve0by1_mul_time : Uint256) = uint256_felt_checked_mul(
                        reserve0by1, block_timestamp - block_timestamp_last
                    )
                    let (new_price_1_cumulative : Uint256) = uint256_checked_add(
                        price_1_cumulative_last, reserve0by1_mul_time
                    )
                    _price_1_cumulative_last.write(new_price_1_cumulative)

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
