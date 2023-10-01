// contracts/OBridgeERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./utils/LogicRole.sol";
import "./interfaces/IWrappedNativeToken.sol";

contract Treasury is Ownable, LogicRole {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public native_token;

  bool public enable_status; // true: enable, false: disable

  uint256 public trade_fee; // fee amount that user need to pay for usage
  uint256 public trade_period; // period that user can trade after pay fee

  uint256 public max_profit_percent; // 1% = 100

  // detail transfer info for each token
  struct TRANSFER_INFO {
    uint256 transfer_amount;
    uint256 transfer_date;
    uint transfer_type; // 0: deposit, 1: withdrw, 3: get profit
  }

  // detail user info
  struct USER_INFO {
    bool trade_status;
    uint256 trade_start_date;

    bool register_status;
    
    mapping(address => uint256) token_amount;
    mapping(address => uint256) profit_amount;
    mapping(address => uint256) profit_got_date;
    mapping(address => TRANSFER_INFO[]) transfer_list;
  }

  mapping(address => USER_INFO) public users; // user list that use bot
  mapping(address => bool) public tokens; // token list that can be used for trading
  mapping(address => bool) public logic_contracts; // logic contract list 

  constructor(address _native_token, uint256 _trade_fee, uint256 _trade_period, uint256 _max_profit_percent) {
    native_token = _native_token;

    trade_fee = _trade_fee;
    trade_period = _trade_period;

    max_profit_percent = _max_profit_percent;
    
    enable_status = false;
  }

  modifier onlyTradable {
    require(enable_status == true, "Treasury: Trade is not available at this moment.");
    _;
  }
  
  receive() external payable {}

  function enableContract() public onlyOwner {
    require(enable_status == false, "Treasury: Trade was enabled already.");

    enable_status = true;
  }

  function disableContract() public onlyOwner {
    require(enable_status == false, "Treasury: Trade was enabled already.");

    enable_status = false;
  }

  function enableLogicContract(address _logic_contract) public onlyOwner {
    require(logic_contracts[_logic_contract] == false, "Treasury: Logic contract was enabled already.");

    logic_contracts[_logic_contract] = true;
  }
  
  function disableLogicContract(address _logic_contract) public onlyOwner {
    require(logic_contracts[_logic_contract] == true, "Treasury: Logic contract was disabled already.");

    logic_contracts[_logic_contract] = false;
  }

  function approveLogicContract(address _token_address) public onlyLogic {
    IERC20(_token_address).approve(msg.sender, 2**256 - 1);
  }

  function enableToken(address _token_address) public onlyOwner {
    require(tokens[_token_address] == false, "Treasury: Token was enabled already.");

    tokens[_token_address] = true;
  }
  
  function disableToken(address _token_address) public onlyOwner {
    require(tokens[_token_address] == true, "Treasury: Token was disabled already.");

    tokens[_token_address] = false;
  }

  function changeTradeFee(uint256 _trade_fee) public onlyOwner {
    trade_fee = _trade_fee;
  }

  function changeMaxProfitPercent(uint256 _max_profit_percent) public onlyOwner {
    max_profit_percent = _max_profit_percent;
  }
  
  function startTrade() public onlyTradable payable {
    require(msg.value == trade_fee, "Treasury: Fee must be correct amount");
    require(users[msg.sender].trade_status == false, "Treasury: Trade already started.");

    users[msg.sender].trade_status = true;
    users[msg.sender].trade_start_date = block.timestamp;
  }

  function stopTrade() public onlyTradable {
    require(users[msg.sender].trade_status == true, "Treasury: User didn't start trade yet.");

    uint256 currentTime = block.timestamp;

    users[msg.sender].trade_status = false;
    uint256 refund_fee = trade_fee.mul(currentTime.sub(users[msg.sender].trade_start_date)).div(trade_period);

    if(refund_fee > 0) payable(msg.sender).transfer(refund_fee);
  }

  function depositToken(address token_address, uint256 amount) public onlyTradable {
    require(users[msg.sender].trade_status == false, "Treasury: Trade already started.");

    IERC20(token_address).transferFrom(msg.sender, address(this), amount);

    _depositToken(token_address, amount);
  }

  function depositMultipleTokens(address[] memory token_address_list, uint256[] memory amount_list) public onlyTradable {
    require(users[msg.sender].trade_status == false, "Treasury: Trade already started.");
    require(token_address_list.length == amount_list.length, "Treasury: Invalid input data.");

    for(uint i = 0; i < token_address_list.length; i++) {
      IERC20(token_address_list[i]).transferFrom(msg.sender, address(this), amount_list[i]);

      _depositToken(token_address_list[i], amount_list[i]);
    }
  }

  function depositNativeToken() public onlyTradable payable {
    require(users[msg.sender].trade_status == false, "Treasury: Trade already started.");

    IWrappedNativeToken(native_token).deposit{value: msg.value}();
  
    _depositToken(native_token, msg.value);
  }

  function _depositToken(address token_address, uint256 amount) internal {
    require(tokens[token_address] == true, "Treasury: Token is not allowed");

    users[msg.sender].register_status = true;
    users[msg.sender].token_amount[token_address].add(amount);
    users[msg.sender].transfer_list[token_address].push(TRANSFER_INFO({
      transfer_amount: amount,
      transfer_date: block.timestamp,
      transfer_type: 0
    }));
  }

  function withdrawToken(address token_address, uint256 amount) public onlyTradable {
    require(users[msg.sender].trade_status == false, "Treasury: Disable trade first.");

    _withdrawToken(token_address, amount);

    IERC20(token_address).transfer(msg.sender, amount);
  }

  function withdrawMultipleTokens(address[] memory token_address_list, uint256[] memory amount_list) public onlyTradable {
    require(users[msg.sender].trade_status == false, "Treasury: Disable trade first.");
    require(token_address_list.length == amount_list.length, "Treasury: Invalid input data.");

    for(uint i = 0; i < token_address_list.length; i++) {
      _withdrawToken(token_address_list[i], amount_list[i]);

      IERC20(token_address_list[i]).transfer(msg.sender, amount_list[i]);
    }
  }

  function withdrawNativeToken(uint256 amount) public onlyTradable {
    require(users[msg.sender].trade_status == false, "Treasury: Disable trade first.");

    _withdrawToken(native_token, amount);

    IWrappedNativeToken(native_token).approve(native_token, amount);
    IWrappedNativeToken(native_token).withdraw(amount);
    payable(msg.sender).transfer(amount);
  }

  function _withdrawToken(address token_address, uint256 amount) internal {
    require(tokens[token_address] == true, "Treasury: Token is not allowed");
    require(users[msg.sender].token_amount[token_address] > amount, "Treasury: Balance is not enough");

    users[msg.sender].token_amount[token_address].sub(amount);
    users[msg.sender].transfer_list[token_address].push(TRANSFER_INFO({
      transfer_amount: amount,
      transfer_date: block.timestamp,
      transfer_type: 1
    }));
  }

  function withdrawProfit(address token_address) public onlyTradable {
    require(users[msg.sender].register_status == true, "Treasury: User is not registered");

    _withdrawProfit(token_address);
  }

  function withdrawMultipleProfit(address[] memory token_list) public onlyTradable {
    require(users[msg.sender].register_status == true, "Treasury: User is not registered");

    for(uint i = 0; i < token_list.length; i++) {
      _withdrawProfit(token_list[i]);
    }
  }

  function _withdrawProfit(address token_address) internal {
    uint256 currentTime = block.timestamp;

    if(users[msg.sender].profit_amount[token_address] > 0) {
      uint256 dayCount = currentTime.sub(users[msg.sender].profit_got_date[token_address]).div(86400);
      
      uint max_profit = users[msg.sender].token_amount[token_address].mul(max_profit_percent * dayCount).div(10000);

      if(max_profit > users[msg.sender].profit_amount[token_address]) {
        IERC20(token_address).transfer(msg.sender, users[msg.sender].profit_amount[token_address]);
      } else {
        IERC20(token_address).transfer(msg.sender, max_profit);
        IERC20(token_address).transfer(msg.sender, users[msg.sender].profit_amount[token_address].sub(max_profit));
      }
    }
    
    users[msg.sender].profit_amount[token_address] = 0;
    users[msg.sender].profit_got_date[token_address] = currentTime;
  }
}