%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256

#
# Interfaces
#
@contract_interface
namespace IERC20:
    
    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
end

@contract_interface
namespace IPair:
    
    func token0() -> (address: felt):
    end

    func token1() -> (address: felt):
    end
end

@contract_interface
namespace IRegistry:
    func get_pair_for(token0: felt, token1: felt) -> (pair: felt):
    end
end

@storage_var
func _registry() -> (address: felt):
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        registry: felt
    ):
    with_attr error_message("Router::constructor::registry can not be zero"):
        assert_not_zero(registry)
    end
    _registry.write(registry)
    return ()
end

@external
func jediswap_call{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(sender: felt, amount0Out: Uint256, amount1Out: Uint256, data_len: felt, data: felt*):
    alloc_locals
    
    let (caller) = get_caller_address()

    let (local token0) = IPair.token0(contract_address=caller)
    let (local token1) = IPair.token1(contract_address=caller)
    let (local registry) = _registry.read()
    let (local pair) = IRegistry.get_pair_for(contract_address=registry, token0=token0, token1=token1)

    with_attr error_message("FlashSwapTest::jediswap_call::Only valid pair can call"):
        assert pair = caller
    end

    let (self_address) = get_contract_address()
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address)
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address)

    IERC20.transfer(contract_address=token0, recipient=caller, amount=balance0)
    IERC20.transfer(contract_address=token1, recipient=caller, amount=balance1)

    return ()
end