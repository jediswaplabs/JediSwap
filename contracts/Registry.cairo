%lang starknet

# @title Jediswap Registry
# @author Mesh Finance
# @license MIT

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc

#
# Storage
#

# @dev Total pairs in the registry
@storage_var
func _num_pairs() -> (num: felt):
end

# @dev Array of all pairs
@storage_var
func _all_pairs(index: felt) -> (address: felt):
end

# @dev Pair address for pair of `token0` and `token1`
@storage_var
func _pair(token0: felt, token1: felt) -> (pair: felt):
end

# @dev Address of fee recipient
@storage_var
func _fee_to() -> (address: felt):
end

#
# Storage Ownable
#

# @dev Address of the owner of the contract
@storage_var
func _owner() -> (address: felt):
end

# @dev Address of the future owner of the contract
@storage_var
func _future_owner() -> (address: felt):
end

# An event emitted whenever initiate_ownership_transfer() is called.
@event
func owner_change_initiated(current_owner: felt, future_owner: felt):
end

# An event emitted whenever accept_ownership() is called.
@event
func owner_change_completed(current_owner: felt, future_owner: felt):
end

# An event emitted whenever set_pair() is called.
@event
func pair_added(token0: felt, token1: felt, pair: felt, total_pairs: felt):
end

#
# Constructor
#

# @notice Contract constructor
# @param initial_owner Owner of this registry contract
@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(initial_owner: felt):
    # get_caller_address() returns '0' in the constructor;
    # therefore, initial_owner parameter is included
    with_attr error_message("Registry::constructor::Initial Owner can not be zero"):
        assert_not_zero(initial_owner)
    end
    _owner.write(initial_owner)
    _fee_to.write(0)
    _num_pairs.write(0)
    return ()
end

#
# Getters
#

# @notice Get all the pairs registered
# @return all_pairs_len Length of `all_pairs` array
# @return all_pairs Array of addresses of the registered pairs
@view
func get_all_pairs{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (all_pairs_len: felt, all_pairs: felt*):
    alloc_locals
    let (num_pairs) = _num_pairs.read()
    let (local all_pairs : felt*) = alloc()
    let (all_pairs_end: felt*) = _build_all_pairs_array(0, num_pairs, all_pairs)
    return (num_pairs, all_pairs)
end

# @notice Get pair address for the pair of `token0` and `token1`
# @param token0 Address of token0
# @param token1 Address of token1
# @return pair Address of the pair
@view
func get_pair_for{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt) -> (pair: felt):
    let (pair) = _pair.read(token0, token1)
    return (pair)
end

# @notice Get fee recipient address
# @return address
@view
func fee_to{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _fee_to.read()
    return (address)
end

# @notice Get contract owner address
# @return address
@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _owner.read()
    return (address)
end

# @notice Get contract future_owner address
# @return address
@view
func future_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _future_owner.read()
    return (address)
end

#
# Setters
#

# @notice Set address for `token0` and `token1` pair to `pair`
# @dev Only owner can set 
# @param token0 Address of token0
# @param token1 Address of token1
# @param pair Address of the pair
@external
func set_pair{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt, pair: felt):
    _only_owner()
    with_attr error_message("Registry::set_pair::all arguments must be non zero"):
        assert_not_zero(token0)
        assert_not_zero(token1)
        assert_not_zero(pair)
    end
    with_attr error_message("Registry::set_pair::token0 and token1 must be different"):
        assert_not_equal(token0, token1)
    end
    let (existing_pair) = _pair.read(token0, token1)
    with_attr error_message("Registry::set_pair::pair already exists for token0 and token1"):
        assert existing_pair = 0
    end
    _pair.write(token0, token1, pair)
    _pair.write(token1, token0, pair)
    let (num_pairs) = _num_pairs.read()
    _all_pairs.write(num_pairs, pair)
    _num_pairs.write(num_pairs + 1)
    pair_added.emit(token0=token0, token1=token1, pair=pair, total_pairs=num_pairs + 1)
    return ()
end

# @notice Change fee recipient to `new_fee_to`
# @dev Only owner can change 
# @param new_fee_to Address of new fee recipient
@external
func update_fee_to{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee_to: felt):
    _only_owner()
    _fee_to.write(new_fee_to)
    return ()
end

#
# Setters Ownable
#

# @notice Change ownership to `future_owner`
# @dev Only owner can change. Needs to be accepted by future_owner using accept_ownership
# @param future_owner Address of new owner
@external
func initiate_ownership_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_owner: felt) -> (future_owner: felt):
    _only_owner()
    let (current_owner) = _owner.read()
    with_attr error_message("Registry::initiate_ownership_transfer::New owner can not be zero"):
        assert_not_zero(future_owner)
    end
    _future_owner.write(future_owner)
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner)
    return (future_owner=future_owner)
end

# @notice Change ownership to future_owner
# @dev Only future_owner can accept. Needs to be initiated via initiate_ownership_transfer
@external
func accept_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (current_owner) = _owner.read()
    let (future_owner) = _future_owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Registry::accept_ownership::Only future owner can accept"):
        assert future_owner = caller
    end
    _owner.write(future_owner)
    owner_change_completed.emit(current_owner=current_owner, future_owner=future_owner)
    return ()
end

#
# Internals Ownable
#

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Registry::_only_owner::Caller must be owner"):
        assert owner = caller
    end
    return ()
end

func _build_all_pairs_array{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, num_pairs: felt, all_pairs: felt*) -> (all_pairs: felt*):
    alloc_locals
    if current_index == num_pairs:
        return (all_pairs)
    end
    let (current_pair) = _all_pairs.read(current_index)
    assert [all_pairs] = current_pair
    return _build_all_pairs_array(current_index + 1, num_pairs, all_pairs + 1)
end