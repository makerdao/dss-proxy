// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.9;

import "ds-test/test.sol";

import "./DssProxyRegistry.sol";

contract Usr {
	function transferProxy(DssProxy proxy, address dst) external {
		proxy.setOwner(dst);
	}
}

contract DssProxyTest is DSTest {
    DssProxyRegistry registry;

    function setUp() public {
        registry = new DssProxyRegistry();
    }

    function test_proxy_creation() public {
        assertEq(registry.proxies(address(this)), address(0));
        assertEq(registry.seed(address(this)), 0);
        address payable proxy = registry.build(address(this));
        assertEq(registry.seed(address(this)), 1);
        assertEq(registry.proxies(address(this)), proxy);
        assertEq(DssProxy(proxy).owner(), address(this));
    }

    function testFail_proxy_creation_existing() public {
        registry.build(address(this));
        registry.build(address(this));
    }

    function test_proxy_claim_and_creation_after_transfer() public {
		Usr usr1 = new Usr();
		Usr usr2 = new Usr();
		address payable proxyAddr = registry.build(address(usr1));
		assertTrue(proxyAddr != address(0));
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
		DssProxy proxy = DssProxy(proxyAddr);
		assertEq(proxy.owner(), address(usr1));
		
        // Registry set up correctly before transfer
        assertEq(registry.proxies(address(usr1)), proxyAddr);
        assertEq(registry.proxies(address(usr2)), address(0));

		usr1.transferProxy(proxy, address(usr2));
		assertEq(proxy.owner(), address(usr2));

		// Registry now out of date
		assertEq(registry.proxies(address(usr1)), proxyAddr);
		assertEq(registry.proxies(address(usr2)), address(0));

		registry.claim(proxyAddr, address(usr1), address(usr2));

		assertEq(proxy.owner(), address(usr2));

		// Registry now reports correctly for usr2
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(registry.proxies(address(usr1)), address(0));
		assertEq(registry.proxies(address(usr2)), proxyAddr);

		// Can build for usr1 now
		address payable newProxyAddr = registry.build(address(usr1));
		assertEq(DssProxy(newProxyAddr).owner(), address(usr1));
		assertEq(proxy.owner(), address(usr2));

		// Registry now reports correctly for usr1
        assertEq(registry.seed(address(usr1)), 2);
        assertEq(registry.seed(address(usr2)), 0);
		assertEq(payable(registry.proxies(address(usr1))), newProxyAddr);
		assertEq(registry.proxies(address(usr2)), proxyAddr);
	}

	function testFail_ClaimOwnedProxy() internal {
		Usr usr1 = new Usr();

		address payable proxyAddr = registry.build(address(usr1));
		assertTrue(proxyAddr != address(0));

		assertEq(address(registry.proxies(address(usr1))), proxyAddr);

		registry.claim(proxyAddr, address(usr1), address(123));
	}

	function testFail_ClaimOtherProxy() internal {
		Usr usr1 = new Usr();
		Usr usr2 = new Usr();

		address payable proxyAddr = registry.build(address(usr1));
		assertTrue(proxyAddr != address(0));

		assertEq(address(registry.proxies(address(usr1))), proxyAddr);

		registry.claim(proxyAddr, address(usr1), address(usr2));
	}
}
