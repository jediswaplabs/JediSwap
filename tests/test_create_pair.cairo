%lang starknet

from protostar.asserts import assert_not_eq

@contract_interface
namespace IFactory:
    func create_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end
end

@contract_interface
namespace IRouter:
    func sort_tokens(tokenA : felt, tokenB : felt) -> (token0 : felt, token1 : felt):
    end
end

@external
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    tempvar deployer_address = 123456789987654321
    tempvar factory_address
    tempvar token_0_address
    tempvar token_1_address
    %{ 
        context.deployer_address = ids.deployer_address
        context.declared_class_hash = declare("contracts/Pair.cairo").class_hash
        context.factory_address = deploy_contract("contracts/Factory.cairo", [context.declared_class_hash, context.deployer_address]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    return ()
end

@external
func test_create_pair_without_tokens{syscall_ptr : felt*, range_check_ptr}():
    
    tempvar factory_address
    tempvar token_0_address

    %{  
        ids.factory_address = context.factory_address
        ids.token_0_address = context.token_0_address
    %}

    %{ expect_revert(error_message="Factory::create_pair::tokenA and tokenB must be non zero") %}
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = 0, token1 = 0)

    %{ expect_revert(error_message="Factory::create_pair::tokenA and tokenB must be non zero") %}
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = token_0_address, token1 = 0)
  
    return ()
end

@external
func test_create_pair_same_tokens{syscall_ptr : felt*, range_check_ptr}():
    
    tempvar factory_address
    tempvar token_0_address

    %{  
        ids.factory_address = context.factory_address
        ids.token_0_address = context.token_0_address
    %}

    %{ expect_revert(error_message="Factory::create_pair::tokenA and tokenB must be different") %}
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = token_0_address, token1 = token_0_address)
  
    return ()
end

@external
func test_create_pair_same_pair{syscall_ptr : felt*, range_check_ptr}():
    
    tempvar factory_address
    tempvar token_0_address
    tempvar token_1_address

    %{  
        ids.factory_address = context.factory_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = token_0_address, token1 = token_1_address)

    assert_not_eq(pair_address, 0)

    %{ expect_revert(error_message="Factory::create_pair::pair already exists for tokenA and tokenB") %}
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = token_0_address, token1 = token_1_address)
    %{ expect_revert(error_message="Factory::create_pair::pair already exists for tokenA and tokenB") %}
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = token_1_address, token1 = token_0_address)

    return ()
end

@external
func test_create2_deployed_pair{syscall_ptr : felt*, range_check_ptr}():
    
    tempvar declared_class_hash
    tempvar factory_address
    tempvar router_address
    tempvar token_0_address
    tempvar token_1_address
    tempvar create2_pair_address

    %{  
        ids.declared_class_hash = context.declared_class_hash
        ids.factory_address = context.factory_address
        ids.router_address = deploy_contract("contracts/Router.cairo", [context.factory_address]).contract_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}

    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address)

    %{  
        from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address_from_hash
        from starkware.cairo.lang.vm.crypto import pedersen_hash
        salt = pedersen_hash(ids.sorted_token_0_address, ids.sorted_token_1_address)
        constructor_calldata = [ids.sorted_token_0_address, ids.sorted_token_1_address, ids.factory_address]
        ids.create2_pair_address = calculate_contract_address_from_hash(salt=salt, class_hash=ids.declared_class_hash, deployer_address=ids.factory_address, constructor_calldata=constructor_calldata)
    %}

    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = sorted_token_0_address, token1 = sorted_token_1_address)

    assert pair_address = create2_pair_address
    
    return ()
end
