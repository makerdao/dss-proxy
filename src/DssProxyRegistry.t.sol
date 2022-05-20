// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
        address payable proxy = registry.build(address(this));
        DssProxy(proxy).execute(address(new Destruct()), abi.encodeWithSignature("destruct()"));
    }

    function testProxyCreation() public {
        Usr usr = new Usr();

        assertEq(registry.proxies(address(usr)), address(0));
        assertEq(registry.seed(address(usr)), 0);
        address payable proxy = registry.build(address(usr));
        assertEq(registry.seed(address(usr)), 1);
        assertEq(registry.proxies(address(usr)), proxy);
        assertEq(DssProxy(proxy).owner(), address(usr));
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
        address payable proxy = registry.build(address(usr1));
        assertTrue(proxy != address(0));
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(DssProxy(proxy).owner(), address(usr1));

        // Registry set up correctly before transfer
        assertEq(registry.proxies(address(usr1)), proxy);
        assertEq(registry.proxies(address(usr2)), address(0));

        usr1.transferProxy(DssProxy(proxy), address(usr2));
        assertEq(DssProxy(proxy).owner(), address(usr2));

        // Registry now out of date
        assertEq(registry.proxies(address(usr1)), proxy);
        assertEq(registry.proxies(address(usr2)), address(0));

        usr2.claimProxy(registry, proxy);

        // Registry now reports correctly for usr2 but still shows the old one for usr1
        assertEq(registry.seed(address(usr1)), 1);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(registry.proxies(address(usr1)), proxy);
        assertEq(registry.proxies(address(usr2)), proxy);

        // Can build for usr1 now
        address payable proxy2 = registry.build(address(usr1));
        assertEq(DssProxy(proxy2).owner(), address(usr1));
        assertEq(DssProxy(proxy).owner(), address(usr2));

        // Registry now reports correctly for usr1
        assertEq(registry.seed(address(usr1)), 2);
        assertEq(registry.seed(address(usr2)), 0);
        assertEq(registry.proxies(address(usr1)), proxy2);
        assertEq(registry.proxies(address(usr2)), proxy);
    }

    function testClaimOtherProxyOwned() public {
        Usr usr1 = new Usr();
        address payable proxy = registry.build(address(usr1));
        assertEq(registry.proxies(address(usr1)), proxy);
        address payable proxy2 = registry.build(address(this));
        DssProxy(proxy2).setOwner(address(usr1));
        usr1.claimProxy(registry, proxy2);
        assertEq(registry.proxies(address(usr1)), proxy2);
        usr1.claimProxy(registry, proxy);
        assertEq(registry.proxies(address(usr1)), proxy);
    }

    function testFailClaimNotAProxy() public {
        registry.claim(payable(address(111)));
    }

    function testFailClaimNotOwnedProxy() public {
        Usr usr1 = new Usr();
        address payable proxy = registry.build(address(this));
        DssProxy(proxy).setOwner(address(123));
        usr1.claimProxy(registry, proxy);
    }
}
