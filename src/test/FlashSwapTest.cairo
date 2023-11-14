use zeroable::Zeroable;
use starknet::{ContractAddress};

#[starknet::interface]
trait IFlashSwapTest<T> {
    fn jediswap_call(ref self: T, sender: ContractAddress, amount0Out: u256, amount1Out: u256, data: Array::<felt252>);
}

//
// External Interfaces
//
#[starknet::interface]
trait IERC20<T> {
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IFactory<T> {
    fn get_pair(self: @T, token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
}

#[starknet::interface]
trait IPair<T> {
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn token0(self: @T) -> ContractAddress;
    fn token1(self: @T) -> ContractAddress;
}


#[starknet::contract]
mod FlashSwapTest {
    use zeroable::Zeroable;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait, get_caller_address, get_contract_address};
    use super::{
        IERC20Dispatcher, IERC20DispatcherTrait, IPairDispatcher, IPairDispatcherTrait, IFactoryDispatcher, IFactoryDispatcherTrait
    };

    #[storage]
    struct Storage {
        _factory: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        assert(!factory.is_zero(), 'factory can not be zero');
        self._factory.write(factory);
    }

    #[external(v0)]
    impl FlashSwapTest of super::IFlashSwapTest<ContractState> {

        fn jediswap_call(ref self: ContractState, sender: ContractAddress, amount0Out: u256, amount1Out: u256, data: Array::<felt252>) {
            let caller: ContractAddress = get_caller_address();
            let pairDispatcher = IPairDispatcher { contract_address: caller };
            let token0: ContractAddress = pairDispatcher.token0();
            let token1: ContractAddress = pairDispatcher.token1();

            let factory: ContractAddress = self._factory.read();
            let factoryDispatcher = IFactoryDispatcher { contract_address: factory };
            let pair: ContractAddress = factoryDispatcher.get_pair(token0, token1);

            assert(caller == pair, 'FlashSwapTest::caller == pair');

            let self_address: ContractAddress = get_contract_address();

            let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
            let balance0: u256 = token0Dispatcher.balance_of(self_address);
            token0Dispatcher.transfer(caller, balance0);
            
            let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };
            let balance1: u256 = token1Dispatcher.balance_of(self_address);
            token1Dispatcher.transfer(caller, balance1);
        }
    }
}
