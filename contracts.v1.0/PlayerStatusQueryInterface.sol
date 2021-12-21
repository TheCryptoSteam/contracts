
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


interface PlayerStatusQueryInterface
{
    function stakingAmount(address stakedTokenAddr,address account) view external returns(uint256) ;
}

contract PlayerStatusQueryMock is PlayerStatusQueryInterface
{
    constructor() {
    }

    function stakingAmount(address /*stakedTokenAddr*/,address /*account*/) pure public override returns(uint256) {
        return 0;
    }
}