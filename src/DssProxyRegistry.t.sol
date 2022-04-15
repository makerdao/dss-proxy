// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.13;

import "ds-test/test.sol";

import "./DssProxyRegistry.sol";

contract Usr {
    function transferProxy(DssProxy proxy, address dst) external {
        proxy.setOwner(dst);
    }

    function claimProxy(DssProxyRegistry registry, address payable proxy) external {
        registry.claim(proxy);
    }
}

contract Destruct {
    function destruct() public {
        selfdestruct(payable(msg.sender));
    }
}

contract DssProxyTest is DSTest {
    DssProxyRegistry registry;

    function setUp() public {
        registry = new DssProxyRegistry();

        // This is a workaround to test that build can be also called if the actual proxy of the user was self destructed
        // as selfdestruct is processed at the end of the tx there is not other way with hevm to test that build works after
        address payable proxyAddr = registry.build(address(this));
        DssProxy(proxyAddr).execute(address(new Destruct()), abi.encodeWithSignature("destruct()"));
    }

    function testProxyCreation() public {
        Usr usr = new Usr();

        assertEq(registry.proxies(address(usr)), address(0));
        assertEq(registry.seed(address(usr)), 0);
        address payable proxyAddr = registry.build(address(usr));
        assertEq(registry.seed(address(usr)), 1);
        assertEq(registry.proxies(address(usr)), proxyAddr);
        assertEq(DssProxy(proxyAddr).owner(), address(usr));
    }

    function testProxyCreationAfterSelfDestruct() public {
        // proxy for address(this) was selfdestructed during setup
        registry.build(address(this));
    }

    function testFailProxyCreationExisting() public {
        registry.build(address(this));
        registry.build(address(this));
    }

    function testProxyClaimAndCreationAfterTransfer() public {
        Usr usr1 = new Usr();
        Usr usr2 = new Usr();
        address payable proxyAddr = registry.build(address(usr1));
        assertTrue(proxyAddr != address(0));
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(DssProxy(proxyAddr).owner(), address(usr1));

        // Registry set up correctly before transfer
        assertEq(registry.proxies(address(usr1)), proxyAddr);
        assertEq(registry.proxies(address(usr2)), address(0));

        usr1.transferProxy(DssProxy(proxyAddr), address(usr2));
        assertEq(DssProxy(proxyAddr).owner(), address(usr2));

        // Registry now out of date
        assertEq(registry.proxies(address(usr1)), proxyAddr);
        assertEq(registry.proxies(address(usr2)), address(0));

        usr2.claimProxy(registry, proxyAddr);

        // Registry now reports correctly for usr2 but still shows the old one for usr1
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(registry.proxies(address(usr1)), proxyAddr);
        assertEq(registry.proxies(address(usr2)), proxyAddr);

        // Can build for usr1 now
        address payable newProxyAddr = registry.build(address(usr1));
        assertEq(DssProxy(newProxyAddr).owner(), address(usr1));
        assertEq(DssProxy(proxyAddr).owner(), address(usr2));

        // Registry now reports correctly for usr1
        assertEq(registry.seed(address(usr1)), 2);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(registry.proxies(address(usr1)), newProxyAddr);
        assertEq(registry.proxies(address(usr2)), proxyAddr);
    }

    function testClaimOtherProxyOwned() public {
        Usr usr1 = new Usr();
        address payable proxyAddr1 = registry.build(address(usr1));
        assertEq(registry.proxies(address(usr1)), proxyAddr1);
        address payable proxyAddr2 = registry.build(address(this));
        DssProxy(proxyAddr2).setOwner(address(usr1));
        usr1.claimProxy(registry, proxyAddr2);
        assertEq(registry.proxies(address(usr1)), proxyAddr2);
        usr1.claimProxy(registry, proxyAddr1);
        assertEq(registry.proxies(address(usr1)), proxyAddr1);
    }

    function testFailClaimNotAProxy() public {
        registry.claim(payable(address(111)));
    }

    function testFailClaimNotOwnedProxy() public {
        Usr usr1 = new Usr();
        address payable proxyAddr = registry.build(address(this));
        DssProxy(proxyAddr).setOwner(address(123));
        usr1.claimProxy(registry, proxyAddr);
    }
}
