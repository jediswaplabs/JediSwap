%lang starknet

@contract_interface
namespace IFactory {
    func set_fee_to(new_fee_to: felt) {
    }

    func set_fee_to_setter(new_fee_to_setter: felt) {
    }

    func get_fee_to() -> (address: felt) {
    }

    func get_fee_to_setter() -> (address: felt) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address = 123456789987654321;
    tempvar factory_address;
    %{
        context.deployer_address = ids.deployer_address
        context.declared_pair_class_hash = declare("contracts/Pair.cairo").class_hash
        context.factory_address = deploy_contract("contracts/Factory.cairo", [context.declared_pair_class_hash, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
    %}

    return ();
}

@external
func test_set_fee_to_non_fee_to_setter{syscall_ptr: felt*, range_check_ptr}() {
    tempvar factory_address;

    %{ ids.factory_address = context.factory_address %}

    %{ expect_revert(error_message="Factory::set_fee_to::Caller must be fee to setter") %}
    IFactory.set_fee_to(contract_address=factory_address, new_fee_to=200);

    return ();
}

@external
func test_set_fee_to{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address;
    tempvar factory_address;

    %{
        ids.deployer_address = context.deployer_address
        ids.factory_address = context.factory_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.factory_address) %}
    tempvar new_fee_to_address = 200;
    IFactory.set_fee_to(contract_address=factory_address, new_fee_to=new_fee_to_address);
    %{ stop_prank() %}

    let (get_fee_to_address) = IFactory.get_fee_to(contract_address=factory_address);
    assert get_fee_to_address = new_fee_to_address;

    return ();
}

@external
func test_update_fee_to_setter_non_fee_to_setter{syscall_ptr: felt*, range_check_ptr}() {
    tempvar factory_address;

    %{ ids.factory_address = context.factory_address %}

    %{ expect_revert(error_message="Factory::set_fee_to_setter::Caller must be fee to setter") %}
    IFactory.set_fee_to_setter(contract_address=factory_address, new_fee_to_setter=200);

    return ();
}

@external
func test_update_fee_to_setter_zero{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address;
    tempvar factory_address;

    %{
        ids.deployer_address = context.deployer_address
        ids.factory_address = context.factory_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.factory_address) %}
    %{ expect_revert(error_message="Factory::set_fee_to_setter::new_fee_to_setter must be non zero") %}
    IFactory.set_fee_to_setter(contract_address=factory_address, new_fee_to_setter=0);
    %{ stop_prank() %}

    return ();
}

@external
func test_update_fee_to_setter{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address;
    tempvar factory_address;

    %{
        ids.deployer_address = context.deployer_address
        ids.factory_address = context.factory_address
    %}

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.factory_address) %}
    tempvar new_fee_to_setter_address = 200;
    IFactory.set_fee_to_setter(
        contract_address=factory_address, new_fee_to_setter=new_fee_to_setter_address
    );
    %{ stop_prank() %}

    let (get_fee_to_setter_address) = IFactory.get_fee_to_setter(contract_address=factory_address);
    assert get_fee_to_setter_address = new_fee_to_setter_address;

    return ();
}
