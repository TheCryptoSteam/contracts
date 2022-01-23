
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

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MetaInfoDb.sol";
import "./ChestToken.sol";
import "./PlayerStatusQueryInterface.sol";

contract AccountInfo is AccessControl
{
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;
    address public metaInfoDbAddr;
    address public signPublicKey ;

    using Counters for Counters.Counter;
    Counters.Counter public lastEventSeqNum;

    struct Info{
        address account;
        uint256 foodPoints;

        uint256 hatchingNests;
    }

    mapping(address=>Info) public infos;
    mapping(address=>mapping(string =>string)) extInfos;

    mapping(bytes16=>uint256) public actionUUIDs;

    mapping(address=>EnumerableSet.UintSet) hatchingNestsSet ;

    event AccountCreated(address indexed account,uint256 foodPoint,uint256 hatchingNests,uint256 indexed eventSeqNum);
    event AccountFoodsChanged(address account,uint256 foodPoint,uint256 indexed eventSeqNum);
    event AccountHatchingNestsCountChanged(address account,uint256 hatchingNests,uint256 indexed eventSeqNum);
    event AccountHatchingNestsUsed(address account,uint256 eggTokenId,uint256 indexed eventSeqNum);
    event AccountHatchingNestsFree(address account,uint256 eggTokenId,uint256 indexed eventSeqNum);

    event AccountExtInfoChanged(address account,string name,string value,uint256 eventSeqNum);

    modifier notContract() {
        require(!msg.sender.isContract() && (msg.sender == tx.origin), "contract not allowed");
        _;
    }

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role.");
        _;
    }
    constructor(address metaInfoDbAddr_,address signPublicKey_){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        signPublicKey=signPublicKey_;
        resetAddress(metaInfoDbAddr_);

    }


    function newAccount(address account,uint256 foodPoints_,uint256 hatchingNests_/* default 1 */,uint256 expiresAt, uint8 _v, bytes32 _r, bytes32 _s) public {
        require(infos[account].account==address(0),"AccountInfo: account exists");

        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            require(expiresAt > block.timestamp, "AccountInfo: time expired");
            bytes32 messageHash =  keccak256(
                abi.encodePacked(
                    signPublicKey,
                    account,
                    foodPoints_,
                    hatchingNests_,
                    "newAccount",
                    address(this),
                    expiresAt
                )
            );
            MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
            bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
            require(isValidSignature,"AccountInfo: signature error");
        }

        infos[account]=Info(account,foodPoints_,hatchingNests_);

        lastEventSeqNum.increment();
        emit AccountCreated(account,foodPoints_,hatchingNests_,lastEventSeqNum.current());
    }

    function getRewardHatchingNestsByStaking(address account) view  public returns(uint256){
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 cstStakingCount =  PlayerStatusQueryInterface(metaInfo.playerStatusQueryInterface()).stakingAmount(metaInfo.CSTAddress(),account);
        return metaInfo.queryRewardHatchingNestsCST(cstStakingCount);
    }

    function removeFoodPoints(address account,uint256 value, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) public{
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            require(actionUUIDs[actionUUID]==0,"AccountInfo: action has been executed");
            bytes32 messageHash =  keccak256(
                abi.encodePacked(
                    signPublicKey,
                    account,
                    value,
                    actionUUID,
                    "removeFoodPoints",
                    address(this)
                )
            );
            MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
            bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
            require(isValidSignature,"AccountInfo: signature error");
            actionUUIDs[actionUUID]=block.timestamp;
        }
        infos[account].foodPoints-=value;
        lastEventSeqNum.increment();
        emit AccountFoodsChanged(account,infos[account].foodPoints,lastEventSeqNum.current());
    }

    function addFoodPoints(address account,uint256 value, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) public{
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            require(actionUUIDs[actionUUID]==0,"AccountInfo: action has been executed");
            bytes32 messageHash =  keccak256(
                abi.encodePacked(
                    signPublicKey,
                    account,
                    value,
                    actionUUID,
                    "addFoodPoints",
                    address(this)
                )
            );
            MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
            bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
            require(isValidSignature,"AccountInfo: signature error");
            actionUUIDs[actionUUID]=block.timestamp;
        }
        infos[account].foodPoints+=value;
        lastEventSeqNum.increment();
        emit AccountFoodsChanged(account,infos[account].foodPoints,lastEventSeqNum.current());
    }

    function foodPoints(address account) view public returns(uint256) {
        return infos[account].foodPoints;
    }

    function openFoodChest(address account) public notContract {
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        ChestToken chestToken=ChestToken(metaInfo.chestAddressArray(FOOD_CHEST));
        require(chestToken.balanceOf(_msgSender())>0,"AccountInfo: not enough Food Chest");

        uint256 index=metaInfo.probabilisticRandom5(metaInfo.getOutputFoodProbabilityArray());
        (uint256 beginValue,uint256 endValue)=metaInfo.outputFoodScopeArray(index);
        uint256 amount=metaInfo.scopeRand(beginValue,endValue);

        chestToken.burnFrom(_msgSender(), 1);
        infos[account].foodPoints+=amount;
        lastEventSeqNum.increment();
        emit AccountFoodsChanged(account,infos[account].foodPoints,lastEventSeqNum.current());
    }

    function hatchingNests(address account) view public returns(uint256 [] memory) {
        return hatchingNestsSet[account].values();
    }

    function hasRewardHatchingNestsWorking(address account) view external returns(bool){
        return hatchingNests(account).length>infos[account].hatchingNests;
    }

    function hatchingNestsCount(address account) view public returns(uint256){
        uint256 rewardNests=getRewardHatchingNestsByStaking(account);
        return infos[account].hatchingNests+rewardNests;
    }


    //EggNFT contract call it 
    function putInHatchingNest(address account, uint256 eggTokenId) public onlyAdmin returns(bool){
        require(hatchingNestsCount(account)>hatchingNestsSet[account].length(),"AccountInfo: no enought HatchingNests");
        bool ret = hatchingNestsSet[account].add(eggTokenId);
        lastEventSeqNum.increment();
        emit AccountHatchingNestsUsed(account,eggTokenId,lastEventSeqNum.current());
        return ret;
    }

    //EggNFT contract call it 
    function takeOutHatchingNest(address account, uint256 eggTokenId) public onlyAdmin returns(bool){
        bool ret= hatchingNestsSet[account].remove(eggTokenId);
        lastEventSeqNum.increment();
        emit AccountHatchingNestsFree(account,eggTokenId,lastEventSeqNum.current());
        return ret;
    }

    //manager interfaces
    function setSignPublicKey(address signPublicKey_) external onlyAdmin {
        signPublicKey = signPublicKey_;
    }

    function setExtInfo(address account,string memory name,string memory value) public onlyAdmin {
        extInfos[account][name]=value;
        lastEventSeqNum.increment();
        emit AccountExtInfoChanged(account,name,value,lastEventSeqNum.current());
    }

    function resetAddress(address metaInfoDbAddr_) public onlyAdmin {

        metaInfoDbAddr =metaInfoDbAddr_;
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, metaInfo.eggNFTAddr());
    }

    function addHatchingNests(address account,uint256 nestsCount) public onlyAdmin {
        require(infos[account].hatchingNests+nestsCount<=HATCHING_NESTS_SUPPLY,"AccountInfo: hatchingNests must less than HATCHING_NESTS_SUPPLY");
        infos[account].hatchingNests+=nestsCount;

        lastEventSeqNum.increment();
        emit AccountHatchingNestsCountChanged(account,infos[account].hatchingNests,lastEventSeqNum.current());
    }

}
