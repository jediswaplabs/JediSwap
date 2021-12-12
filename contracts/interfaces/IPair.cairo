%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPair:
    
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256):
    end

    func mint(to: felt) -> (liquidity: Uint256):
    end

    func burn(to: felt) -> (amount0: Uint256, amount1: Uint256):
    end

    func swap(amount0Out: Uint256, amount1Out: Uint256, to: felt):
    end
end