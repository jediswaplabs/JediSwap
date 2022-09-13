%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256

//
// Interfaces
//
@contract_interface
namespace IERC20 {
    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }
}

@contract_interface
namespace IPair {
    func token0() -> (address: felt) {
    }

    func token1() -> (address: felt) {
    }
}

@contract_interface
namespace IFactory {
    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }
}

@storage_var
func _factory() -> (address: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(factory: felt) {
    with_attr error_message("Router::constructor::factory can not be zero") {
        assert_not_zero(factory);
    }
    _factory.write(factory);
    return ();
}

@external
func jediswap_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, amount0Out: Uint256, amount1Out: Uint256, data_len: felt, data: felt*
) {
    alloc_locals;

    let (caller) = get_caller_address();

    let (local token0) = IPair.token0(contract_address=caller);
    let (local token1) = IPair.token1(contract_address=caller);
    let (local factory) = _factory.read();
    let (local pair) = IFactory.get_pair(contract_address=factory, token0=token0, token1=token1);

    with_attr error_message("FlashSwapTest::jediswap_call::Only valid pair can call") {
        assert pair = caller;
    }

    let (self_address) = get_contract_address();
    let (local balance0: Uint256) = IERC20.balanceOf(contract_address=token0, account=self_address);
    let (local balance1: Uint256) = IERC20.balanceOf(contract_address=token1, account=self_address);

    IERC20.transfer(contract_address=token0, recipient=caller, amount=balance0);
    IERC20.transfer(contract_address=token1, recipient=caller, amount=balance1);

    return ();
}
