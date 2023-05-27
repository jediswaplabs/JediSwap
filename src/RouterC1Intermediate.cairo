// @title JediSwap router for stateless execution of swaps Cairo 1.0
// @author Mesh Finance
// @license MIT
// @dev Based on the Uniswap V2 Router
//       https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol

#[contract]
mod RouterC1Intermediate {
    use traits::Into;
    use array::ArrayTrait;
    use array::SpanTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use starknet::contract_address_to_felt252;
    use integer::u256_from_felt252;

    //
    // Interfaces
    //
    #[abi]
    trait IERC20 {
        fn transferFrom(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool; // TODO which transferFrom
    }

    #[abi]
    trait IPair {
        fn get_reserves() -> (u256, u256, u64);
        fn mint(to: ContractAddress) -> u256;
        fn burn(to: ContractAddress) -> (u256, u256);
        fn swap(amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>);
    }

    #[abi]
    trait IFactory {
        fn get_pair(token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
        fn create_pair(token0: ContractAddress, token1: ContractAddress) -> ContractAddress;
    }

    //
    // Storage
    //

    struct Storage {
        _factory: ContractAddress, // @dev Factory contract address
        Proxy_admin: ContractAddress, // @dev Proxy admin contract address, to be used to finalize Cairo 1 upgrade.
    }

    //
    // Constructor
    //

    // @notice Contract constructor
    // @param factory Address of factory contract
    #[constructor]
    fn constructor(factory: ContractAddress) {
        assert(!factory.is_zero(), 'can not be zero');
        _factory::write(factory);
    }

    //
    // Getters
    //

    // @notice factory address
    // @return address
    #[view]
    fn factory() -> ContractAddress {
        _factory::read()
    }

    // @notice Sort tokens `tokenA` and `tokenB` by address
    // @param tokenA Address of tokenA
    // @param tokenB Address of tokenB
    // @return token0 First token
    // @return token1 Second token
    #[view]
    fn sort_tokens(
        tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        _sort_tokens(tokenA, tokenB)
    }

    // @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // @param amountA Amount of tokenA
    // @param reserveA Reserves for tokenA
    // @param reserveB Reserves for tokenB
    // @return amountB Amount of tokenB
    #[view]
    fn quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
        _quote(amountA, reserveA, reserveB)
    }

    // @notice Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // @param amountIn Input Amount
    // @param reserveIn Reserves for input token
    // @param reserveOut Reserves for output token
    // @return amountOut Maximum output amount
    #[view]
    fn get_amount_out(amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        _get_amount_out(amountIn, reserveIn, reserveOut)
    }

    // @notice Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // @param amountOut Output Amount
    // @param reserveIn Reserves for input token
    // @param reserveOut Reserves for output token
    // @return amountIn Required input amount
    #[view]
    fn get_amount_in(amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        _get_amount_in(amountOut, reserveIn, reserveOut)
    }

    // @notice Performs chained get_amount_out calculations on any number of pairs
    // @param amountIn Input Amount
    // @param path_len Length of path array
    // @param path Array of pair addresses through which swaps are chained
    // @return amounts_len Required output amount array's length
    // @return amounts Required output amount array
    #[view]
    fn get_amounts_out(amountIn: u256, path: Array::<ContractAddress>) -> Array::<u256> {
        _get_amounts_out(amountIn, path.span())
    }

    // @notice Performs chained get_amount_in calculations on any number of pairs
    // @param amountOut Output Amount
    // @param path_len Length of path array
    // @param path Array of pair addresses through which swaps are chained
    // @return amounts_len Required input amount array's length
    // @return amounts Required input amount array
    #[view]
    fn get_amounts_in(amountOut: u256, path: Array::<ContractAddress>) -> Array::<u256> {
        _get_amounts_in(amountOut, path.span())
    }

    //
    // Externals
    //

    // @notice Add liquidity to a pool
    // @dev `caller` should have already given the router an allowance of at least amountADesired/amountBDesired on tokenA/tokenB
    // @param tokenA Address of tokenA
    // @param tokenB Address of tokenB
    // @param amountADesired The amount of tokenA to add as liquidity
    // @param amountBDesired The amount of tokenB to add as liquidity
    // @param amountAMin Bounds the extent to which the B/A price can go up before the transaction reverts. Must be <= amountADesired
    // @param amountBMin Bounds the extent to which the A/B price can go up before the transaction reverts. Must be <= amountBDesired
    // @param to Recipient of liquidity tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amountA The amount of tokenA sent to the pool
    // @return amountB The amount of tokenB sent to the pool
    // @return liquidity The amount of liquidity tokens minted
    #[external]
    fn add_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256, u256) {
        _ensure_deadline(deadline);
        let (amountA, amountB) = _add_liquidity(
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin
        );
        let pair = _pair_for(tokenA, tokenB);
        let sender = get_caller_address();
        let tokenADispatcher = IERC20Dispatcher { contract_address: tokenA };
        tokenADispatcher.transferFrom(sender, pair, amountA); // TODO which transferFrom
        let tokenBDispatcher = IERC20Dispatcher { contract_address: tokenB };
        tokenBDispatcher.transferFrom(sender, pair, amountB);
        let pairDispatcher = IPairDispatcher { contract_address: pair };
        let liquidity = pairDispatcher.mint(to);
        (amountA, amountB, liquidity)
    }

    // @notice Remove liquidity from a pool
    // @dev `caller` should have already given the router an allowance of at least liquidity on the pool
    // @param tokenA Address of tokenA
    // @param tokenB Address of tokenB
    // @param tokenB Address of tokenB
    // @param liquidity The amount of liquidity tokens to remove
    // @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert
    // @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert
    // @param to Recipient of the underlying tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amountA The amount of tokenA received
    // @return amountB The amount of tokenA received
    #[external]
    fn remove_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        liquidity: u256,
        amountAMin: u256,
        amountBMin: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256) {
        _ensure_deadline(deadline);
        let pair = _pair_for(tokenA, tokenB);
        let sender = get_caller_address();
        let pairERC20Dispatcher = IERC20Dispatcher { contract_address: pair };
        pairERC20Dispatcher.transferFrom(sender, pair, liquidity);
        let pairDispatcher = IPairDispatcher { contract_address: pair };
        let (amount0, amount1) = pairDispatcher.burn(to);
        let (token0, _) = _sort_tokens(tokenA, tokenB);
        let mut amountA = 0.into();
        let mut amountB = 0.into();
        if tokenA == token0 {
            amountA = amount0;
            amountB = amount1;
        } else {
            amountA = amount1;
            amountB = amount0;
        }

        assert(amountA >= amountAMin, 'insufficient A amount');
        assert(amountB >= amountBMin, 'insufficient B amount');

        (amountA, amountB)
    }

    // @notice Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path
    // @dev `caller` should have already given the router an allowance of at least amountIn on the input token
    // @param amountIn The amount of input tokens to send
    // @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert
    // @param path_len Length of path array
    // @param path Array of pair addresses through which swaps are chained
    // @param to Recipient of the output tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amounts_len Length of amounts array
    // @return amounts The input token amount and all subsequent output token amounts
    #[external]
    fn swap_exact_tokens_for_tokens(
        amountIn: u256,
        amountOutMin: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256> {
        _ensure_deadline(deadline);
        let mut amounts = _get_amounts_out(amountIn, path.span());
        assert(*amounts[amounts.len() - 1] >= amountOutMin, 'insufficient output amount');
        let pair = _pair_for(*path[0], *path[1]);
        let sender = get_caller_address();
        let pairERC20Dispatcher = IERC20Dispatcher { contract_address: *path[0] };
        pairERC20Dispatcher.transferFrom(sender, pair, *amounts[0]);
        _swap(0, path.len(), ref amounts, path.span(), to);
        amounts
    }

    // @notice Receive an exact amount of output tokens for as few input tokens as possible, along the route determined by the path
    // @dev `caller` should have already given the router an allowance of at least amountInMax on the input token
    // @param amountOut The amount of output tokens to receive
    // @param amountInMax The maximum amount of input tokens that can be required before the transaction reverts
    // @param path_len Length of path array
    // @param path Array of pair addresses through which swaps are chained
    // @param to Recipient of the output tokens
    // @param deadline Timestamp after which the transaction will revert
    // @return amounts_len Length of amounts array
    // @return amounts The input token amount and all subsequent output token amounts
    #[external]
    fn swap_tokens_for_exact_tokens(
        amountOut: u256,
        amountInMax: u256,
        path: Array::<ContractAddress>,
        to: ContractAddress,
        deadline: u64
    ) -> Array::<u256> {
        _ensure_deadline(deadline);
        let mut amounts = _get_amounts_in(amountOut, path.span());
        assert(*amounts[0] <= amountInMax, 'excessive input amount');
        let pair = _pair_for(*path[0], *path[1]);
        let sender = get_caller_address();
        let pairERC20Dispatcher = IERC20Dispatcher { contract_address: *path[0] };
        pairERC20Dispatcher.transferFrom(sender, pair, *amounts[0]);
        _swap(0, path.len(), ref amounts, path.span(), to);
        amounts
    }

    // @notice This is an intermediate state to finalize upgrade to non-upgradable Factory Cairo 1.0
    // @dev Only Proxy_admin can call
    // @param new_implementation_class New implementation hash
    #[external]
    fn replace_implementation_class(new_implementation_class: ClassHash) {
        let sender = get_caller_address();
        let proxy_admin = Proxy_admin::read();
        assert(sender == proxy_admin, 'must be admin');
        assert(!new_implementation_class.is_zero(), 'must be non zero');
        replace_class_syscall(new_implementation_class);
    }

    //
    // Internals
    //

    fn _ensure_deadline(deadline: u64) {
        let block_timestamp = get_block_timestamp();
        assert(deadline >= block_timestamp, 'expired');
    }

    fn _add_liquidity(
        tokenA: ContractAddress,
        tokenB: ContractAddress,
        amountADesired: u256,
        amountBDesired: u256,
        amountAMin: u256,
        amountBMin: u256,
    ) -> (u256, u256) {
        let factory = _factory::read();
        let factoryDispatcher = IFactoryDispatcher { contract_address: factory };
        let pair = factoryDispatcher.get_pair(tokenA, tokenB);

        if (pair == contract_address_const::<0>()) {
            factoryDispatcher.create_pair(tokenA, tokenB);
        }

        let (reserveA, reserveB) = _get_reserves(tokenA, tokenB);

        if (reserveA == 0.into() & reserveB == 0.into()) {
            return (amountADesired, amountBDesired);
        } else {
            let amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if amountBOptimal <= amountBDesired {
                assert(amountBOptimal >= amountBMin, 'insufficient B amount');
                return (amountADesired, amountBOptimal);
            } else {
                let amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired, '');
                assert(amountAOptimal >= amountAMin, 'insufficient A amount');
                return (amountAOptimal, amountBDesired);
            }
        }
    }

    fn _swap(
        current_index: u32,
        amounts_len: u32,
        ref amounts: Array::<u256>,
        path: Span::<ContractAddress>,
        _to: ContractAddress
    ) {
        let factory = _factory::read();
        if (current_index == amounts_len - 1) {
            return ();
        }
        let (token0, _) = _sort_tokens(*path[current_index], *path[current_index + 1]);
        let mut amount0Out = 0.into();
        let mut amount1Out = 0.into();
        if (*path[current_index] == token0) {
            amount1Out = *amounts[current_index + 1];
        } else {
            amount0Out = *amounts[current_index + 1];
        }
        let mut to: ContractAddress = _to;
        if (current_index < (amounts_len
            - 2)) {
                to = _pair_for(*path[current_index + 1], *path[current_index + 2]);
            }
        let pair = _pair_for(*path[current_index], *path[current_index + 1]);
        let data = ArrayTrait::<felt252>::new();
        let pairDispatcher = IPairDispatcher { contract_address: pair };
        pairDispatcher.swap(amount0Out, amount1Out, to, data);
    // return _swap(current_index + 1, amounts_len, ref amounts, path, _to);   // TODO solve compilation  
    }

    fn _sort_tokens(
        tokenA: ContractAddress, tokenB: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        assert(tokenA != tokenB, 'must not be identical');
        let mut token0: ContractAddress = contract_address_const::<0>();
        let mut token1: ContractAddress = contract_address_const::<0>();
        if u256_from_felt252(
            contract_address_to_felt252(tokenA)
        ) < u256_from_felt252(
            contract_address_to_felt252(tokenB)
        ) { // TODO token comparison directly
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }

        assert(!token0.is_zero(), 'must be non zero');
        (token0, token1)
    }

    fn _pair_for(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {
        let (token0, token1) = _sort_tokens(tokenA, tokenB);
        let factory = _factory::read();
        let factoryDispatcher = IFactoryDispatcher { contract_address: factory };
        let pair = factoryDispatcher.get_pair(token0, token1);
        pair
    }

    fn _get_reserves(tokenA: ContractAddress, tokenB: ContractAddress) -> (u256, u256) {
        let (token0, _) = _sort_tokens(tokenA, tokenB);
        let pair = _pair_for(tokenA, tokenB);
        let pairDispatcher = IPairDispatcher { contract_address: pair };
        let (reserve0, reserve1, _) = pairDispatcher.get_reserves();
        if (tokenA == token0) {
            return (reserve0, reserve1);
        } else {
            return (reserve1, reserve0);
        }
    }

    //
    // Internals LIBRARY
    //

    fn _quote(amountA: u256, reserveA: u256, reserveB: u256) -> u256 {
        assert(amountA > 0.into(), 'insufficient amount');
        assert(reserveA > 0.into() & reserveB > 0.into(), 'insufficient liquidity');

        let amountB = (amountA * reserveB) / reserveA;
        amountB
    }

    fn _get_amount_out(amountIn: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        assert(amountIn > 0.into(), 'insufficient input amount');
        assert(reserveIn > 0.into() & reserveOut > 0.into(), 'insufficient liquidity');

        let amountIn_with_fee = amountIn * 997.into();
        let numerator = amountIn_with_fee * reserveOut;
        let denominator = (reserveIn * 1000.into()) + amountIn_with_fee;

        numerator / denominator
    }

    fn _get_amount_in(amountOut: u256, reserveIn: u256, reserveOut: u256) -> u256 {
        assert(amountOut > 0.into(), 'insufficient output amount');
        assert(reserveIn > 0.into() & reserveOut > 0.into(), 'insufficient liquidity');

        let numerator = reserveIn * amountOut * 1000.into();
        let denominator = (reserveOut - amountOut) * 997.into();

        (numerator / denominator) + 1.into()
    }

    fn _get_amounts_out(amountIn: u256, path: Span::<ContractAddress>) -> Array::<u256> {
        assert(path.len() >= 2, 'invalid path');
        let mut amounts = ArrayTrait::<u256>::new();
        amounts.append(amountIn);
        let mut current_index = 0;
        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut err_data = array::array_new();
                    array::array_append(ref err_data, 'Out of gas');
                    panic(err_data)
                },
            }
            if (current_index == path.len() - 1) {
                break true;
            }
            let (reserveIn, reserveOut) = _get_reserves(
                *path[current_index], *path[current_index + 1]
            );
            amounts.append(_get_amount_out(*amounts[current_index], reserveIn, reserveOut));
            current_index += 1;
        };
        amounts
    }

    fn _get_amounts_in(amountOut: u256, path: Span::<ContractAddress>) -> Array::<u256> {
        assert(path.len() >= 2, 'invalid path');
        let mut amounts = ArrayTrait::<u256>::new();
        amounts.append(amountOut);
        let mut current_index = path.len() - 1;
        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut err_data = array::array_new();
                    array::array_append(ref err_data, 'Out of gas');
                    panic(err_data)
                },
            }
            if (current_index == 0) {
                break true;
            }
            let (reserveIn, reserveOut) = _get_reserves(
                *path[current_index - 1], *path[current_index]
            );
            amounts.append(
                _get_amount_in(*amounts[path.len() - current_index], reserveIn, reserveOut)
            );
            current_index -= 1;
        };
        let mut final_amounts = ArrayTrait::<u256>::new();
        current_index = 0;
        loop { // reversing array, TODO remove when set comes.
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut err_data = array::array_new();
                    array::array_append(ref err_data, 'Out of gas');
                    panic(err_data)
                },
            }
            if (current_index == amounts.len()) {
                break true;
            }
            final_amounts.append(*amounts[amounts.len() - 1 - current_index]);
            current_index += 1;
        };
        final_amounts
    }
}
