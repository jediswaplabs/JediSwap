%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal

#
# Storage
#

@storage_var
func _pair(token0: felt, token1: felt) -> (pair: felt):
end

#
# Storage Ownable
#

@storage_var
func _owner() -> (address: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(initial_owner: felt):
    # get_caller_address() returns '0' in the constructor;
    # therefore, initial_owner parameter is included
    assert_not_zero(initial_owner)
    _owner.write(initial_owner)
    return ()
end

#
# Getters
#

@view
func get_pair_for{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt) -> (pair: felt):
    let (pair) = _pair.read(token0, token1)
    return (pair)
end

#
# Setters
#

@external
func set_pair{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt, pair: felt):
    _only_owner()
    assert_not_zero(token0)
    assert_not_zero(token1)
    assert_not_zero(pair)
    assert_not_equal(token0, token1)
    let (existing_pair) = _pair.read(token0, token1)
    assert existing_pair = 0
    _pair.write(token0, token1, pair)
    _pair.write(token1, token0, pair)
    return ()
end

#
# Setters Ownable
#

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    _only_owner()
    assert_not_zero(new_owner)
    _owner.write(new_owner)
    return (new_owner=new_owner)
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
    assert owner = caller
    return ()
end