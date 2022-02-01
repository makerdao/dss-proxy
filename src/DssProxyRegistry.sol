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

pragma solidity ^0.8.9;

import "./DssProxy.sol";

contract DssProxyRegistry {
    mapping (address => uint256) public seed;

    function _salt(address owner_) internal view returns (uint256 salt) {
        salt = uint256(keccak256(abi.encode(owner_, seed[owner_])));
    }

    function _code(address owner_) internal pure returns (bytes memory code) {
        code = abi.encodePacked(type(DssProxy).creationCode, abi.encode(owner_));
    }

    function proxies(address owner_) public view returns (address proxy) {
        proxy = seed[owner_] == 0
            ? address(0)
            : address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                _salt(owner_),
                                keccak256(_code(owner_))
                            )
                        )
                    )
                )
            );
    }

    function build(address owner_) external returns (address payable proxy) {
        address payable proxy_ = payable(proxies(owner_));
        require(proxy_ == address(0) || DssProxy(proxy_).owner() != owner_); // Not allow new proxy if the user already has one and remains being the owner
        seed[owner_]++;
        uint256 salt = _salt(owner_);
        bytes memory code = _code(owner_);
        assembly {
            proxy := create2(0, add(code, 0x20), mload(code), salt)
        }
    }
}
