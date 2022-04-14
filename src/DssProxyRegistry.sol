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

import "./DssProxy.sol";

contract DssProxyRegistry {
    mapping (address => uint256) public seed;
    mapping (address => address) public proxies;
    mapping (address => uint256) public isProxy;

    function build(address usr) external returns (address payable proxy) {
        proxy = payable(proxies[usr]);

        (, bytes memory owner) = proxy.call(abi.encodeWithSignature("owner()")); // Using low level call in case proxy was self destructed

        require(proxy == address(0) || owner.length != 32 || abi.decode(owner, (address)) != usr, "DssProxyRegistry/proxy-already-registered-to-user"); // Not allow new proxy if the user already has one and remains being the owner

        uint256 salt = uint256(keccak256(abi.encode(usr, ++seed[usr])));

        bytes memory code = abi.encodePacked(type(DssProxy).creationCode, abi.encode(usr));
        assembly {
            proxy := create2(0, add(code, 0x20), mload(code), salt)
        }
        require(proxy != address(0), "DssProxyRegistry/creation-failed");

        proxies[usr] = proxy;
        isProxy[proxy] = 1;
    }


    // This function needs to be used carefully, you should only claim a proxy you trust on.
    // A proxy might be set up with an authority or just simple allowances that might make an
    // attacker to take funds that are sitting in the proxy.
    function claim(address proxy) external {
        require(isProxy[proxy] != 0, "DssProxyRegistry/not-proxy-from-this-registry");
        address owner = DssProxy(payable(proxy)).owner();
        require(owner == msg.sender, "DssProxyRegistry/only-owner-can-claim");
        proxies[owner] = proxy;
    }
}
