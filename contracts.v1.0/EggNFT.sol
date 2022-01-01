
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

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./PresetMinterPauserAutoIdNFT.sol";
import "./DragonNFT.sol";
import "./MetaInfoDb.sol";
import "./AccountInfo.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

struct EggInfo {
    uint256 id;
    uint256 timestamp;
    uint256 hatchingBeginTime;
    uint256 remainingHatchDuration;
}


contract EggNFT is PresetMinterPauserAutoIdNFT
{
    using Address for address;
    address public metaInfoDbAddr;

    using Counters for Counters.Counter;

    mapping(uint256=>EggInfo) public infos;
    mapping(uint256=>HeredityInfo) public heredityInfos;

    uint256 private _currentInfoId;
    
    uint256 [5] public hatchingDurationArray;

    event NewEggMinted( EggInfo info, HeredityInfo heredityInfo,uint256 indexed eventSeqNum);
    event EggBurned( uint256 indexed id,uint256 indexed eventSeqNum);
    event EggHatchingStarted(uint256 tokenId,uint256 indexed eventSeqNum);
    event EggHatchingStopped(uint256 tokenId,uint256 indexed eventSeqNum);

    constructor(address metaInfoDbAddr_,string memory baseTokenURI)
    PresetMinterPauserAutoIdNFT("DeDragon Egg NFT","DDEN",baseTokenURI)
    {
        metaInfoDbAddr = metaInfoDbAddr_;
        _setupRole(MINTER_ROLE, address(this));
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        hatchingDurationArray=[50000, 100000, 150000, 200000, 300000];
    }


    function remainingHatchDuration(uint256 tokenId) view public returns(uint256){
        require(_exists(tokenId), "EggNFT: token must be minted");
        EggInfo storage eggInfo  = infos[tokenId];
        if (eggInfo.hatchingBeginTime==0){
            return eggInfo.remainingHatchDuration;
        }else{
            uint256 hatchingBeginTime=eggInfo.hatchingBeginTime;
            if (block.timestamp<eggInfo.hatchingBeginTime){
                hatchingBeginTime=block.timestamp;
            }
            uint256 hatchingPeriod = block.timestamp-hatchingBeginTime;
            if (eggInfo.remainingHatchDuration>hatchingPeriod){
                return eggInfo.remainingHatchDuration-hatchingPeriod;
            }else{
                return 0;
            }
        }
    }

    function startHatching(uint256 tokenId) public{
        require(_exists(tokenId), "EggNFT: the token must be minted");
        require(ownerOf(tokenId)==_msgSender(),"EggNFT: the token not yours");
        require(infos[tokenId].hatchingBeginTime==0,"EggNFT: the token has been hatching");
        require(infos[tokenId].timestamp > 1, "EggNFT: born and broken");
        
        infos[tokenId].hatchingBeginTime=block.timestamp;

        AccountInfo accountInfo=AccountInfo(MetaInfoDb(metaInfoDbAddr).accountInfoAddr());
        accountInfo.putInHatchingNest(_msgSender(), tokenId);

        lastEventSeqNum.increment();
        emit EggHatchingStarted(tokenId,lastEventSeqNum.current());
    }

    function stopHatching(uint256 tokenId) public{
        require(_exists(tokenId), "EggNFT: the token must be minted");
        require(ownerOf(tokenId)==_msgSender(),"EggNFT: the token not yours");
        require(infos[tokenId].hatchingBeginTime!=0,"EggNFT: the token has not been hatching");
        
        EggInfo storage eggInfo  = infos[tokenId]; 
        eggInfo.remainingHatchDuration=remainingHatchDuration(tokenId);
        eggInfo.hatchingBeginTime=0;

        AccountInfo accountInfo=AccountInfo(MetaInfoDb(metaInfoDbAddr).accountInfoAddr());
        accountInfo.takeOutHatchingNest(_msgSender(), tokenId);

        lastEventSeqNum.increment();
        emit EggHatchingStopped(tokenId,lastEventSeqNum.current());
    }


    function hatchNow(uint256 tokenId) public notContract {
        stopHatching(tokenId);
        require(infos[tokenId].hatchingBeginTime==0, "EggNFT: the token is hatching");
        require(remainingHatchDuration(tokenId)==0,"EggNFT: hatching not end");
        require(infos[tokenId].timestamp > 1, "EggNFT: born and broken");

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        HeredityInfo storage info=heredityInfos[tokenId];

        delete infos[tokenId];
        _burn(tokenId);

        DragonNFT dragonNFT=DragonNFT(metaInfo.dragonNFTAddr());
        dragonNFT.mint(CLASS_NONE,info.fatherFamily.dragonId,info.motherFamily.dragonId,_msgSender());

        lastEventSeqNum.increment();
        emit EggBurned(tokenId,lastEventSeqNum.current());
    }


    function mint(uint256 fatherTokenId,uint256 motherTokenId,address to) public notContract {
        DragonNFT dragonNFT=DragonNFT(MetaInfoDb(metaInfoDbAddr).dragonNFTAddr());
        require(dragonNFT.ownerOf(fatherTokenId)==_msgSender(),"EggNFT: father is not yours");
        require(dragonNFT.ownerOf(motherTokenId)==_msgSender(),"EggNFT: mother is not yours");

        require(!dragonNFT.isCloseRelativeWith(fatherTokenId,motherTokenId),"EggNFT: Inbreeding is prohibited");

        HatchCostInfo memory hatchCostInfoFather = dragonNFT.hatchCostInfo(fatherTokenId);
        HatchCostInfo memory hatchCostInfoMonther = dragonNFT.hatchCostInfo(motherTokenId);

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 totalCst=hatchCostInfoFather.CSTCost+hatchCostInfoMonther.CSTCost;
        uint256 totalRuby=hatchCostInfoFather.rubyCost+hatchCostInfoMonther.rubyCost;
        require(ERC20Burnable(metaInfo.CSTAddress()).balanceOf(_msgSender())>=totalCst,"No enought CST");
        require(ERC20Burnable(metaInfo.rubyAddress()).balanceOf(_msgSender())>=totalRuby,"No enought RUBY");

        {
        uint256 rubyBonusAmount=totalRuby*metaInfo.RUBYBonusPoolRate()/FRACTION_INT_BASE;
        uint256 rubyOrgAmount=totalRuby*metaInfo.RUBYOrganizeRate()/FRACTION_INT_BASE;
        uint256 rubyTeamAmount=totalRuby*metaInfo.RUBYTeamRate()/FRACTION_INT_BASE;
        IERC20(metaInfo.rubyAddress()).transferFrom(_msgSender(),metaInfo.RUBYBonusPoolAddress(),rubyBonusAmount);
        IERC20(metaInfo.rubyAddress()).transferFrom(_msgSender(),metaInfo.RUBYOrganizeAddress(),rubyOrgAmount);
        IERC20(metaInfo.rubyAddress()).transferFrom(_msgSender(),metaInfo.RUBYTeamAddress(),rubyTeamAmount);
        ERC20Burnable(metaInfo.rubyAddress()).burnFrom(_msgSender(), totalRuby-rubyBonusAmount-rubyOrgAmount-rubyTeamAmount);

        uint256 cstBonusAmount=totalCst*metaInfo.CSTBonusPoolRate()/FRACTION_INT_BASE;
        uint256 cstOrgAmount=totalCst*metaInfo.CSTOrganizeRate()/FRACTION_INT_BASE;
        IERC20(metaInfo.CSTAddress()).transferFrom(_msgSender(),metaInfo.CSTBonusPoolAddress(),cstBonusAmount);
        IERC20(metaInfo.CSTAddress()).transferFrom(_msgSender(),metaInfo.CSTOrganizeAddress(),cstOrgAmount);
        ERC20Burnable(metaInfo.CSTAddress()).burnFrom(_msgSender(), totalCst-cstBonusAmount-cstOrgAmount);
        }

        dragonNFT.subHatchTimes(fatherTokenId);
        dragonNFT.subHatchTimes(motherTokenId);

        _currentInfoId=0;
        PresetMinterPauserAutoIdNFT(this).mint(to);
        require(_currentInfoId!=0,"EggNFT: mint id error");
        uint256 duration = metaInfo.defaultHatchingDuration();
        uint256 dragonNum = dragonNFT.totalSupply();
        for (uint256 i=0; i<hatchingDurationArray.length; i++) {
            if (dragonNum < hatchingDurationArray[hatchingDurationArray.length-1-i] && duration > 1 days) {
                duration -= 1 days;
            }
        }

        infos[_currentInfoId]=EggInfo(_currentInfoId,block.timestamp,0,duration);
        heredityInfos[_currentInfoId]=dragonNFT.genHeredityInfo(_currentInfoId,fatherTokenId,motherTokenId);

        lastEventSeqNum.increment();
        emit NewEggMinted(infos[_currentInfoId],heredityInfos[_currentInfoId],lastEventSeqNum.current());
    }

    function getHatchingDurationArray() view public returns(uint256 [5] memory) {
        return hatchingDurationArray;
    }

    function setHatchingDurationArray(uint256 [5] memory hatchingDurationArray_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "EggNFT: must have admin role to setHatchingDurationArray");
        hatchingDurationArray=hatchingDurationArray_;
    }

    function _beforeTokenTransfer(address from,address to,uint256 tokenId) internal virtual override{
        if (from==address(0)){
            _currentInfoId=tokenId;
        }
        require(infos[tokenId].hatchingBeginTime==0, "EggNFT: the token is hatching");
        super._beforeTokenTransfer(from, to, tokenId);
    }

}
