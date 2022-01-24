// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

import "ds-test/test.sol";

import "./DssProxyRegistry.sol";

contract DssProxyTest is DSTest {
    DssProxyRegistry registry;

    function setUp() public {
        registry = new DssProxyRegistry();
    }

    function test_proxy_creation() public {
        address payable proxy = registry.build(address(123));
        assertEq(registry.getProxy(address(123)), proxy);
        assertEq(DssProxy(proxy).owner(), address(123));
    }

    function testFail_proxy_creation_twice() public {
        registry.build(address(123));
        registry.build(address(123));
    }
}
