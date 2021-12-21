
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
import "./MetaInfoDb.sol";


contract RubyToken is ERC20PresetMinterPauser
{
    address public signPublicKey ;
    address public metaInfoDbAddr;

    mapping(bytes16=>uint256) public actionUUIDs;


    constructor(address signPublicKey_) ERC20PresetMinterPauser("DeDragon Ruby Token", "RUBY") {
        signPublicKey=signPublicKey_;
    }

    function setSignPublicKey(address signPublicKey_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "RubyToken: must have admin role");
        signPublicKey = signPublicKey_;
    }

    function setMetaInfoAddress(address metaInfoDbAddr_) external {
        metaInfoDbAddr=metaInfoDbAddr_;
    }

    function mint(uint256 amount, bytes16 actionUUID,uint8 _v, bytes32 _r, bytes32 _s) public {
        //require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        require(actionUUIDs[actionUUID]==0,"AccountInfo: action has been executed");

        bytes32 messageHash =  keccak256(
            abi.encodePacked(
                signPublicKey,
                amount,
                actionUUID,
                "mint",
                address(this)
            )
        );
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
        require(isValidSignature,"signature error");

        actionUUIDs[actionUUID]=block.timestamp;
        _mint(_msgSender(),amount);
    }


}
