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
        assertEq(registry.getProxy(address(this)), address(0));
        assertEq(registry.seed(address(this)), 0);
        address payable proxy = registry.build(address(this));
        assertEq(registry.seed(address(this)), 1);
        assertEq(registry.getProxy(address(this)), proxy);
        assertEq(DssProxy(proxy).owner(), address(this));
    }

    function testFail_proxy_creation_existing() public {
        registry.build(address(this));
        registry.build(address(this));
    }

    function test_proxy_creation_transferred() public {
        DssProxy proxy = DssProxy(registry.build(address(this)));
        proxy.setOwner(address(123));
        registry.build(address(this));
        assertEq(registry.seed(address(this)), 2);
    }
}
