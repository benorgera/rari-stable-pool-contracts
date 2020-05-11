/**
 * @file
 * @author David Lucid <david@rari.capital>
 *
 * @section LICENSE
 *
 * All rights reserved to David Lucid of David Lucid LLC.
 * Any disclosure, reproduction, distribution or other use of this code by any individual or entity other than David Lucid of David Lucid LLC, unless given explicit permission by David Lucid of David Lucid LLC, is prohibited.
 *
 * @section DESCRIPTION
 *
 * This file includes the Ethereum contract code for DydxPoolController, a library handling deposits to and withdrawals from dYdX liquidity pools.
 */

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../external/dydx/SoloMargin.sol";
import "../../external/dydx/lib/Account.sol";
import "../../external/dydx/lib/Actions.sol";
import "../../external/dydx/lib/Types.sol";

/**
 * @title DydxPoolController
 * @dev This library handles deposits to and withdrawals from dYdX liquidity pools.
 */
library DydxPoolController {
    using SafeMath for uint256;

    address constant private SOLO_MARGIN_CONTRACT = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    SoloMargin constant private _soloMargin = SoloMargin(DYDX_SOLO_MARGIN_CONTRACT);

    /**
     * @dev Returns a token's dYdX market ID given its ERC20 contract address.
     * @param erc20Contract The ERC20 contract address of the token.
     */
    function getMarketId(address erc20Contract) private pure returns (uint256) {
        if (erc20Contract == 0x6B175474E89094C44Da98b954EedeAC495271d0F) return 3; // DAI
        else revert("Supported dYdX market not found for this token address.");
    }

    /**
     * @dev Retrieves the calling address's balance of the specified currency in the dYdX pool.
     * @param erc20Contract The ERC20 contract address of the token.
     */
    function getBalance(address erc20Contract) internal view returns (uint256) {
        uint256 marketId = getMarketId(erc20Contract); // TODO: Make sure this reverts if an invalid address is supplied

        Account.Info memory account = Account.Info(address(this), 0);

        address[] memory tokens;
        Types.Par[] memory pars;
        Types.Wei[] memory weis;

        (tokens, pars, weis) = _soloMargin.getAccountBalances(account);

        return weis[marketId].value;
    }

    /**
     * @dev Deposits funds to the dYdX pool.
     * @param erc20Contract The ERC20 contract address of the token to be deposited.
     * @param amount The amount of tokens to be deposited.
     */
    function deposit(address erc20Contract, uint256 amount) internal returns (bool) {
        uint256 marketId = getMarketId(erc20Contract); // TODO: Make sure this reverts if an invalid address is supplied

        ERC20 underlying = ERC20(erc20Contract);
        require(underlying.approve(_dydxContract, amount), "Approval of tokens failed."); // TODO: Execute infinite approval once instead of approving every time we deposit so we don't waste gas?

        Account.Info memory account = Account.Info(address(this), 0);
        Account.Info[] memory accounts = new Account.Info[](1);
        accounts[0] = account;

        Types.AssetAmount memory assetAmount = Types.AssetAmount(true, Types.AssetDenomination.Wei, Types.AssetReference.Delta, amount);
        bytes memory emptyData;

        Actions.ActionArgs memory action = Actions.ActionArgs(
            Actions.ActionType.Deposit,
            0,
            assetAmount,
            marketId,
            0,
            address(this),
            0,
            emptyData
        );

        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
        actions[0] = action;

        _soloMargin.operate(accounts, actions);

        return true;
    }

    /**
     * @dev Withdraws funds from the dYdX pool.
     * @param erc20Contract The ERC20 contract address of the token to be withdrawn.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(address erc20Contract, uint256 amount) internal returns (bool) {
        uint256 marketId = getMarketId(erc20Contract); // TODO: Make sure this reverts if an invalid address is supplied

        Account.Info memory account = Account.Info(address(this), 0);
        Account.Info[] memory accounts = new Account.Info[](1);
        accounts[0] = account;

        Types.AssetAmount memory assetAmount = Types.AssetAmount(false, Types.AssetDenomination.Wei, Types.AssetReference.Delta, amount);
        bytes memory emptyData;

        Actions.ActionArgs memory action = Actions.ActionArgs(
            Actions.ActionType.Withdraw,
            0,
            assetAmount,
            marketId,
            0,
            address(this),
            0,
            emptyData
        );

        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
        actions[0] = action;

        _soloMargin.operate(accounts, actions);

        return true;
    }

    /**
     * @dev Withdraws all funds from the dYdX pool.
     * @param erc20Contract The ERC20 contract address of the token to be withdrawn.
     */
    function withdrawAll(address erc20Contract) internal returns (bool) {
        uint256 marketId = getMarketId(erc20Contract); // TODO: Make sure this reverts if an invalid address is supplied

        Account.Info memory account = Account.Info(address(this), 0);
        Account.Info[] memory accounts = new Account.Info[](1);
        accounts[0] = account;

        Types.AssetAmount memory assetAmount = Types.AssetAmount(true, Types.AssetDenomination.Par, Types.AssetReference.Target, 0);
        bytes memory emptyData;

        Actions.ActionArgs memory action = Actions.ActionArgs(
            Actions.ActionType.Withdraw,
            0,
            assetAmount,
            marketId,
            0,
            address(this),
            0,
            emptyData
        );

        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);
        actions[0] = action;

        _soloMargin.operate(accounts, actions);

        return true;
    }
}