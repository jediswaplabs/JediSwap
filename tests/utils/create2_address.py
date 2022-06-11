from Crypto.Hash import keccak
from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address_from_hash
from starkware.python.utils import to_bytes, from_bytes
from utils.uint import to_uint


def get_create2_address(token0: int, token1: int, factory: int, class_hash: int) -> int:
    salt = keccak.new(digest_bits=256)
    token0_byte_address = to_bytes(token0, None, 'little')
    token1_byte_address = to_bytes(token1, None, 'little')

    salt.update(token0_byte_address)
    salt.update(token1_byte_address)

    constructor_calldata = [token0,
                            token1, factory]

    salt_int = from_bytes(salt.digest(), 'little')

    (salt_low, salt_high) = to_uint(salt_int)

    create2_pair_address = calculate_contract_address_from_hash(
        salt=salt_low, class_hash=class_hash, deployer_address=factory, constructor_calldata=constructor_calldata)

    return create2_pair_address
