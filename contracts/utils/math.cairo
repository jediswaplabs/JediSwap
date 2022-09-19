%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_eq,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_le,
    uint256_lt,
)

// Adds two integers.
// Reverts if the sum overflows.
func uint256_checked_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (c: Uint256) {
    uint256_check(a);
    uint256_check(b);
    let (c: Uint256, is_overflow) = uint256_add(a, b);
    assert (is_overflow) = 0;
    return (c,);
}

// Subtracts two integers.
// Reverts if minuend (`b`) is greater than subtrahend (`a`).
func uint256_checked_sub_le{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (c: Uint256) {
    alloc_locals;
    uint256_check(a);
    uint256_check(b);
    let (is_le) = uint256_le(b, a);
    assert_not_zero(is_le);
    let (c: Uint256) = uint256_sub(a, b);
    return (c,);
}

// Subtracts two integers.
// Reverts if minuend (`b`) is greater than or equal to subtrahend (`a`).
func uint256_checked_sub_lt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (c: Uint256) {
    alloc_locals;
    uint256_check(a);
    uint256_check(b);

    let (is_lt) = uint256_lt(b, a);
    assert_not_zero(is_lt);
    let (c: Uint256) = uint256_sub(a, b);
    return (c,);
}

// Multiplies two integers.
// Reverts if overflows
func uint256_checked_mul{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (c: Uint256) {
    alloc_locals;
    uint256_check(a);
    uint256_check(b);

    let (c: Uint256, mul_high: Uint256) = uint256_mul(a, b);
    let (is_equal_to_zero) = uint256_eq(mul_high, Uint256(0, 0));
    assert is_equal_to_zero = 1;
    return (c,);
}

// Multiplies two integers.
// Reverts if overflows
func uint256_felt_checked_mul{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: felt
) -> (c: Uint256) {
    alloc_locals;
    uint256_check(a);

    let (c: Uint256, mul_high: Uint256) = uint256_mul(a, Uint256(b, 0));
    let (is_mul_high_equal_to_zero) = uint256_eq(mul_high, Uint256(0, 0));
    assert is_mul_high_equal_to_zero = 1;
    return (c,);
}
