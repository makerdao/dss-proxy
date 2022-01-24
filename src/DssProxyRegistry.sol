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
    function _getSalt(address owner_) internal pure returns (uint256 salt) {
        salt = uint256(uint160(owner_));
    }

    function _getCode(address owner_) internal pure returns (bytes memory code) {
        code = abi.encodePacked(type(DssProxy).creationCode, abi.encode(owner_));
    }

    function getProxy(address owner_) public view returns (address proxy) {
        proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            _getSalt(owner_),
                            keccak256(_getCode(owner_))
                        )
                    )
                )
            )
        );
    }

    function build(address owner_) public returns (address payable proxy) {
        uint256 salt = _getSalt(owner_);
        bytes memory code = _getCode(owner_);
        assembly {
            proxy := create2(0, add(code, 0x20), mload(code), salt)
        }
        require(proxy != address(0), "DssProxyRegistry/proxy-already-created");
    }
}
