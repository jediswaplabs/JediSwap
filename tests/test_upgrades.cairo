%lang starknet

@contract_interface
namespace IFactory {
    func create_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func set_fee_to(new_fee_to: felt) {
    }

    func set_fee_to_setter(new_fee_to_setter: felt) {
    }

    func get_fee_to() -> (address: felt) {
    }

    func get_fee_to_setter() -> (address: felt) {
    }
}

@contract_interface
namespace IRouter {
    func factory() -> (address: felt) {
    }

    func sort_tokens(tokenA: felt, tokenB: felt) -> (token0: felt, token1: felt) {
    }
}

@contract_interface
namespace IProxy {
    func upgrade(new_implementation: felt) {
    }

    func set_admin(new_admin: felt) {
    }

    func get_admin() -> (admin: felt) {
    }

    func get_implementation_hash() -> (implementation: felt) {
    }
}

@contract_interface
namespace IV2 {
    func test_v2_contract() -> (success: felt) {
    }
}

@external
func __setup__{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address = 123456789987654321;
    tempvar factory_address;
    tempvar router_address;
    tempvar token_0_address;
    tempvar token_1_address;
    %{
        context.deployer_address = ids.deployer_address
        context.declared_pair_proxy_class_hash = declare("contracts/PairProxy.cairo").class_hash
        context.declared_pair_class_hash = declare("contracts/Pair.cairo").class_hash
        context.declared_factory_class_hash = declare("contracts/Factory.cairo").class_hash
        context.factory_address = deploy_contract("contracts/FactoryProxy.cairo", [context.declared_factory_class_hash, context.declared_pair_proxy_class_hash, context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.declared_router_class_hash = declare("contracts/Router.cairo").class_hash
        context.router_address = deploy_contract("contracts/RouterProxy.cairo", [context.declared_router_class_hash, context.factory_address, context.deployer_address]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}
    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(
        contract_address=router_address, tokenA=token_0_address, tokenB=token_1_address
    );

    let (pair_address) = IFactory.create_pair(
        contract_address=factory_address,
        token0=sorted_token_0_address,
        token1=sorted_token_1_address,
    );

    %{ context.pair_address = ids.pair_address %}
    return ();
}

@external
func test_upgrade_implementation_non_admin{syscall_ptr: felt*, range_check_ptr}() {
    tempvar factory_address;
    tempvar router_address;
    tempvar pair_address;
    tempvar declared_factory_v2_class_hash;
    tempvar declared_router_v2_class_hash;
    tempvar declared_pair_v2_class_hash;

    %{ 
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.pair_address = context.pair_address
        ids.declared_factory_v2_class_hash = declare("contracts/test/FactoryV2.cairo").class_hash
        ids.declared_router_v2_class_hash = declare("contracts/test/RouterV2.cairo").class_hash
        ids.declared_pair_v2_class_hash = declare("contracts/test/PairV2.cairo").class_hash
    %}

    %{ expect_revert(error_message="Proxy: caller is not admin") %}
    IProxy.upgrade(contract_address=factory_address, new_implementation=declared_factory_v2_class_hash);

    %{ expect_revert(error_message="Proxy: caller is not admin") %}
    IProxy.upgrade(contract_address=router_address, new_implementation=declared_router_v2_class_hash);

    %{ expect_revert(error_message="Proxy: caller is not admin") %}
    IProxy.upgrade(contract_address=pair_address, new_implementation=declared_pair_v2_class_hash);

    return ();
}

@external
func test_upgrade_implementation{syscall_ptr: felt*, range_check_ptr}() {
    tempvar deployer_address;
    tempvar factory_address;
    tempvar router_address;
    tempvar pair_address;
    tempvar declared_factory_v2_class_hash;
    tempvar declared_router_v2_class_hash;
    tempvar declared_pair_v2_class_hash;

    %{
        ids.deployer_address = context.deployer_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.pair_address = context.pair_address
        ids.declared_factory_v2_class_hash = declare("contracts/test/FactoryV2.cairo").class_hash
        ids.declared_router_v2_class_hash = declare("contracts/test/RouterV2.cairo").class_hash
        ids.declared_pair_v2_class_hash = declare("contracts/test/PairV2.cairo").class_hash
    %}

    %{ expect_revert(error_type="ENTRY_POINT_NOT_FOUND_IN_CONTRACT") %}
    IV2.test_v2_contract(contract_address=factory_address);

    let (fee_to_setter_address_initial) = IFactory.get_fee_to_setter(contract_address=factory_address);

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.factory_address) %}
    IProxy.upgrade(
        contract_address=factory_address, new_implementation=declared_factory_v2_class_hash
    );
    %{ stop_prank() %}

    let (factory_implementation) = IProxy.get_implementation_hash(contract_address=factory_address);
    assert factory_implementation = declared_factory_v2_class_hash;

    let (factory_v2_success) = IV2.test_v2_contract(contract_address=factory_address);
    assert factory_v2_success = 1;

    let (fee_to_setter_address_final) = IFactory.get_fee_to_setter(contract_address=factory_address);
    assert fee_to_setter_address_final = fee_to_setter_address_initial;

    %{ expect_revert(error_type="ENTRY_POINT_NOT_FOUND_IN_CONTRACT") %}
    IV2.test_v2_contract(contract_address=deployer_address);

    let (factory_address_from_router_initial) = IRouter.factory(contract_address=router_address);

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.router_address) %}
    IProxy.upgrade(
        contract_address=router_address, new_implementation=declared_router_v2_class_hash
    );
    %{ stop_prank() %}

    let (router_implementation) = IProxy.get_implementation_hash(contract_address=router_address);
    assert router_implementation = declared_router_v2_class_hash;

    let (router_v2_success) = IV2.test_v2_contract(contract_address=router_address);
    assert router_v2_success = 1;

    let (factory_address_from_router_final) = IRouter.factory(contract_address=router_address);
    assert factory_address_from_router_final = factory_address_from_router_initial;

    %{ expect_revert(error_type="ENTRY_POINT_NOT_FOUND_IN_CONTRACT") %}
    IV2.test_v2_contract(contract_address=pair_address);

    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.pair_address) %}
    IProxy.upgrade(
        contract_address=pair_address, new_implementation=declared_pair_v2_class_hash
    );
    %{ stop_prank() %}

    let (pair_implementation) = IProxy.get_implementation_hash(contract_address=pair_address);
    assert pair_implementation = declared_pair_v2_class_hash;

    let (pair_v2_success) = IV2.test_v2_contract(contract_address=pair_address);
    assert pair_v2_success = 1;

    return ();
}
