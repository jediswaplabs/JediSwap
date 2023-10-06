use starknet:: { ContractAddress, contract_address_try_from_felt252, contract_address_const };

const TOKEN_MULTIPLIER: u256 = 1000000000000000000;
const TOKEN0_NAME: felt252 = 'TOKEN0';
const TOKEN1_NAME: felt252 = 'TOKEN1';
const TOKEN2_NAME: felt252 = 'TOKEN2';
const SYMBOL: felt252 = 'SYMBOL';
const MINIMUM_LIQUIDITY: u256 = 1000;

fn deployer_addr() -> ContractAddress {
    contract_address_try_from_felt252('deployer').unwrap()
}

fn token0() -> ContractAddress {
    contract_address_try_from_felt252('token0').unwrap()
}

fn token1() -> ContractAddress {
    contract_address_try_from_felt252('token1').unwrap()
}

fn zero_addr() -> ContractAddress {
    contract_address_const::<0>()
}

fn burn_addr() -> ContractAddress {
    contract_address_const::<1>()
}

fn user1() -> ContractAddress {
    contract_address_try_from_felt252('user1').unwrap()
}

fn user2() -> ContractAddress {
    contract_address_try_from_felt252('user2').unwrap()
}
