
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
import "./MetaInfoDb.sol";
import "./ChestToken.sol";
import "./PlayerStatusQueryInterface.sol";

contract AccountInfo is AccessControl
{
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;
    address public metaInfoDbAddr;
    address public signPublicKey ;

    struct Info{
        address account;
        uint256 foodPoints;

        uint256 hatchingNests;
        //uint256 stakingNests;
    }

    mapping(address=>Info) public infos;
    mapping(address=>mapping(string =>string)) extInfos;

    mapping(bytes16=>uint256) public actionUUIDs;

    mapping(address=>EnumerableSet.UintSet) hatchingNestsSet ;

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    modifier notContract() {
        require((!_isContract(msg.sender)) && (msg.sender == tx.origin), "contract not allowed");
        _;
    }

    constructor(address metaInfoDbAddr_,address signPublicKey_){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        signPublicKey=signPublicKey_;
        resetAddress(metaInfoDbAddr_);

    }


    function newAccount(address account,uint256 foodPoints_,uint256 hatchingNests_/* default 1 */,uint256 expiresAt, uint8 _v, bytes32 _r, bytes32 _s) public {
        //require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to newAccount");
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

        //infos[account]=Info(account,foodPoints_,hatchingNests_,STAKING_NESTS_SUPPLY);
        infos[account]=Info(account,foodPoints_,hatchingNests_);
    }

    function getRewardHatchingNestsByStaking(address account) view  public returns(uint256){
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 cstStakingCount =  PlayerStatusQueryInterface(metaInfo.playerStatusQueryInterface()).stakingAmount(metaInfo.CSTAddress(),account);
        return metaInfo.queryRewardHatchingNestsCST(cstStakingCount);
    }

    function removeFoodPoints(address account,uint256 value, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) public{
        //require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to addFoodPoints");
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
    }

    function addFoodPoints(address account,uint256 value, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) public{
        //require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to addFoodPoints");
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
        //ERC20Burnable(metaInfo.rubyAddress()).burnFrom(_msgSender(), hatchCostInfoFather.rubyCost+hatchCostInfoMonther.rubyCost);
        //chestToken.burn(1);
        infos[account].foodPoints+=amount;
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
    function putInHatchingNest(address account, uint256 eggTokenId) public returns(bool){
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to putInHatchingNest");
        require(hatchingNestsCount(account)>hatchingNestsSet[account].length(),"AccountInfo: no enought HatchingNests");
        return hatchingNestsSet[account].add(eggTokenId);
    }

    //EggNFT contract call it 
    function takeOutHatchingNest(address account, uint256 eggTokenId) public returns(bool){
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to takeOutHatchingNest");
        return hatchingNestsSet[account].remove(eggTokenId);
    }

    //manager interfaces
    function setSignPublicKey(address signPublicKey_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role");
        signPublicKey = signPublicKey_;
    }

    function setExtInfo(address account,string memory name,string memory value) public{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to setExtInfo");
        extInfos[account][name]=value;
    }

    function resetAddress(address metaInfoDbAddr_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to resetAddress");

        metaInfoDbAddr =metaInfoDbAddr_;
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, metaInfo.eggNFTAddr());
    }

    function addHatchingNests(address account,uint256 nestsCount) public{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AccountInfo: must have admin role to addHatchingNests");
        require(infos[account].hatchingNests+nestsCount<=HATCHING_NESTS_SUPPLY,"AccountInfo: hatchingNests must less than HATCHING_NESTS_SUPPLY");
        infos[account].hatchingNests+=nestsCount;
    }

}
