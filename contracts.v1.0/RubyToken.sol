
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
import "./MetaInfoDb.sol";


contract RubyToken is ERC20PresetMinterPauserEx
{
    address public signPublicKey ;
    address public metaInfoDbAddr;

    mapping(bytes32=>uint256) public usedSignatures;


    constructor(address signPublicKey_)
    ERC20PresetMinterPauserEx("DeDragon Ruby Token", "RUBY")
    {
        signPublicKey=signPublicKey_;
    }

    function setSignPublicKey(address signPublicKey_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "RubyToken: must have admin role");
        signPublicKey = signPublicKey_;
    }

    function setMetaInfoAddress(address metaInfoDbAddr_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "RubyToken: must have admin role");
        metaInfoDbAddr=metaInfoDbAddr_;
    }

    function mint(uint256 amount, bytes16 actionUUID,uint8 _v, bytes32 _r, bytes32 _s) public {

        bytes32 messageHash =  keccak256(
            abi.encodePacked(
                signPublicKey,
                amount,
                actionUUID,
                "mint",
                address(this)
            )
        );
        require(usedSignatures[messageHash]==0,"AccountInfo: action has been executed");
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
        require(isValidSignature,"signature error");

        usedSignatures[messageHash]=block.timestamp;
        _mint(_msgSender(),amount);
    }


}
