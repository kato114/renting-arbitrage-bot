// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract Arbitrage is Ownable {
  address public treasury;

  function setTreasury(address _treasury) public {
    treasury = _treasury;
  }

	function estimateSimpleTrade(address router, address _tokenIn, address _tokenOut, uint256 _amount) public view returns (uint256) {
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint256[] memory amountOutMins = IUniswapV2Router(router).getAmountsOut(_amount, path);
		return amountOutMins[path.length -1];
	}

	function runSimpleTrade(address router, address _tokenIn, address _tokenOut, uint256 _amount, uint256 _minOutAmount) public {
    IERC20(_tokenIn).transferFrom(treasury, address(this), _amount);
		IERC20(_tokenIn).approve(router, _amount);

		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;

		uint deadline = block.timestamp + 300;
		
    uint256[] memory amountOutMins = IUniswapV2Router(router).swapExactTokensForTokens(_amount, _minOutAmount, path, treasury, deadline);

    require(amountOutMins[1] > _minOutAmount, "Arbitrage: Opportunity had gone away");
	}

	function estimateTriangleTrade(address router, address[] memory _path, uint256 _amount) public view returns (uint256) {
		uint256[] memory amountOutMins = IUniswapV2Router(router).getAmountsOut(_amount, _path);
		return amountOutMins[_path.length -1];
	}
  
	function runTriangleTrade(address router, address[] memory _path, uint256 _amount, uint256 _minOutAmount) public {
    require(_path.length == 3, "Arbitrage: Invalid params");

    IERC20(_path[0]).transferFrom(treasury, address(this), _amount);
		IERC20(_path[0]).approve(router, _amount);

		uint deadline = block.timestamp + 300;
		
    uint256[] memory amountOutMins = IUniswapV2Router(router).swapExactTokensForTokens(_amount, _minOutAmount, _path, treasury, deadline);
    
    require(amountOutMins[1] > _minOutAmount, "Arbitrage: Opportunity had gone away");
	}

  function estimateDualDexTrade(address[] memory _router, address[] memory _path, uint256 _amount) external view returns (uint256) {
    require(_router.length == 2 && _path.length == 2, "Arbitrage: Invalid params");

		uint256 amtBack1 = estimateSimpleTrade(_router[0], _path[0], _path[1], _amount);
		uint256 amtBack2 = estimateSimpleTrade(_router[1], _path[1], _path[0], amtBack1);
		return amtBack2;
	}
	
  function runDualTrade(address _router1, address _router2, address _token1, address _token2, uint256 _amount) external onlyOwner {
    IERC20(_token1).transferFrom(treasury, address(this), _amount);

    uint startBalance = IERC20(_token1).balanceOf(address(this));
    uint token2InitialBalance = IERC20(_token2).balanceOf(address(this));
    runSimpleTrade(_router1,_token1, _token2,_amount, 0);

    uint token2Balance = IERC20(_token2).balanceOf(address(this));
    uint tradeableAmount = token2Balance - token2InitialBalance;
    runSimpleTrade(_router2,_token2, _token1,tradeableAmount, 0);

    uint endBalance = IERC20(_token1).balanceOf(address(this));
    require(endBalance > startBalance, "Trade Reverted, No Profit Made");

    IERC20(_token1).transfer(treasury, endBalance);
  }

	function estimateTriDexTrade(address[] memory _router, address[] memory _path, uint256 _amount) external view returns (uint256) {
    require(_router.length == 3 && _path.length == 3, "Arbitrage: Invalid params");

		uint amtBack1 = estimateSimpleTrade(_router[0], _path[0], _path[1], _amount);
		uint amtBack2 = estimateSimpleTrade(_router[1], _path[1], _path[2], amtBack1);
		uint amtBack3 = estimateSimpleTrade(_router[2], _path[2], _path[0], amtBack2);
		return amtBack3;
	}
  
  function runTripleTrade(address[] memory _router, address[] memory _path, uint256 _amount) external onlyOwner {
    IERC20(_path[0]).transferFrom(treasury, address(this), _amount);
    
    uint token2InitialBalance = IERC20(_path[1]).balanceOf(address(this));
    uint token3InitialBalance = IERC20(_path[2]).balanceOf(address(this));

    uint startBalance = IERC20(_path[0]).balanceOf(address(this));
    runSimpleTrade(_router[0],_path[0], _path[1],_amount, 0);

    uint token2Balance = IERC20(_path[1]).balanceOf(address(this));
    uint tradeableAmount = token2Balance - token2InitialBalance;
    runSimpleTrade(_router[1],_path[1], _path[2],tradeableAmount, 0);

    uint token3Balance = IERC20(_path[1]).balanceOf(address(this));
    tradeableAmount = token3Balance - token3InitialBalance;
    runSimpleTrade(_router[1],_path[2], _path[0],tradeableAmount, 0);

    uint endBalance = IERC20(_path[0]).balanceOf(address(this));
    require(endBalance > startBalance, "Trade Reverted, No Profit Made");

    IERC20(_path[0]).transfer(treasury, endBalance);
  }
	
	function recoverEth() external onlyOwner {
		payable(msg.sender).transfer(address(this).balance);
	}

	function recoverTokens(address tokenAddress) external onlyOwner {
		IERC20 token = IERC20(tokenAddress);
		token.transfer(msg.sender, token.balanceOf(address(this)));
	}
}
