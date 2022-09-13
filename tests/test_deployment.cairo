%lang starknet

@contract_interface
namespace IERC20 {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
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
namespace IFactory {
    func create_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }

    func get_all_pairs() -> (all_pairs_len: felt, all_pairs: felt*) {
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
        context.declared_pair_class_hash = declare("contracts/Pair.cairo").class_hash
        stop_prank = start_prank(context.deployer_address)
        declared_factory = declare("contracts/Factory.cairo")
        prepared_factory = prepare(declared_factory, [context.declared_pair_class_hash])
        context.factory_address = prepared_factory.contract_address
        stop_prank = start_prank(ids.deployer_address, target_contract_address=context.factory_address)
        deploy(prepared_factory)
        stop_prank()
        context.router_address = deploy_contract("contracts/Router.cairo", [context.factory_address]).contract_address
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
func test_pair{syscall_ptr: felt*, range_check_ptr}() {
    tempvar pair_address;

    %{ ids.pair_address = context.pair_address %}

    let (name) = IERC20.name(contract_address=pair_address);
    assert name = 'JediSwap Pair';

    let (symbol) = IERC20.symbol(contract_address=pair_address);
    assert symbol = 'JEDI-P';

    let (decimals) = IERC20.decimals(contract_address=pair_address);
    assert decimals = 18;

    return ();
}

@external
func test_pair_in_factory{syscall_ptr: felt*, range_check_ptr}() {
    tempvar token_0_address;
    tempvar token_1_address;
    tempvar factory_address;
    tempvar pair_address;

    %{
        ids.factory_address = context.factory_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.pair_address = context.pair_address
    %}

    let (pair_address_from_factory_1) = IFactory.get_pair(
        contract_address=factory_address, token0=token_0_address, token1=token_1_address
    );
    assert pair_address_from_factory_1 = pair_address;

    let (pair_address_from_factory_2) = IFactory.get_pair(
        contract_address=factory_address, token0=token_1_address, token1=token_0_address
    );
    assert pair_address_from_factory_2 = pair_address;

    let (all_pairs_len, all_pairs: felt*) = IFactory.get_all_pairs(
        contract_address=factory_address
    );
    assert all_pairs_len = 1;
    assert [all_pairs] = pair_address;

    return ();
}

@external
func test_factory_in_router{syscall_ptr: felt*, range_check_ptr}() {
    tempvar factory_address;
    tempvar router_address;

    %{
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
    %}

    let (factory_address_from_router) = IRouter.factory(contract_address=router_address);
    assert factory_address_from_router = factory_address;

    return ();
}
