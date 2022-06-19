from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address_from_hash
from starkware.cairo.lang.vm.crypto import pedersen_hash


def get_create2_address(token0: int, token1: int, factory: int, class_hash: int) -> int:

    salt = pedersen_hash(token0, token1)

    constructor_calldata = [token0,
                            token1, factory]

    create2_pair_address = calculate_contract_address_from_hash(
        salt=salt, class_hash=class_hash, deployer_address=factory, constructor_calldata=constructor_calldata)

    return create2_pair_address
