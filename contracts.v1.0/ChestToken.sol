
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//                   Version 2, December 2004
// 
//CryptoSteam @2021,All rights reserved
//
//Everyone is permitted to copy and distribute verbatim or modified
//copies of this license document, and changing it is allowed as long
//as the name is changed.
// 
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
//
// You just DO WHAT THE FUCK YOU WANT TO.

pragma solidity ^0.8.0;

import "./ERC20PresetMinterPauserEx.sol";


contract ChestToken is ERC20PresetMinterPauserEx
{
    uint256 immutable public kind;

    constructor(uint256 kind_,string memory name, string memory symbol)
    ERC20PresetMinterPauserEx(name, symbol)
    {
        kind=kind_;
    }

}