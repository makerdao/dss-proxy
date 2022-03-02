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

pragma solidity ^0.8.11;

import "./DssProxy.sol";

contract DssProxyRegistry {
    mapping (address => uint256) public seed;
    mapping (address => address) public proxies;
    mapping (address => uint256) public isProxy;

    function build(address owner_) external returns (address payable proxy) {
        proxy = payable(proxies[owner_]);
        require(proxy == address(0) || DssProxy(payable(proxy)).owner() != owner_, "DssProxyRegistry/proxy-registered-to-owner"); // Not allow new proxy if the user already has one and remains being the owner

        uint256 _seed = seed[owner_];
        seed[owner_] = ++_seed;
        uint256 salt = uint256(keccak256(abi.encode(owner_, _seed)));

        bytes memory code = abi.encodePacked(type(DssProxy).creationCode, abi.encode(owner_));
        assembly {
            proxy := create2(0, add(code, 0x20), mload(code), salt)
        }
        proxies[owner_] = proxy;
        isProxy[proxy] = 1;
    }

    // This function needs to be used carefully, you should only claim a proxy you trust on.
    // A proxy might be set up with an authority or just simple allowances that might make an
    // attacker to take funds that are sitting in the proxy.
    function claim(address proxy) external {
        require(isProxy[proxy] == 1, "DssProxyRegistry/not-proxy-from-this-registry");
        address owner = DssProxy(payable(proxy)).owner();
        require(owner == msg.sender, "DssProxyRegistry/only-owner-can-claim");
        address payable prevProxy = payable(proxies[owner]);
        require(prevProxy == address(0) || DssProxy(prevProxy).owner() != owner, "DssProxyRegistry/owner-proxy-already-exists"); // Not allow new proxy if the user already has one and remains being the owner
        proxies[owner] = proxy;
    }
}
