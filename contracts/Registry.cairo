%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero

#
# Storage
#

@storage_var
func _pair(token0: felt, token1: felt) -> (pair: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
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
    ## TODO, put some auth here
    assert_not_zero(token0)
    assert_not_zero(token1)
    assert_not_zero(pair)
    _pair.write(token0, token1, pair)
    _pair.write(token1, token0, pair)
    return ()
end