use starknet:: { ContractAddress, ClassHash, contract_address_try_from_felt252, contract_address_const };

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
