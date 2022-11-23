%lang starknet

// @title JediSwap V2 Factory Proxy
// @author Mesh Finance
// @license MIT
// @notice Upgradeable proxy for Factory.cairo

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import library_call, library_call_l1_handler
from starkware.cairo.common.alloc import alloc
from openzeppelin.upgrades.library import Proxy

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    implementation_hash: felt, pair_proxy_contract_class_hash:felt, pair_contract_class_hash: felt, fee_to_setter: felt
) {
    
    Proxy._set_implementation_hash(implementation_hash);
    
    let calldata: felt* = alloc();
    assert [calldata] = pair_proxy_contract_class_hash;
    assert [calldata + 1] = pair_contract_class_hash;
    assert [calldata + 2] = fee_to_setter;
    library_call(
        class_hash=implementation_hash,
        function_selector=1295919550572838631247819983596733806859788957403169325509326258146877103642,  // initializer
        calldata_size=3,
        calldata=calldata,
    );
    return ();
}

//
// Fallback functions
//

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    let (class_hash) = Proxy.get_implementation_hash();

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return (retdata_size, retdata);
}

@l1_handler
@raw_input
func __l1_default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) {
    let (class_hash) = Proxy.get_implementation_hash();

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

@external
func set_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_admin: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_admin(new_admin);
    return ();
}

@view
func get_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        admin: felt
) {
    return Proxy.get_admin();
}

@view
func get_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation: felt
) {
    return Proxy.get_implementation_hash();
}
