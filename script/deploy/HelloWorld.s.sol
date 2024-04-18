// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BaseScript.sol";
import { HelloWorld } from "src/HelloWorld.sol";

contract HelloWorldScript is BaseScript {
  /**
   * @dev Converting json file to solidity struct has one important concept.
   * The parse reads the json's elements in Alphabetical order
   *
   * In our example
   * Config::owner is the first element, but in the json, it's the second.
   * But since it starts with "01_", it becomes the first element in the json after the sorting
   *
   * Tips: As the config is set, to avoid any confusion, I recommend to add a prefix XX_<NAME>
   * That way you should never have an unexpected behavior while converting from json to struct.
   */
  struct Config {
    address owner;
    uint256 exampleInt;
    string exampleString;
    address ownerTwo;
  }

  string private constant CONTRACT_NAME = "HelloWorld";

  function run(string memory _network) external {
    _setNetwork(_network);
    string memory file = _getConfig(CONTRACT_NAME);

    Config memory config =
      abi.decode(vm.parseJson(file, string.concat(".", _getNetwork())), (Config));

    // Asserts are there as an example to showcase the config is functionnal
    assert(
      keccak256(abi.encode(config.exampleString)) == keccak256(abi.encode("HelloWorld"))
    );
    assert(config.exampleInt == 102);
    assert(config.owner == address(0xADaE1798F761Fa7fce29B6673D453d1a48A2931A));
    assert(config.ownerTwo == address(0x912CE59144191C1204E64559FE8253a0e49E6548));

    _loadContracts();

    HelloWorld hello = HelloWorld(contracts[CONTRACT_NAME]);

    vm.startBroadcast(_getDeployerPrivateKey());
    {
      if (address(hello) == address(0)) {
        hello = new HelloWorld(config.owner);
        _saveDeployment(CONTRACT_NAME, address(hello));
      }
    }
    vm.stopBroadcast();
  }
}
