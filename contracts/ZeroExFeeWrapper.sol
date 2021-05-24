pragma solidity 0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/LibOrder.sol";

contract ZeroExFeeWrapper is ReentrancyGuard {
	mapping(address => bool) _owners;
	address _exchange;

	struct FeeData {
		address recipient;
		uint256 paymentTokenAmount;
	}

	constructor(address exchange)
	{
		_owners[msg.sender] = true;
		_exchange = exchange;
	}

	modifier ownerOnly()
	{
		require(_owners[msg.sender],"Owner only");
		_;
	}

	function setOwner(address owner,bool isOwner)
		public
		ownerOnly
	{
		_owners[owner] = isOwner;
	}

	function setExchange(address exchange)
		public
	{
		_exchange = exchange;
	}

	function matchOrders(
		LibOrder.Order memory leftOrder,
		LibOrder.Order memory rightOrder,
		bytes memory leftSignature,
		bytes memory rightSignature,
		FeeData[] memory feeData,
		address paymentTokenAddress
		)
		public
		payable
		reentrancyGuard
		ownerOnly
		returns (bytes memory)
	{
		bool transferFees = paymentTokenAddress != address(0x0) && feeData.length > 0;
		uint256 currentFeeBalance;
		if (transferFees) {
			require(leftOrder.feeRecipientAddress != address(0x0) || rightOrder.feeRecipientAddress != address(0x0),"Neither order has a fee recipient");
			require(leftOrder.feeRecipientAddress == address(0x0) || leftOrder.feeRecipientAddress == address(this),"leftOrder.feeRecipientAddress is not equal to the wrapper address");
			require(rightOrder.feeRecipientAddress == address(0x0) || rightOrder.feeRecipientAddress == address(this),"rightOrder.feeRecipientAddress is not equal to the wrapper address");
			currentFeeBalance = ERC20(paymentTokenAddress).balanceOf(address(this));
		}
		// bytes4 matchOrdersSig = hex"88ec79fb";
		(bool success, bytes memory result) = _exchange.call{value: msg.value}(abi.encodeWithSignature("matchOrders((address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,bytes,bytes,bytes,bytes),(address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,bytes,bytes,bytes,bytes),bytes,bytes)",leftOrder,rightOrder,leftSignature,rightSignature));
		require(success,"matchOrders failed");
		if (transferFees) {
			for (uint index = 0 ; index < feeData.length ; ++index) {
				ERC20(paymentTokenAddress).transfer(feeData[index].recipient, feeData[index].paymentTokenAmount);
			}
			require(ERC20(paymentTokenAddress).balanceOf(address(this)) == currentFeeBalance,"Did not transfer the exact payment fee amount");
		}
		return result;
	}
}