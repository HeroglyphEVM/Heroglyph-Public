// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

contract MockERC20ABI is Test {
  string private constant SIG_BALANCE_OF = "balanceOf(address)";
  string private constant SIG_MINT = "mint(address,uint256)";
  string private constant SIG_BURN = "burn(address,uint256)";
  string private constant SIG_NAME = "name()";
  string private constant SIG_SYMBOL = "symbol()";
  string private constant SIG_DECIMALS = "decimals()";
  string private constant SIG_TOTAL_SUPPLY = "totalSupply()";
  string private constant SIG_ALLOWANCE = "allowance(address,address)";
  string private constant SIG_APPROVE = "approve(address,uint256)";
  string private constant SIG_TRANSFER = "transfer(address,uint256)";
  string private constant SIG_TRANSFER_FROM = "transferFrom(address,address,uint256)";
  string private constant SIG_INCREASE_ALLOWANCE = "increaseAllowance(address,uint256)";
  string private constant SIG_DECREASE_ALLOWANCE = "decreaseAllowance(address,uint256)";

  function mockBalance(address _token, address _of, uint256 _amount) internal {
    vm.mockCall(_token, abi.encodeWithSignature(SIG_BALANCE_OF, _of), abi.encode(_amount));
  }

  function expectMint(address _token, address _of, uint256 _amount) internal {
    vm.expectCall(_token, abi.encodeWithSignature(SIG_MINT, _of, _amount));
  }

  function expectBurn(address _token, address _from, uint256 _amount) internal {
    vm.expectCall(_token, abi.encodeWithSignature(SIG_BURN, _from, _amount));
  }

  function mockName(address _token, string memory _name) internal {
    vm.mockCall(_token, abi.encodeWithSignature(SIG_NAME), abi.encode(_name));
  }

  function mockDecimals(address _token, uint8 _decimals) internal {
    vm.mockCall(_token, abi.encodeWithSignature(SIG_DECIMALS), abi.encode(_decimals));
  }

  function mockTotalSupply(address _token, uint256 _totalSupply) internal {
    vm.mockCall(
      _token, abi.encodeWithSignature(SIG_TOTAL_SUPPLY), abi.encode(_totalSupply)
    );
  }

  function mockAllowance(
    address _token,
    address _of,
    address _spender,
    uint256 _allowance
  ) internal {
    vm.mockCall(
      _token,
      abi.encodeWithSignature(SIG_ALLOWANCE, _of, _spender),
      abi.encode(_allowance)
    );
  }

  function expectApprove(address _token, address _of, uint256 _amount) internal {
    vm.expectCall(_token, abi.encodeWithSignature(SIG_APPROVE, _of, _amount));
    mockApprove(_token, _of, _amount, true);
  }

  function mockApprove(address _token, address _of, uint256 _amount, bool _result)
    internal
  {
    vm.mockCall(
      _token, abi.encodeWithSignature(SIG_APPROVE, _of, _amount), abi.encode(_result)
    );
  }

  function expectTransfer(address _token, address _to, uint256 _amount) internal {
    vm.expectCall(_token, abi.encodeWithSignature(SIG_TRANSFER, _to, _amount));
    mockTransfer(_token, _to, _amount, true);
  }

  function mockTransfer(address _token, address _to, uint256 _amount, bool _result)
    internal
  {
    vm.mockCall(
      _token, abi.encodeWithSignature(SIG_TRANSFER, _to, _amount), abi.encode(_result)
    );
  }

  function mockAnyTransfer(address _token) internal {
    vm.mockCall(_token, abi.encodeWithSignature(SIG_TRANSFER), abi.encode(true));
  }

  function expectTransferFrom(address _token, address _from, address _to, uint256 _amount)
    internal
  {
    vm.expectCall(_token, abi.encodeWithSignature(SIG_TRANSFER_FROM, _from, _to, _amount));
    mockTransferFrom(_token, _from, _to, _amount, true);
  }

  function mockTransferFrom(
    address _token,
    address _from,
    address _to,
    uint256 _amount,
    bool _result
  ) internal {
    vm.mockCall(
      _token,
      abi.encodeWithSignature(SIG_TRANSFER_FROM, _from, _to, _amount),
      abi.encode(_result)
    );
  }

  function mockAnyTransferFrom(address _token) internal {
    vm.mockCall(_token, abi.encodeWithSignature(SIG_TRANSFER_FROM), abi.encode(true));
  }
}
