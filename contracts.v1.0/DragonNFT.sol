
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

import "@openzeppelin/contracts/utils/Address.sol";
import "./PresetMinterPauserAutoIdNFT.sol";
import "./MetaInfoDb.sol";
import "./ChestToken.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

uint256 constant ID=0;
uint256 constant FATHER_ID=1;
uint256 constant MOTHER_ID=2;
uint256 constant CLASS=3;
uint256 constant LEVEL=4;
uint256 constant STAR=5;
uint256 constant HATCH_TIMES=6;
uint256 constant RARITY=7;
uint256 constant INIT_STAKING_CST_POWER=8;
uint256 constant INIT_STAKING_RUBY_POWER=9;
uint256 constant LIFE_VALUE=10;
uint256 constant ATTACK_VALUE=11;
uint256 constant DEFENSE_VALUE=12;
uint256 constant SPEED_VALUE=13;

uint256 constant ELEMENT_ID=0;
uint256 constant SKILL_ID=1;
uint256 constant PARTS_IDS=2;
uint256 constant PARTS_HEAD_ID=PARTS_IDS+PARTS_HEAD;
uint256 constant PARTS_BODY_ID=PARTS_IDS+PARTS_BODY;
uint256 constant PARTS_LIMBS_ID=PARTS_IDS+PARTS_LIMBS;
uint256 constant PARTS_WINGS_ID=PARTS_IDS+PARTS_WINGS;

uint256 constant INFO_FIELDS_COUNT=SPEED_VALUE+1;
uint256 constant INFO_FIELDSEX_COUNT=PARTS_WINGS_ID+1;

contract DragonNFT is PresetMinterPauserAutoIdNFT
{
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    using Counters for Counters.Counter;

    address public metaInfoDbAddr;
    address public signPublicKey;

    mapping(bytes32=>uint256) public usedSignatures;

    mapping(uint256/** tokenId */=>uint256 [INFO_FIELDS_COUNT])  public fields;
    mapping(uint256/** tokenId */=>uint256 [INFO_FIELDSEX_COUNT])  public fieldsEx;


    mapping(uint256/**rarity id */=>uint256/*total*/) public balanceInRarity;

    uint256 private _currentInfoId;
    uint256 [5/**star */] public levelOfStar;

    event NewDragonMinted(uint256 [INFO_FIELDS_COUNT] info, uint256 [INFO_FIELDSEX_COUNT] infoEx,uint256 indexed eventSeqNum);
    event DragonBurned(uint256 tokenId,uint256 indexed eventSeqNum);
    event DragonHatchTimesChanged(uint256 tokenId,uint256 hatchTimes,uint256 indexed eventSeqNum);
    event DragonStarChanged(uint256 tokenId,uint256 star,uint256 indexed eventSeqNum);
    event DragonStateChanged(uint256 tokenId,uint256 level, uint256 life,uint256 attack,uint256 defense,uint256 speed,uint256 rubyPower,uint256 indexed eventSeqNum);

    function allFields(uint256 tokenId) view public returns(uint256 [INFO_FIELDS_COUNT] memory, uint256 [INFO_FIELDSEX_COUNT] memory){
        return (fields[tokenId], fieldsEx[tokenId]);
    }

    constructor(address eggNFTAddr,address metaInfoDbAddr_,string memory baseTokenURI,address signPublicKey_)
    PresetMinterPauserAutoIdNFT("DeDragon Dragon NFT","DDRN",baseTokenURI)
    {
        metaInfoDbAddr =metaInfoDbAddr_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, eggNFTAddr);
        _setupRole(MINTER_ROLE, address(this));
        signPublicKey = signPublicKey_;
        levelOfStar = [5, 15, 25, 35, 45];
    }


    function setSignPublicKey(address signPublicKey_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "DragonNFT: must have admin role");
        signPublicKey = signPublicKey_;
    }


    function stakingCSTPower(uint256 tokenId) view public returns(uint256){
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 [INFO_FIELDS_COUNT] storage info=fields[tokenId];
        uint256 qf=metaInfo.qualityFactors(info[RARITY]);
        return info[INIT_STAKING_CST_POWER]+(info[LEVEL]-1)*info[INIT_STAKING_CST_POWER]*qf+((((info[LEVEL]/5)^2+(info[LEVEL]/5))/2)*(4^qf))*qf;
    }

    function stakingCSTWeight(uint256 tokenId) view public returns(uint256){
        uint256 weight = stakingCSTPower(tokenId)*FRACTION_INT_BASE/MAX_STAKING_CST_POWER;
        if (weight>MAX_STAKING_CST_WEIGHT_DELTA){
            weight=MAX_STAKING_CST_WEIGHT_DELTA;
        }
        return weight+FRACTION_INT_BASE;
    }

    function initDragonInfo(uint256 id,uint256 class,uint256 kind, uint256 fatherId,uint256 motherId,uint256 rnd) internal {
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        uint256 [INFO_FIELDS_COUNT] storage info=fields[id];
        info[ID]=id;
        info[CLASS]=class;
        info[LEVEL]=1;
        info[HATCH_TIMES]=HATCH_MAX_TIMES;
        info[FATHER_ID] = fatherId;
        info[MOTHER_ID]= motherId;

        info[RARITY]=metaInfo.calcRandRarityR(kind, rnd);
        balanceInRarity[info[RARITY]]+=1;
        {
            (uint256 beginCST,uint256 endCST)=metaInfo.stakingCSTPowerArray(info[RARITY]);
            info[INIT_STAKING_CST_POWER]=MathEx.scopeRandR(beginCST,endCST, rnd/10);

            (uint256 beginRuby,uint256 endRuby)=metaInfo.stakingRubyPowerArray(info[RARITY]);
            info[INIT_STAKING_RUBY_POWER]=MathEx.scopeRandR(beginRuby,endRuby, rnd/100);
        }
        {
            (uint256 beginLife,uint256 endLife)=metaInfo.lifeValueScopeArray(info[RARITY]);
            info[LIFE_VALUE]=MathEx.scopeRandR(beginLife,endLife,rnd/1000);

            (uint256 beginAttack,uint256 endAttack)=metaInfo.attackValueScopeArray(info[RARITY]);
            info[ATTACK_VALUE]=MathEx.scopeRandR(beginAttack,endAttack, rnd/1e4);

            (uint256 beginDefense,uint256 endDefense) = metaInfo.defenseValueScopeArray(info[RARITY]);
            info[DEFENSE_VALUE]=MathEx.scopeRandR(beginDefense,endDefense, rnd/1e5);

            (uint256 beginSpeed,uint256 endSpeed) = metaInfo.speedValueScopeArray(info[RARITY]);
            info[SPEED_VALUE]=MathEx.scopeRandR(beginSpeed,endSpeed, rnd/1e6);
        }

    }

    //Only EggNFT or admin can call the function
    function mintUlitma (address to,uint256 count) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "DragonNFT: must have minter role to mintUlitma");
        for(uint256 i=0;i<count;++i){
            _mintUlitma(to,SUPER_CHEST,i);
        }
    }

    function _mintUlitma(address to,uint256 kind,uint256 seed) internal{
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 rnd = MathEx.randEx(seed);

        _currentInfoId=0;
        PresetMinterPauserAutoIdNFT(this).mint(to);
        require(_currentInfoId!=0,"DragonNFT: mint id error");
        uint256 [INFO_FIELDSEX_COUNT] storage infoEx=fieldsEx[_currentInfoId];

        initDragonInfo(_currentInfoId,CLASS_ULTIMA,kind,0,0,rnd/1e6);
        {

            infoEx[ELEMENT_ID]=metaInfo.getElementId(MathEx.probabilisticRandom6R(metaInfo.allElementProbabilities(), rnd));

            uint256 [4] memory partsCounts=metaInfo.getPartsLibCount(infoEx[ELEMENT_ID]);
            infoEx[PARTS_HEAD_ID]=(rnd / 10) % partsCounts[PARTS_HEAD] + 1;
            infoEx[PARTS_BODY_ID]=(rnd / 100) % partsCounts[PARTS_BODY] + 1;
            infoEx[PARTS_LIMBS_ID]=(rnd / 1000) % partsCounts[PARTS_LIMBS] + 1;
            infoEx[PARTS_WINGS_ID]=(rnd / 1e4) % partsCounts[PARTS_WINGS] + 1;

            uint256 skillsCount=metaInfo.skillsLib(infoEx[ELEMENT_ID]);
            infoEx[SKILL_ID]=(rnd / 1e5) % skillsCount + 1;
        }

        lastEventSeqNum.increment();
        emit NewDragonMinted(fields[_currentInfoId],fieldsEx[_currentInfoId],lastEventSeqNum.current());
    }

    function mintByChest(address to,uint256 chestKind) public notContract {

        require(chestKind==0||chestKind==1,"DragonNFT:chest type must be 0 or 1");
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        ChestToken chestToken=ChestToken(metaInfo.chestAddressArray(chestKind));
        require(chestToken.balanceOf(_msgSender())>0,"DragonNFT: not enough Chest");
        chestToken.burnFrom(_msgSender(), 1);
        _mintUlitma(to,chestKind,0);
    }



    function getHeredityInfo(uint256 tokenId) view public returns(HeredityInfo memory){
        return genHeredityInfo(tokenId,fields[tokenId][FATHER_ID],fields[tokenId][MOTHER_ID]);
    }

    function genHeredityInfo(uint256 tokenId,uint256 fatherTokenId,uint256 motherTokenId )view  public returns(HeredityInfo memory){
        HeredityInfo memory info;
        info.id=tokenId;
        info.fatherFamily=FamilyDragonInfo(fatherTokenId,fields[fatherTokenId][FATHER_ID],fields[fatherTokenId][MOTHER_ID]);
        info.motherFamily=FamilyDragonInfo(motherTokenId,fields[motherTokenId][FATHER_ID],fields[motherTokenId][MOTHER_ID]);
        return info;
    }



    function selectFromHeredityR(uint256 fatherTokenId,uint256 motherTokenId, uint256 rnd) view internal returns(uint256/** tokenId */) {
        require(fatherTokenId!=0 && motherTokenId!=0, "DragonNFT: parent id must be none zero");
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 [6] memory elements=metaInfo.getElementHeredityProbArray();
        HeredityInfo memory fatherFamily=getHeredityInfo(fatherTokenId);
        HeredityInfo memory motherFamily=getHeredityInfo(motherTokenId);
        uint256 [6] memory dragons=[fatherTokenId,motherTokenId,
                                    fatherFamily.fatherFamily.dragonId!=0?fatherFamily.fatherFamily.dragonId:fatherTokenId,
                                    fatherFamily.motherFamily.dragonId!=0?fatherFamily.motherFamily.dragonId:fatherTokenId,
                                    motherFamily.fatherFamily.dragonId!=0?motherFamily.fatherFamily.dragonId:motherTokenId,
                                    motherFamily.motherFamily.dragonId!=0?motherFamily.motherFamily.dragonId:motherTokenId
                                    ];
        uint256 index=MathEx.probabilisticRandom6R(elements, rnd);
        return dragons[index];
    }







    function genPartsFromHeredityR(uint256 fatherTokenId,uint256 motherTokenId,uint256 selectTokenId,uint256 partsIndex, uint256 rnd) view internal returns(uint256){
        uint256 [6] memory parts = [uint256(0),0,0,0,0,0];

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        if (selectTokenId!=fatherTokenId && selectTokenId!=motherTokenId){
            parts=metaInfo.getPartsProb(0);
        }else{
            parts=metaInfo.getPartsProb(1);
        }

        uint256 index=MathEx.probabilisticRandom6R(parts, rnd);

        if (index==0 ){
            //return infoExs[selectTokenId].partsIds[partsIndex];
            return fieldsEx[selectTokenId][PARTS_IDS+partsIndex];
        }else if(index==1){
            if (selectTokenId!=fatherTokenId && selectTokenId!=motherTokenId){
                //return infoExs[selectTokenId].partsIds[partsIndex];
                return fieldsEx[selectTokenId][PARTS_IDS+partsIndex];
            }else{
                HeredityInfo memory family=getHeredityInfo(selectTokenId);
                if (fieldsEx[family.fatherFamily.dragonId][ELEMENT_ID]==fieldsEx[selectTokenId][ELEMENT_ID]){
                    return fieldsEx[family.fatherFamily.dragonId][PARTS_IDS+partsIndex];
                }
                if (fieldsEx[family.motherFamily.dragonId][ELEMENT_ID]==fieldsEx[selectTokenId][ELEMENT_ID]){
                    return fieldsEx[family.motherFamily.dragonId][PARTS_IDS+partsIndex];
                }

            }
        }

        return rnd/10 % (metaInfo.partsLib(fieldsEx[selectTokenId][ELEMENT_ID],partsIndex))+1;

    }





    function genSkillsFromHeredityR(uint256 fatherTokenId,uint256 motherTokenId,uint256 selectTokenId, uint256 rnd) view internal returns(uint256){
        uint256 [6] memory parts = [uint256(0),0,0,0,0,0];

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        if (selectTokenId!=fatherTokenId && selectTokenId!=motherTokenId){
            parts=metaInfo.getSkillsProb(0);
        }else{
            parts=metaInfo.getSkillsProb(1);
        }
        uint256 index=MathEx.probabilisticRandom6R(parts, rnd);

        if (index==0 ){
            return fieldsEx[selectTokenId][SKILL_ID];
        }else if(index==1){
            if (selectTokenId!=fatherTokenId && selectTokenId!=motherTokenId){
                return fieldsEx[selectTokenId][SKILL_ID];
            }else{
                HeredityInfo memory family=getHeredityInfo(selectTokenId);
                if (fieldsEx[family.fatherFamily.dragonId][ELEMENT_ID]==fieldsEx[selectTokenId][ELEMENT_ID]){
                    return fieldsEx[family.fatherFamily.dragonId][SKILL_ID];
                }
                if (fieldsEx[family.motherFamily.dragonId][ELEMENT_ID]==fieldsEx[selectTokenId][ELEMENT_ID]){
                    return fieldsEx[family.motherFamily.dragonId][SKILL_ID];
                }
            }
        }

        return rnd/10 % metaInfo.skillsLib(fieldsEx[selectTokenId][ELEMENT_ID]) + 1;
    }




    function mint(uint256 class,uint256 fatherTokenId,uint256 motherTokenId,address to) public{
        require(hasRole(MINTER_ROLE, _msgSender()), "DragonNFT: must have minter role to mint");
        require(class!=CLASS_ULTIMA,"DragonNFT: must call mintUlitma for Ulitma");
        require(_exists(fatherTokenId) && _exists(motherTokenId),"DragonNFT: parent id not exists");

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 rnd = metaInfo.rand3();

        uint256 selDragonId=selectFromHeredityR(fatherTokenId,motherTokenId, rnd);
        _currentInfoId=0;
        super.mint(to);
        require(_currentInfoId!=0,"DragonNFT: mint id error");
        uint256 [INFO_FIELDSEX_COUNT] storage infoEx=fieldsEx[_currentInfoId];
        initDragonInfo(_currentInfoId,class,SUPER_CHEST,fatherTokenId, motherTokenId,rnd/1e7);

        {
            infoEx[ELEMENT_ID]=fieldsEx[selDragonId][ELEMENT_ID];

            infoEx[PARTS_IDS+PARTS_HEAD]=genPartsFromHeredityR(fatherTokenId,motherTokenId,selDragonId,PARTS_HEAD, rnd/100);
            infoEx[PARTS_IDS+PARTS_BODY]=genPartsFromHeredityR(fatherTokenId,motherTokenId,selDragonId,PARTS_BODY, rnd/1000);
            infoEx[PARTS_IDS+PARTS_LIMBS]=genPartsFromHeredityR(fatherTokenId,motherTokenId,selDragonId,PARTS_LIMBS, rnd/1e4);
            infoEx[PARTS_IDS+PARTS_WINGS]=genPartsFromHeredityR(fatherTokenId,motherTokenId,selDragonId,PARTS_WINGS, rnd/1e5);

            infoEx[SKILL_ID]=genSkillsFromHeredityR(fatherTokenId,motherTokenId,selDragonId,rnd/1e6);
        }

        lastEventSeqNum.increment();
        emit NewDragonMinted(fields[_currentInfoId],fieldsEx[_currentInfoId],lastEventSeqNum.current());

        _currentInfoId=0;
    }

    function _beforeTokenTransfer(address from,address to,uint256 tokenId) internal virtual override{
        if (from==address(0)){ //mint
            _currentInfoId=tokenId;
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }


    function subHatchTimes(uint256 tokenId) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "DragonNFT: must have minter role to subHatchTimes");
        fields[tokenId][HATCH_TIMES]-=1;

        lastEventSeqNum.increment();
        emit DragonHatchTimesChanged(tokenId,fields[tokenId][HATCH_TIMES],lastEventSeqNum.current());
    }

    function hatchCostInfo(uint256 tokenId) view public returns(HatchCostInfo memory){
        require(fields[tokenId][HATCH_TIMES]>0,"DragonNFT: No enough hatch times");

        uint256 hatchCount = HATCH_MAX_TIMES - fields[tokenId][HATCH_TIMES];
        (uint256 CSTCost,uint256 rubyCost)=MetaInfoDb(metaInfoDbAddr).hatchCostInfos(hatchCount);
        return HatchCostInfo(CSTCost,rubyCost);
    }


    function updateStar(uint256 dragonTokenId,uint256 [] calldata foodDragonTokenIds/** dragonNFT as food */) external {
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        uint256 [INFO_FIELDS_COUNT] storage info=fields[dragonTokenId];

        require(info[LEVEL] >= levelOfStar[info[STAR]], "DragonNFT: level too low to updateStar");
        require(info[STAR] < 5, "DragonNFT: reach top star level");

        uint256 [5] memory foodDragons=metaInfo.getStarUpdateTable(info[RARITY],info[STAR]);

        uint256 k=0;
        for (uint256 i=0;i<5;++i){
            for (uint256 j=0;j<foodDragons[i];++j){
                uint256 tokenId=foodDragonTokenIds[k++];
                require (fields[tokenId][RARITY]==i,"DragonNFT:  the rarity does not match to updateStar");
                require (ownerOf(tokenId)==_msgSender(),"DragonNFT: Not your NFT");
                _burn(tokenId);
            }
        }
        fields[dragonTokenId][STAR] += 1;

        lastEventSeqNum.increment();
        emit DragonStarChanged(dragonTokenId,fields[dragonTokenId][STAR],lastEventSeqNum.current());
    }


    function isApprovedOrOwner(address spender, uint256 tokenId) public view returns (bool) {
        return _isApprovedOrOwner(spender,tokenId);
    }

    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
        uint256  rarity = fields[tokenId][RARITY];
        if (balanceInRarity[rarity]>1){
            balanceInRarity[rarity]-=1;
        }
        delete fields[tokenId];
        delete fieldsEx[tokenId];

        lastEventSeqNum.increment();
        emit DragonBurned(tokenId,lastEventSeqNum.current());
        //delete infoExs[tokenId];
        //delete heredityInfos[tokenId];
    }

    function updateStateBatch(uint256[] calldata stateArray,uint256 expiresAt, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) external {
        //require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "DragonNFT: must have admin role");
        require(stateArray.length % 7 == 0, "DragonNFT: wrong length of data");
        require(expiresAt > block.timestamp, "time expired");
        bytes32 messageHash =  keccak256(
            abi.encodePacked(
                signPublicKey,
                stateArray,
                actionUUID,
                "updateState",
                address(this),
                expiresAt
            )
        );
        require(usedSignatures[messageHash]==0,"AccountInfo: action has been executed");
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            bool isValidSignature = MetaInfoDb(metaInfoDbAddr).isValidSignature(messageHash,signPublicKey,_v,_r,_s);
            require(isValidSignature,"signature error");
        }
        usedSignatures[messageHash]=block.timestamp;
        //DragonInfo storage info=fields[tokenId];
        for (uint256 i=0; i<stateArray.length; ) {
            uint256 tokenId = stateArray[i++];
            uint256 [INFO_FIELDS_COUNT] storage info=fields[tokenId];
            info[LEVEL]=stateArray[i++];
            info[LIFE_VALUE]=stateArray[i++];
            info[ATTACK_VALUE]=stateArray[i++];
            info[DEFENSE_VALUE]=stateArray[i++];
            info[SPEED_VALUE]=stateArray[i++];
            info[INIT_STAKING_RUBY_POWER]=stateArray[i++];

            lastEventSeqNum.increment();
            emit  DragonStateChanged(tokenId,info[LEVEL],info[LIFE_VALUE],info[ATTACK_VALUE],info[DEFENSE_VALUE],info[SPEED_VALUE],info[INIT_STAKING_RUBY_POWER],lastEventSeqNum.current());
        }
    }

}
