use array::ArrayTrait;
use result::ResultTrait;

#[test]
fn test_deployment_pair_factory_router() { // TODO Separate out once setup is available.
    
    let deployer_address = 123456789987654321;
    
    let declared_pair_class_hash = declare('PairC1').unwrap();
    
    let mut factory_constructor_calldata = ArrayTrait::new();
    factory_constructor_calldata.append(declared_pair_class_hash);
    factory_constructor_calldata.append(deployer_address);
    let factory_address = deploy_contract('FactoryC1', @factory_constructor_calldata).unwrap();

    let mut router_constructor_calldata = ArrayTrait::new();
    router_constructor_calldata.append(factory_address);
    let router_address = deploy_contract('RouterC1', @router_constructor_calldata).unwrap();

    let result = call(router_address, 'factory', @ArrayTrait::new()).unwrap();
    assert(*result.at(0) == factory_address, 'Invalid Factory');

}