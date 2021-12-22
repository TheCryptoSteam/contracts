
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

import "./DragonNFT.sol";
import "./EggNFT.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

    struct DragonInfo{
        uint256 id;   //0

        uint256 class ;
        uint256 level;
        uint256 star;
        uint256 hatchTimes;

        uint256 rarity;

        uint256 stakingCSTPower;
        uint256 initialStakingRubyPower;

        uint256 lifeValue;
        uint256 attackValue;
        uint256 defenseValue;
        uint256 speedValue;

        uint256 elementId;
        uint256 skillId;
        uint256 [4] partsIds;

    }


    struct DragonBriefInfo
    {
        uint256 id;
        uint256 elementId;
        uint256 [4] partsIds;
        uint256 rarity;
        uint256 class ;
        uint256 level;
        uint256 star;
        uint256 hatchTimes;
    }


contract DragonNFTHelper
{
    address public immutable metaInfoDbAddress;
    address public immutable dragonNFTAddress;
    address public immutable eggNFTAddress;

    constructor(address metaInfoDbAddr, address dragonNFTAddr, address eggNFTAddr){
        metaInfoDbAddress=metaInfoDbAddr;
        dragonNFTAddress=dragonNFTAddr;
        eggNFTAddress=eggNFTAddr;
    }


    function briefInfos(uint256 tokenId) view public returns(DragonBriefInfo memory){
        (uint256 [INFO_FIELDS_COUNT] memory info, uint256 [INFO_FIELDSEX_COUNT] memory infoEx)=DragonNFT(dragonNFTAddress).allFields(tokenId);
        return DragonBriefInfo(
            info[ID],infoEx[ELEMENT_ID],
            [infoEx[PARTS_HEAD_ID],infoEx[PARTS_BODY_ID],infoEx[PARTS_LIMBS_ID],infoEx[PARTS_WINGS_ID]],
            info[RARITY],
            info[CLASS],info[LEVEL],info[STAR],
            info[HATCH_TIMES]
        );
    }

    function infos(uint256 tokenId) view public returns(DragonInfo memory){
        (uint256 [INFO_FIELDS_COUNT] memory info, uint256 [INFO_FIELDSEX_COUNT] memory infoEx)=DragonNFT(dragonNFTAddress).allFields(tokenId);
        return DragonInfo(info[ID],info[CLASS],info[LEVEL],info[STAR],info[HATCH_TIMES],info[RARITY],
            DragonNFT(dragonNFTAddress).stakingCSTPower(tokenId),info[INIT_STAKING_RUBY_POWER],
            info[LIFE_VALUE],info[ATTACK_VALUE],info[DEFENSE_VALUE],info[SPEED_VALUE],infoEx[ELEMENT_ID],infoEx[SKILL_ID],
            [infoEx[PARTS_HEAD_ID],infoEx[PARTS_BODY_ID],infoEx[PARTS_LIMBS_ID],infoEx[PARTS_WINGS_ID]]);
    }

    function listIds(address user,uint256 beginIndex,uint256 count) view public returns(uint256 [] memory){
        uint256 balance=DragonNFT(dragonNFTAddress).balanceOf(user);
        require(beginIndex+count<=balance,"DragonNFTHelper: Invalid beginIndex pr count");

        uint256 [] memory ids=new uint256[](count);
        uint256 curIdx=0;
        for (uint256 i=beginIndex;i<beginIndex+count;++i){
            uint256 tokenId=DragonNFT(dragonNFTAddress).tokenOfOwnerByIndex(user,i);
            ids[curIdx++]=tokenId;
        }
        return ids;
    }

    function listByIndex(address user,uint256 beginIndex,uint256 count) view external returns(DragonBriefInfo [] memory){
        return list(listIds(user,beginIndex,count));
    }

    function list(uint256 [] memory tokenIds) view public returns(DragonBriefInfo [] memory){
        DragonBriefInfo [] memory binfos=new DragonBriefInfo [](tokenIds.length);
        for (uint256 i=0;i<tokenIds.length;++i){
            binfos[i]=briefInfos(tokenIds[i]);
        }
        return binfos;
    }

    function listEggNFT(uint256 [] memory tokenIds) view external returns(EggInfo [] memory){
        EggInfo [] memory eggInfos=new EggInfo [](tokenIds.length);
        for (uint256 i=0;i<tokenIds.length;++i){
            (uint256 id,uint256 timestamp,uint256 hatchingBeginTime,uint256 remainingHatchDuration) = EggNFT(eggNFTAddress).infos(tokenIds[i]);
            eggInfos[i] = EggInfo(id,timestamp,hatchingBeginTime,remainingHatchDuration);
        }
        return eggInfos;
    }

    function getPartsIds(uint256 tokenId) view public returns(uint256 [4] memory){
        (, uint256 [INFO_FIELDSEX_COUNT] memory infoEx)=DragonNFT(dragonNFTAddress).allFields(tokenId);
        return [infoEx[PARTS_HEAD_ID],infoEx[PARTS_BODY_ID],infoEx[PARTS_LIMBS_ID],infoEx[PARTS_WINGS_ID]];
    }

    function findParentIds(uint256 tokenId) view  public returns(uint256,uint256){
        (uint256 [INFO_FIELDS_COUNT] memory info, )=DragonNFT(dragonNFTAddress).allFields(tokenId);
        return (info[FATHER_ID],info[MOTHER_ID]);
    }

    function rarityOf(uint256 tokenId) view public returns(uint256){
        return DragonNFT(dragonNFTAddress).fields(tokenId,RARITY);
    }

    function getNFTIds(address nftAddr, uint256 beginIndex, uint256 length) view public returns(uint256[] memory) {
        ERC721Enumerable nft = ERC721Enumerable(nftAddr);
        uint256 totalSupply = nft.totalSupply();
        uint256 endIndex=Math.min(totalSupply,beginIndex+length);

        uint256[] memory ids = new uint256[](endIndex-beginIndex);
        for(uint256 i=beginIndex;i<endIndex;++i){
            ids[i-beginIndex] = nft.tokenByIndex(i);
        }
        return ids;
    }
}
