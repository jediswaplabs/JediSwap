%lang starknet

// @title JediSwap V2 Factory
// @author Mesh Finance
// @license MIT
// @notice Factory to create and register new pairs

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from openzeppelin.upgrades.library import Proxy

//
// Storage
//

// @dev Address of fee recipient
@storage_var
func _fee_to() -> (address: felt) {
}

// @dev Address allowed to change feeTo.
@storage_var
func _fee_to_setter() -> (address: felt) {
}

// @dev Array of all pairs
@storage_var
func _all_pairs(index: felt) -> (address: felt) {
}

// @dev Pair address for pair of `token0` and `token1`
@storage_var
func _pair(token0: felt, token1: felt) -> (pair: felt) {
}

// @dev Total pairs
@storage_var
func _num_of_pairs() -> (num: felt) {
}

@storage_var
func _pair_proxy_contract_class_hash() -> (class_hash: felt) {
}

@storage_var
func _pair_contract_class_hash() -> (class_hash: felt) {
}

// @dev Emitted each time a pair is created via createPair
// token0 is guaranteed to be strictly less than token1 by sort order.

@event
func PairCreated(token0: felt, token1: felt, pair: felt, total_pairs: felt) {
}

//
// Constructor
//

// @notice Contract constructor
// @param fee_to_setter Fee Recipient Setter
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_proxy_contract_class_hash: felt, pair_contract_class_hash: felt, fee_to_setter: felt
) {

    with_attr error_message("Factory::constructor::Fee Recipient Setter can not be zero") {
        assert_not_zero(fee_to_setter);
    }

    with_attr error_message("Factory::constructor::Pair Proxy Contract Class Hash can not be zero") {
        assert_not_zero(pair_proxy_contract_class_hash);
    }
    
    with_attr error_message("Factory::constructor::Pair Contract Class Hash can not be zero") {
        assert_not_zero(pair_contract_class_hash);
    }

    _fee_to_setter.write(fee_to_setter);
    _pair_proxy_contract_class_hash.write(pair_proxy_contract_class_hash);
    _pair_contract_class_hash.write(pair_contract_class_hash);
    _num_of_pairs.write(0);
    Proxy.initializer(fee_to_setter);
    return ();
}

//
// Getters
//

// @notice Get pair address for the pair of `token0` and `token1`
// @param token0 Address of token0
// @param token1 Address of token1
// @return pair Address of the pair
@view
func get_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token0: felt, token1: felt
) -> (pair: felt) {
    let (pair_0_1) = _pair.read(token0, token1);
    if (pair_0_1 == 0) {
        let (pair_1_0) = _pair.read(token1, token0);
        return (pair=pair_1_0);
    } else {
        return (pair=pair_0_1);
    }
}

// @notice Get all the pairs registered
// @return all_pairs_len Length of `all_pairs` array
// @return all_pairs Array of addresses of the registered pairs
@view
func get_all_pairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    all_pairs_len: felt, all_pairs: felt*
) {
    alloc_locals;
    let (num_pairs) = _num_of_pairs.read();
    let (local all_pairs: felt*) = alloc();
    let (all_pairs_end: felt*) = _build_all_pairs_array(0, num_pairs, all_pairs);
    return (num_pairs, all_pairs);
}

// @notice Get the number of pairs
// @return num_of_pairs
@view
func get_num_of_pairs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    num_of_pairs: felt
) {
    let (num_of_pairs) = _num_of_pairs.read();
    return (num_of_pairs,);
}

// @notice Get fee recipient address
// @return address
@view
func get_fee_to{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return _fee_to.read();
}

// @notice Get the address allowed to change fee_to.
// @return address
@view
func get_fee_to_setter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return _fee_to_setter.read();
}

// @notice Get the class hash of the Pair contract which is deployed for each pair.
// @return class_hash
@view
func get_pair_contract_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (class_hash: felt) {
    return _pair_proxy_contract_class_hash.read();
}

//
// Setters
//

// @notice Create pair of `tokenA` and `tokenB` with deterministic address using deploy
// @dev tokens are sorted before creating pair. We deploy PairProxy.
// @param tokenA Address of tokenA
// @param tokenB Address of tokenB
// @return pair Address of the created pair
@external
func create_pair{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(tokenA: felt, tokenB: felt) -> (pair: felt) {
    alloc_locals;
    with_attr error_message("Factory::create_pair::tokenA and tokenB must be non zero") {
        assert_not_zero(tokenA);
        assert_not_zero(tokenB);
    }

    with_attr error_message("Factory::create_pair::tokenA and tokenB must be different") {
        assert_not_equal(tokenA, tokenB);
    }

    let (existing_pair) = get_pair(tokenA, tokenB);
    with_attr error_message("Factory::create_pair::pair already exists for tokenA and tokenB") {
        assert existing_pair = 0;
    }
    let (pair_proxy_class_hash: felt) = _pair_proxy_contract_class_hash.read();
    let (pair_implementation_class_hash: felt) = _pair_contract_class_hash.read();

    let (token0, token1) = _sort_tokens(tokenA, tokenB);

    let (contract_address: felt) = get_contract_address();

    tempvar pedersen_ptr = pedersen_ptr;

    let (salt) = hash2{hash_ptr=pedersen_ptr}(token0, token1);

    let (fee_to_setter) = get_fee_to_setter();

    let constructor_calldata: felt* = alloc();

    assert [constructor_calldata] = pair_implementation_class_hash;
    assert [constructor_calldata + 1] = token0;
    assert [constructor_calldata + 2] = token1;
    assert [constructor_calldata + 3] = fee_to_setter;

    let (pair: felt) = deploy(
        class_hash=pair_proxy_class_hash,
        contract_address_salt=salt,
        constructor_calldata_size=4,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    _pair.write(token0, token1, pair);
    let (num_pairs) = _num_of_pairs.read();
    _all_pairs.write(num_pairs, pair);
    _num_of_pairs.write(num_pairs + 1);
    PairCreated.emit(token0=token0, token1=token1, pair=pair, total_pairs=num_pairs + 1);

    return (pair=pair);
}

// @notice Change fee recipient to `new_fee_to`
// @dev Only fee_to_setter can change
// @param fee_to Address of new fee recipient
@external
func set_fee_to{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_fee_to: felt) {
    let (sender) = get_caller_address();
    let (fee_to_setter) = get_fee_to_setter();
    with_attr error_message("Factory::set_fee_to::Caller must be fee to setter") {
        assert sender = fee_to_setter;
    }
    _fee_to.write(new_fee_to);
    return ();
}

// @notice Change fee setter to `fee_to_setter`
// @dev Only fee_to_setter can change
// @param fee_to_setter Address of new fee setter
@external
func set_fee_to_setter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_fee_to_setter: felt
) {
    let (sender) = get_caller_address();
    let (fee_to_setter) = get_fee_to_setter();
    with_attr error_message("Factory::set_fee_to_setter::Caller must be fee to setter") {
        assert sender = fee_to_setter;
    }
    with_attr error_message("Factory::set_fee_to_setter::new_fee_to_setter must be non zero") {
        assert_not_zero(new_fee_to_setter);
    }
    _fee_to_setter.write(new_fee_to_setter);
    return ();
}

//
// Internals LIBRARY
//

func _build_all_pairs_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_index: felt, num_pairs: felt, all_pairs: felt*
) -> (all_pairs: felt*) {
    alloc_locals;
    if (current_index == num_pairs) {
        return (all_pairs,);
    }
    let (current_pair) = _all_pairs.read(current_index);
    assert [all_pairs] = current_pair;
    return _build_all_pairs_array(current_index + 1, num_pairs, all_pairs + 1);
}

func _sort_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt, tokenB: felt
) -> (token0: felt, token1: felt) {
    alloc_locals;
    local token0;
    local token1;
    assert_not_equal(tokenA, tokenB);
    let is_tokenA_less_than_tokenB = is_le_felt(tokenA, tokenB);
    if (is_tokenA_less_than_tokenB == 1) {
        assert token0 = tokenA;
        assert token1 = tokenB;
    } else {
        assert token0 = tokenB;
        assert token1 = tokenA;
    }

    assert_not_zero(token0);
    return (token0, token1);
}
