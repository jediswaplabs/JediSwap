%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPair:
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256):
    end
end