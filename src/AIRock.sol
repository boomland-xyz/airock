//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC404} from "./ERC404.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract AIRock is ERC404, ReentrancyGuard {
    using Address for address payable;

    address payable public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public buyableSupply;

    event SetProtocolFeeDestination(address indexed destination);
    event SetProtocolFeePercent(uint256 percent);
    event Trade(
        address indexed trader,
        bool indexed isBuy,
        uint256 amount,
        uint256 price,
        uint256 protocolFee,
        uint256 supply
    );

    constructor(
        address payable _protocolFeeDestination,
        uint256 _protocolFeePercent
    ) ERC404("AI Rock", "ROCK", 18, 10_000, address(this)) {
        balanceOf[address(this)] = totalSupply;
        setWhitelist(address(this), true);

        protocolFeeDestination = _protocolFeeDestination;
        protocolFeePercent = _protocolFeePercent;

        emit SetProtocolFeeDestination(_protocolFeeDestination);
        emit SetProtocolFeePercent(_protocolFeePercent);
    }

    function setProtocolFeeDestination(address payable _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
        emit SetProtocolFeeDestination(_feeDestination);
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
        emit SetProtocolFeePercent(_feePercent);
    }

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return string.concat("https://airock.xyz/token/", Strings.toString(id));
    }

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 startPriceWei = (1e15 + (supply) * 1e15);
        uint256 endPriceWei = (1e15 + (supply + amount - 1) * 1e15);
        uint256 totalCostWei = ((startPriceWei + endPriceWei) / 2) * amount;
        return totalCostWei;
    }

    function getBuyPrice(uint256 amount) public view returns (uint256) {
        return getPrice(buyableSupply, amount);
    }

    function getSellPrice(uint256 amount) public view returns (uint256) {
        return getPrice(buyableSupply - amount, amount);
    }

    function getBuyPriceAfterFee(uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        return price + protocolFee;
    }

    function getSellPriceAfterFee(uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        return price - protocolFee;
    }

    function buy(uint256 amount) public payable nonReentrant {
        uint256 price = getBuyPrice(amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;

        require(msg.value >= price + protocolFee, "Insufficient payment");

        _transfer(address(this), msg.sender, amount);
        buyableSupply += amount;

        protocolFeeDestination.sendValue(protocolFee);
        if (msg.value > price + protocolFee) {
            uint256 refund = msg.value - price - protocolFee;
            payable(msg.sender).sendValue(refund);
        }

        emit Trade(msg.sender, true, amount, price, protocolFee, buyableSupply);
    }

    function sell(uint256 amount) public {
        uint256 price = getSellPrice(amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;

        _transfer(msg.sender, address(this), amount);
        buyableSupply -= amount;

        uint256 netAmount = price - protocolFee;
        payable(msg.sender).sendValue(netAmount);
        protocolFeeDestination.sendValue(protocolFee);

        emit Trade(msg.sender, false, amount, price, protocolFee, buyableSupply);
    }
}
