
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

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC20PresetMinterPauserEx is ERC20PresetMinterPauser
{

    using Counters for Counters.Counter;
    Counters.Counter public lastEventSeqNum;

    event TransferEx(address indexed from, address indexed to, uint256 value,uint256 indexed eventSeqNum);

    constructor(string memory name,string memory symbol)
        ERC20PresetMinterPauser(name,symbol)
    {

    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override    {
        lastEventSeqNum.increment();
        emit TransferEx(from,to,amount,lastEventSeqNum.current());
    }
}