// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

import "ds-test/test.sol";

import "./DssProxyRegistry.sol";

// Test Contract Used
contract TestAction {
    function getBytes32() public pure returns (bytes32) {
        return bytes32("Hello");
    }

    function getBytes32AndUint() public pure returns (bytes32, uint) {
        return (bytes32("Bye"), 150);
    }

    function getMultipleValues(uint amount) public pure returns (bytes32[] memory result) {
        result = new bytes32[](amount);
        for (uint i = 0; i < amount; i++) {
            result[i] = bytes32(i);
        }
    }

    function get48Bytes() public pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
            mstore(add(result, 0x20), "AAAAAAAAAAAAAAAA")
            return(result, 0x30)
        }
    }

    function fail() public pure {
        require(false, "Fail test case");
    }
}

contract TestFullAssemblyContract {
    fallback() external {
        assembly {
            let message := mload(0x40)
            mstore(message, "Fail test case")
            revert(message, 0xe)
        }
    }
}

contract WithdrawFunds {
    function withdraw(uint256 amount) public {
        payable(msg.sender).transfer(amount);
    }
}

contract DssProxyTest is DSTest {
    DssProxy proxy;
    address action;

    function setUp() public {
        proxy = new DssProxy(address(this));
        action = address(new TestAction());
    }

    function test_execute() public {
        bytes memory response = proxy.execute(action, abi.encodeWithSignature("getBytes32()"));
        bytes32 response32;

        assembly {
            response32 := mload(add(response, 32))
        }

        assertEq32(response32, bytes32("Hello"));
    }

    function testFail_execute_not_owner() public {
        DssProxy proxy2 = new DssProxy(address(123));
        proxy2.execute(action, abi.encodeWithSignature("getBytes32()"));
    }

    function test_execute2Values() public {
        bytes memory response = proxy.execute(action, abi.encodeWithSignature("getBytes32AndUint()"));

        bytes32 response32;
        uint256 responseUint;

        assembly {
            response32 := mload(add(response, 0x20))
            responseUint := mload(add(response, 0x40))
        }

        assertEq(response32, bytes32("Bye"));
        assertEq(responseUint, uint(150));
    }

    function test_executeMultipleValues() public {
        bytes memory response = proxy.execute(action, abi.encodeWithSignature("getMultipleValues(uint256)", 10000));

        uint256 size;
        bytes32 response32;

        assembly {
            size := mload(add(response, 0x40))
        }

        assertEq(size, 10000);

        for (uint i = 0; i < size; i++) {
            assembly {
                response32 := mload(add(response, mul(32, add(i, 3))))
            }
            assertEq(response32, bytes32(i));
        }
    }

    function test_executeNot32Multiple() public {
        bytes memory response = proxy.execute(action, abi.encodeWithSignature("get48Bytes()"));

        bytes memory test = new bytes(48);
        test = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

        assertEq0(response, test);
    }

    function test_executeFailMethod() public {
        address payable target = payable(proxy);
        bytes memory data = abi.encodeWithSignature("execute(address,bytes)", action, abi.encodeWithSignature("fail()"));

        bool succeeded;
        bytes memory sig;
        bytes memory message;

        assembly {
            succeeded := call(gas(), target, 0, add(data, 0x20), mload(data), 0, 0)

            let size := returndatasize()

            let response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            size := 0x4
            sig := mload(0x40)
            mstore(sig, size)
            mstore(0x40, add(sig, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            returndatacopy(add(sig, 0x20), 0, size)

            size := mload(add(response, 0x44))
            message := mload(0x40)
            mstore(message, size)
            mstore(0x40, add(message, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            returndatacopy(add(message, 0x20), 0x44, size)
        }
        assertTrue(!succeeded);
        assertEq0(sig, abi.encodeWithSignature("Error(string)"));
        assertEq0(message, "Fail test case");
    }

    function test_executeFailMethodAssembly() public {
        address payable target = payable(proxy);
        action = address(new TestFullAssemblyContract());
        bytes memory data = abi.encodeWithSignature("execute(address,bytes)", action, hex"");

        bool succeeded;
        bytes memory response;

        assembly {
            succeeded := call(gas(), target, 0, add(data, 0x20), mload(data), 0, 0)

            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)
        }
        assertTrue(!succeeded);
        assertEq0(response, "Fail test case");
    }

    function test_depositETH() public {
        assertEq(address(proxy).balance, 0);
        (bool success,) = address(proxy).call{value: 10}("");
        assertTrue(success);
        assertEq(address(proxy).balance, 10);
    }

    function test_withdrawETH() public {
        (bool success,) = address(proxy).call{value: 10}("");
        assertTrue(success);
        assertEq(address(proxy).balance, 10);
        uint256 myBalance = address(this).balance;
        address withdrawFunds = address(new WithdrawFunds());
        proxy.execute(withdrawFunds, abi.encodeWithSignature("withdraw(uint256)", 5));
        assertEq(address(proxy).balance, 5);
        assertEq(address(this).balance, myBalance + 5);
    }

    receive() external payable {
    }
}
