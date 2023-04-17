// @title JediSwap Pair Cairo 1.0
// @author Mesh Finance
// @license MIT
// @notice Low level pair contract
// @dev Based on the Uniswap V2 pair
//      https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol
//      Also an ERC20 token

#[contract]
mod PairC1 {
    use JediSwap::utils::erc20::ERC20;
    use traits::Into;
    use option::OptionTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use integer::u128_try_from_felt252;
    use integer::u128_sqrt; // TODO change all to native u256 sqrt when available


    //
    // Interfaces
    //
    #[abi]
    trait IERC20 {
        fn balanceOf(account: ContractAddress) -> u256; // TODO which balanceOf
        fn transfer(recipient: ContractAddress, amount: u256) -> bool;
        fn transferFrom(
            sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool; // TODO which transferFrom
    }

    #[abi]
    trait IFactory {
        fn get_fee_to() -> ContractAddress;
    }

    #[abi]
    trait IJediSwapCallee {
        fn jediswap_call(
            sender: ContractAddress, amount0Out: u256, amount1Out: u256, data: Array::<felt252>
        );
    }

    //
    // Storage Pair
    //

    struct Storage {
        _token0: ContractAddress, // @dev token0 address
        _token1: ContractAddress, // @dev token1 address
        _reserve0: u256, // @dev reserve for token0
        _reserve1: u256, // @dev reserve for token1
        _block_timestamp_last: u64, // @dev block timestamp for last update
        _price_0_cumulative_last: u256, // @dev cumulative price for token0 on last update
        _price_1_cumulative_last: u256, // @dev cumulative price for token1 on last update
        _klast: u256, // @dev reserve0 * reserve1, as of immediately after the most recent liquidity event
        _locked: bool, // @dev Boolean to check reentrancy
        _factory: ContractAddress, // @dev Factory contract address
    }

    // @notice An event emitted whenever mint() is called.
    #[event]
    fn Mint(sender: ContractAddress, amount0: u256, amount1: u256) {}

    // @notice An event emitted whenever burn() is called.
    #[event]
    fn Burn(sender: ContractAddress, amount0: u256, amount1: u256, to: ContractAddress) {}

    // @notice An event emitted whenever swap() is called.
    #[event]
    fn Swap(
        sender: ContractAddress,
        amount0In: u256,
        amount1In: u256,
        amount0Out: u256,
        amount1Out: u256,
        to: ContractAddress,
    ) {}

    // @notice An event emitted whenever _update() is called.
    #[event]
    fn Sync(reserve0: u256, reserve1: u256) {}

    //
    // Constructor
    //

    // @notice Contract constructor
    // @param name Name of the pair token
    // @param symbol Symbol of the pair token
    // @param token0 Address of token0
    // @param token1 Address of token1
    #[external]
    fn initializer(token0: ContractAddress, token1: ContractAddress, proxy_admin: ContractAddress) {
        assert(!token0.is_zero() & !token1.is_zero(), 'must be non zero');
        ERC20::initializer('JediSwap Pair', 'JEDI-P'); //TODO ERC20 integration
        _locked::write(false);
        _token0::write(token0);
        _token1::write(token1);
        let factory = get_caller_address();
        _factory::write(factory);
    // Proxy.initializer(proxy_admin); //TODO proxy integration
    }

    //
    // Getters ERC20
    //

    // @notice Name of the token
    // @return name
    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    // @notice Symbol of the token
    // @return symbol
    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    // @notice Total Supply of the token
    // @return totalSupply
    #[view]
    fn totalSupply() -> u256 { //TODO total_supply ?
        ERC20::total_supply()
    }

    // @notice Decimals of the token
    // @return decimals
    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    // @notice Balance of `account`
    // @param account Account address whose balance is fetched
    // @return balance Balance of `account`
    #[view]
    fn balanceOf(account: ContractAddress) -> u256 { //TODO balance_of ?
        ERC20::balance_of(account)
    }

    // @notice Allowance which `spender` can spend on behalf of `owner`
    // @param owner Account address whose tokens are spent
    // @param spender Account address which can spend the tokens
    // @return remaining
    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    //
    // Getters Pair
    //

    // @notice token0 address
    // @return address
    #[view]
    fn token0() -> ContractAddress {
        _token0::read()
    }

    // @notice token1 address
    // @return address
    #[view]
    fn token1() -> ContractAddress {
        _token1::read()
    }

    // @notice Current reserves for tokens in the pair
    // @return reserve0 reserve for token0
    // @return reserve1 reserve for token1
    // @return block_timestamp_last block timestamp for last update
    #[view]
    fn get_reserves() -> (u256, u256, u64) {
        _get_reserves()
    }

    // @notice cumulative price for token0 on last update
    // @return res
    #[view]
    fn price_0_cumulative_last() -> u256 {
        _price_0_cumulative_last::read()
    }

    // @notice cumulative price for token1 on last update
    // @return res
    #[view]
    fn price_1_cumulative_last() -> u256 {
        _price_1_cumulative_last::read()
    }

    // @notice reserve0 * reserve1, as of immediately after the most recent liquidity event
    // @return res
    #[view]
    fn klast() -> u256 {
        _klast::read()
    }

    //
    // Externals ERC20
    //

    // @notice Transfer `amount` tokens from `caller` to `recipient`
    // @param recipient Account address to which tokens are transferred
    // @param amount Amount of tokens to transfer
    // @return success 0 or 1
    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount);
        true
    }

    // @notice Transfer `amount` tokens from `sender` to `recipient`
    // @dev Checks for allowance.
    // @param sender Account address from which tokens are transferred
    // @param recipient Account address to which tokens are transferred
    // @param amount Amount of tokens to transfer
    // @return success 0 or 1
    #[external]
    fn transferFrom(
        sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool { //TODO transfer_from ?
        ERC20::transfer_from(sender, recipient, amount);
        true
    }

    // @notice Approve `spender` to transfer `amount` tokens on behalf of `caller`
    // @param spender The address which will spend the funds
    // @param amount The amount of tokens to be spent
    // @return success 0 or 1
    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount);
        true
    }

    // @notice Increase allowance of `spender` to transfer `added_value` more tokens on behalf of `caller`
    // @param spender The address which will spend the funds
    // @param added_value The increased amount of tokens to be spent
    // @return success 0 or 1
    #[external]
    fn increaseAllowance(
        spender: ContractAddress, added_value: u256
    ) -> bool { //TODO increase_allowance ?
        ERC20::increase_allowance(spender, added_value);
        true
    }

    // @notice Decrease allowance of `spender` to transfer `subtracted_value` less tokens on behalf of `caller`
    // @param spender The address which will spend the funds
    // @param subtracted_value The decreased amount of tokens to be spent
    // @return success 0 or 1
    #[external]
    fn decreaseAllowance(
        spender: ContractAddress, subtracted_value: u256
    ) -> bool { //TODO decrease_allowance ?
        ERC20::decrease_allowance(spender, subtracted_value);
        true
    }

    //
    // Externals Pair
    //

    // @notice Mint tokens and assign them to `to`
    // @dev This low-level function should be called from a contract which performs important safety checks
    // @param to The account that will receive the created tokens
    // @return liquidity New tokens created
    #[external]
    fn mint(to: ContractAddress) -> u256 {
        _check_and_lock();
        let (reserve0, reserve1, _) = _get_reserves();
        let self_address = get_contract_address();
        let token0 = _token0::read();
        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let balance0 = token0Dispatcher.balanceOf(self_address);
        let token1 = _token1::read();
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };
        let balance1 = token1Dispatcher.balanceOf(self_address);
        let amount0 = balance0 - reserve0;
        let amount1 = balance1 - reserve1;
        let fee_on = _mint_protocol_fee(reserve0, reserve1);
        let _total_supply = totalSupply();
        let mut liquidity = 0.into();
        if (_total_supply == 0.into()) {
            liquidity = u256 { low: u128_sqrt(((amount0 * amount1) - 1000.into()).low), high: 0 };
            ERC20::_mint(contract_address_const::<1>(), 1000.into());
        } else {
            let liquidity0 = (amount0 * _total_supply) / reserve0;
            let liquidity1 = (amount1 * _total_supply) / reserve1;
            if liquidity0 < liquidity1 {
                liquidity = liquidity0;
            } else {
                liquidity = liquidity1;
            }
        }

        assert(liquidity > 0.into(), 'insufficient liquidity minted');

        ERC20::_mint(to, liquidity);

        _update(balance0, balance1, reserve0, reserve1);

        if (fee_on) {
            let klast = balance0 * balance1;
            _klast::write(klast);
        }

        Mint(
            get_caller_address(), amount0, amount1
        ); // TODO?? sender address instead of caller address

        _unlock();
        liquidity
    }

    // @notice Burn tokens belonging to `to`
    // @dev This low-level function should be called from a contract which performs important safety checks
    // @param to The account that will receive the created tokens
    // @return amount0 Amount of token0 received
    // @return amount1 Amount of token1 received
    #[external]
    fn burn(to: ContractAddress) -> (u256, u256) {
        _check_and_lock();
        let (reserve0, reserve1, _) = _get_reserves();
        let self_address = get_contract_address();
        let token0 = _token0::read();
        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let mut balance0 = token0Dispatcher.balanceOf(self_address);
        let token1 = _token1::read();
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };
        let mut balance1 = token1Dispatcher.balanceOf(self_address);
        let liquidity = balanceOf(self_address);
        let fee_on = _mint_protocol_fee(reserve0, reserve1);
        let _total_supply = totalSupply();

        let amount0 = (liquidity * balance0) / _total_supply;
        let amount1 = (liquidity * balance1) / _total_supply;
        assert(amount0 > 0.into() & amount1 > 0.into(), 'insufficient liquidity burned');

        ERC20::_burn(self_address, liquidity);

        token0Dispatcher.transfer(to, amount0);
        token1Dispatcher.transfer(to, amount1);

        balance0 = token0Dispatcher.balanceOf(self_address);
        balance1 = token1Dispatcher.balanceOf(self_address);

        _update(balance0, balance1, reserve0, reserve1);

        if (fee_on) {
            let klast = balance0 * balance1;
            _klast::write(klast);
        }

        Burn(get_caller_address(), amount0, amount1, to);

        _unlock();
        (amount0, amount1)
    }

    // @notice Swaps from one token to another
    // @dev This low-level function should be called from a contract which performs important safety checks
    // @param amount0Out Amount of token0 received
    // @param amount1Out Amount of token1 received
    // @param to The account that will receive the tokens
    #[external]
    fn swap(amount0Out: u256, amount1Out: u256, to: ContractAddress, data: Array::<felt252>) {
        _check_and_lock();
        assert(amount0Out > 0.into() | amount1Out > 0.into(), 'insufficient output amount');

        let (reserve0, reserve1, _) = _get_reserves();
        assert(amount0Out < reserve0 & amount1Out < reserve1, 'insufficient liquidity');

        let token0 = _token0::read();
        let token1 = _token1::read();
        assert(to != token0 & to != token1, 'invalid to');

        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };

        if (amount0Out > 0.into()) {
            token0Dispatcher.transfer(to, amount0Out);
        }

        if (amount1Out > 0.into()) {
            token1Dispatcher.transfer(to, amount1Out);
        }

        if (data.len() > 0) {
            let JediSwapCalleeDispatcher = IJediSwapCalleeDispatcher { contract_address: to };
            JediSwapCalleeDispatcher.jediswap_call(
                get_caller_address(), amount0Out, amount1Out, data
            );
        }

        let self_address = get_contract_address();
        let balance0 = token0Dispatcher.balanceOf(self_address);
        let balance1 = token1Dispatcher.balanceOf(self_address);

        let mut amount0In = 0.into();

        if (balance0 > (reserve0 - amount0Out)) {
            amount0In = balance0 - (reserve0 - amount0Out);
        }

        let mut amount1In = 0.into();

        if (balance1 > (reserve1 - amount1Out)) {
            amount1In = balance1 - (reserve1 - amount1Out);
        }

        assert(amount0In > 0.into() | amount1In > 0.into(), 'insufficient input amount');

        let balance0Adjusted = (balance0 * 1000.into()) - (amount0In * 3.into());
        let balance1Adjusted = (balance1 * 1000.into()) - (amount1In * 3.into());

        assert(
            balance0Adjusted * balance1Adjusted > reserve0 * reserve1 * 1000000.into(),
            'invariant K'
        );

        _update(balance0, balance1, reserve0, reserve1);

        Swap(get_caller_address(), amount0In, amount1In, amount0Out, amount1Out, to);

        _unlock();
    }

    // @notice force balances to match reserves
    // @param to The account that will receive the balance tokens
    #[external]
    fn skim(to: ContractAddress) {
        _check_and_lock();
        let (reserve0, reserve1, _) = _get_reserves();

        let self_address = get_contract_address();
        let token0 = _token0::read();
        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let balance0 = token0Dispatcher.balanceOf(self_address);
        let token1 = _token1::read();
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };
        let balance1 = token1Dispatcher.balanceOf(self_address);

        token0Dispatcher.transfer(to, balance0 - reserve0);
        token1Dispatcher.transfer(to, balance1 - reserve1);

        _unlock();
    }

    // @notice Force reserves to match balances
    #[external]
    fn sync() {
        _check_and_lock();

        let self_address = get_contract_address();
        let token0 = _token0::read();
        let token0Dispatcher = IERC20Dispatcher { contract_address: token0 };
        let balance0 = token0Dispatcher.balanceOf(self_address);
        let token1 = _token1::read();
        let token1Dispatcher = IERC20Dispatcher { contract_address: token1 };
        let balance1 = token1Dispatcher.balanceOf(self_address);

        let (reserve0, reserve1, _) = _get_reserves();

        _update(balance0, balance1, reserve0, reserve1);

        _unlock();
    }

    //
    // Internals Pair
    //

    // @dev Check if the entry is not locked, and lock it
    fn _check_and_lock() {
        let locked = _locked::read();
        assert(!locked, 'locked');
        _locked::write(true);
    }

    // @dev Unlock the entry
    fn _unlock() {
        let locked = _locked::read();
        assert(locked, 'not locked');
        _locked::write(false);
    }

    // @dev If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    fn _mint_protocol_fee(reserve0: u256, reserve1: u256) -> bool {
        let factory = _factory::read();
        let factoryDispatcher = IFactoryDispatcher { contract_address: factory };
        let fee_to = factoryDispatcher.get_fee_to();
        let fee_on = (fee_to != contract_address_const::<0>());

        let klast = _klast::read();

        if (fee_on) {
            if (klast != 0.into()) {
                let rootk = 0.into();
                let rootklast = 0.into();
                if (rootk > rootklast) {
                    let numerator = totalSupply() * (rootk - rootklast);
                    let denominator = (rootk * 5.into()) + rootklast;
                    let liquidity = numerator / denominator;
                    if (liquidity > 0.into()) {
                        ERC20::_mint(fee_to, liquidity);
                    }
                }
            }
        } else {
            if (klast != 0.into()) {
                _klast::write(0.into());
            }
        }
        fee_on
    }

    fn _get_reserves() -> (u256, u256, u64) {
        (_reserve0::read(), _reserve1::read(), _block_timestamp_last::read())
    }

    // @dev Update reserves and, on the first call per block, price accumulators
    fn _update(balance0: u256, balance1: u256, reserve0: u256, reserve1: u256) {
        assert(balance0.high == 0 & balance1.high == 0, 'overflow');
        let block_timestamp = get_block_timestamp();
        let block_timestamp_last = _block_timestamp_last::read();
        let time_elapsed = block_timestamp - block_timestamp_last;
        let (reserve0, reserve1, _) = _get_reserves();
        if (time_elapsed > 0 & reserve0 != 0.into() & reserve1 != 0.into()) {
            let mut price_0_cumulative_last = _price_0_cumulative_last::read();
            let mut price_1_cumulative_last = _price_1_cumulative_last::read();
            price_0_cumulative_last += (reserve1 / reserve0) * u256 {
                low: u128_try_from_felt252(time_elapsed.into()).unwrap(), high: 0
            }; // TODO official support for casting to u256
            price_1_cumulative_last += (reserve0 / reserve1) * u256 {
                low: u128_try_from_felt252(time_elapsed.into()).unwrap(), high: 0
            }; // TODO official support for casting to u256
            _price_0_cumulative_last::write(price_0_cumulative_last);
            _price_1_cumulative_last::write(price_1_cumulative_last);
        }

        _reserve0::write(balance0);
        _reserve1::write(balance1);
        _block_timestamp_last::write(block_timestamp);

        Sync(balance0, balance1);
    }
}
