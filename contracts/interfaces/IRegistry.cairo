%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IRegistry:
    func get_pair_for(token0: felt, token1: felt) -> (pair: felt):
    end
end