// contracts/utils/LogicRole.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LogicRole is Ownable {
    mapping(address => bool) public isLogic;

    modifier onlyLogic() {
        require(isLogic[msg.sender], "OBridgeERC20: FORBIDDEN");
        _;
    }

    constructor() {
        isLogic[msg.sender] = true;
    }

    function addLogic(address _Logic) public onlyOwner {
        require(_Logic != address(0), "OBridgeERC20: Logic address can't be zero.");
        isLogic[_Logic] = true;
    }

    function removeLogic(address _Logic) public onlyOwner {
        require(isLogic[_Logic], "OBridgeERC20: The address is not Logic.");
        isLogic[_Logic] = false;
    }
}