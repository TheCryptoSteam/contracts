
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

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./MathEx.sol";
import "./PlayerStatusQueryInterface.sol";

struct HatchCostInfo
{
    uint256 rubyCost;
    uint256 CSTCost;
}

struct FamilyDragonInfo
{
    uint256 dragonId;
    uint256 fatherDragonId;
    uint256 montherDragonId;
}

struct HeredityInfo
{
    uint256 id;  //eggNFT id , not dragonNFT Id
    FamilyDragonInfo fatherFamily;
    FamilyDragonInfo motherFamily;
}

struct Scope
{
    uint256 beginValue;
    uint256 endValue;
}


uint256 constant SUPER_CHEST=0;  //super chest and egg use
uint256 constant NORMAL_CHEST=1; //normal chest use
uint256 constant FOOD_CHEST=2;  //food chest use

uint256 constant NORMAL_RARITY = 0;
uint256 constant GOOD_RARITY = 1;
uint256 constant RARE_RARITY = 2;
uint256 constant EPIC_RARITY = 3;
uint256 constant LEGEND_RARITY = 4;
uint256 constant RARITY_MAX = 4;


uint256 constant PARTS_HEAD = 0;
uint256 constant PARTS_BODY = 1;
uint256 constant PARTS_LIMBS = 2;
uint256 constant PARTS_WINGS = 3;

uint256 constant ELEMENT_FIRE = 0x01;
uint256 constant ELEMENT_WATER = 0x02;
uint256 constant ELEMENT_LAND = 0x04;
uint256 constant ELEMENT_WIND = 0x08;
uint256 constant ELEMENT_LIGHT = 0x10;
uint256 constant ELEMENT_DARK = 0x20;

uint256 constant FRACTION_INT_BASE = 10000;

uint256 constant STAKING_NESTS_SUPPLY = 6;
uint256 constant HATCHING_NESTS_SUPPLY= 6;

uint256 constant MAX_STAKING_CST_WEIGHT_DELTA=FRACTION_INT_BASE/STAKING_NESTS_SUPPLY;
uint256 constant MAX_STAKING_CST_POWER_BYONE=4631;
uint256 constant MAX_STAKING_CST_POWER = MAX_STAKING_CST_POWER_BYONE*STAKING_NESTS_SUPPLY;

uint256 constant CLASS_NONE =0;
uint256 constant CLASS_ULTIMA = 0x01;
uint256 constant CLASS_FLASH = 0x02;
uint256 constant CLASS_OLYMPUS = 0x04;


uint256 constant DEFAULT_HATCH_TIMES = 5;
uint256 constant HATCH_MAX_TIMES =7  ;

uint256 constant DEFAULT_HATCHING_DURATION = 5 days;


interface IRandomHolder
{
    function getSeed() view external returns(uint256) ;
}


contract MetaInfoDb is AccessControlEnumerable
{
    address public CSTAddress; //CST token address
    address public rubyAddress; //RUBY token address
    address [3] public chestAddressArray; //Chest token address.0:super;1:normal;2:food

    address public dragonNFTAddr; //DragonNFT address
    address public eggNFTAddr;//EggNFT address
    address public accountInfoAddr; //AccountInfo contract

    address public CSTBonusPoolAddress;
    uint256 public CSTBonusPoolRate; //20%

    address public CSTOrganizeAddress;
    uint256 public CSTOrganizeRate; //10%

    address public RUBYBonusPoolAddress;
    uint256 public RUBYBonusPoolRate; //20%

    address public RUBYOrganizeAddress;
    uint256 public RUBYOrganizeRate; //10%

    address public RUBYTeamAddress;
    uint256 public RUBYTeamRate; //20%

    address public BUSDBonusPoolAddress;
    uint256 public BUSDBonusPoolRate; //70%

    address public BUSDOrganizeAddress;
    uint256 public BUSDOrganizeRate; //10%

    address public BUSDTeamAddress;
    uint256 public BUSDTeamRate; //20%

    address public marketFeesReceiverAddress;

    //marketParams
    // feesRate >0 && <FRACTION_INT_BASE
    uint256 public marketFeesRate;


    uint256 [RARITY_MAX+1] [FOOD_CHEST] public rarityProbabilityFloatArray;


    Scope [RARITY_MAX+1] public stakingCSTPowerArray; 
    Scope [RARITY_MAX+1] public stakingRubyPowerArray;


    HatchCostInfo[HATCH_MAX_TIMES] public hatchCostInfos;

    uint256 public defaultHatchingDuration;


    Scope [RARITY_MAX+1] public lifeValueScopeArray;
    Scope [RARITY_MAX+1] public attackValueScopeArray;
    Scope [RARITY_MAX+1] public defenseValueScopeArray;
    Scope [RARITY_MAX+1] public speedValueScopeArray;

    mapping(uint256/** id */=>uint256 [4]) public partsLib; //index=0:head ; index=1:body ; index=2:limbs ; index=3:wings
    mapping(uint256/** id */=>uint256) public skillsLib;

    uint256 [6][2] public partsLibProb;
    uint256 [6][2] public skillsLibProb;
 
    uint256 [6] public elementProbArray;
    uint256 [6] public elementIdArray;

    uint256 [6] public elementHeredityProbArray;


    uint256 [5/**rarity */][5/**star */] [5/**rarity */] public starUpdateTable; 


    uint256 [5/**rarity */] public qualityFactors;

    uint256 [RARITY_MAX+1] public outputFoodProbabilityArray;
    Scope [RARITY_MAX+1] public outputFoodScopeArray;

    address public playerStatusQueryInterface;

    uint256 [5] public rewardHatchingNestsCST;

    IRandomHolder private randomHolder;

    constructor(address CSTAddr,address rubyAddr,address [3] memory chestAddrArray,address playerStatusQueryInterface_){
        CSTAddress=CSTAddr;
        rubyAddress=rubyAddr;
        chestAddressArray=chestAddrArray;
        playerStatusQueryInterface=playerStatusQueryInterface_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        rarityProbabilityFloatArray=[
            [600,365,30,5,0],  //super chest and egg
            [684,300,15,1,0]   //normal chest
        ];

        hatchCostInfos[0]=HatchCostInfo(640 ether,10 gwei);
        hatchCostInfos[1]=HatchCostInfo(1280 ether,10 gwei);
        hatchCostInfos[2]=HatchCostInfo(1920 ether,10 gwei);
        hatchCostInfos[3]=HatchCostInfo(3200 ether,10 gwei);
        hatchCostInfos[4]=HatchCostInfo(5120 ether,10 gwei);
        hatchCostInfos[5]=HatchCostInfo(8320 ether,10 gwei);
        hatchCostInfos[6]=HatchCostInfo(13440 ether,10 gwei);

        defaultHatchingDuration=DEFAULT_HATCHING_DURATION;







        
        elementProbArray=[20,20,20,20,10,10];
        elementIdArray=[ELEMENT_FIRE, ELEMENT_WATER, ELEMENT_LAND, ELEMENT_WIND,
                        ELEMENT_LIGHT, ELEMENT_DARK];

        elementHeredityProbArray=[30,30,10,10,10,10];

        partsLib[ELEMENT_FIRE]=[10,10,10,10];
        partsLib[ELEMENT_WATER]=[10,10,10,10];
        partsLib[ELEMENT_LAND]=[10,10,10,10];
        partsLib[ELEMENT_WIND]=[10,10,10,10];
        partsLib[ELEMENT_LIGHT]=[10,10,10,10];
        partsLib[ELEMENT_DARK]=[10,10,10,10];

        partsLibProb=[
                [0, 10, 90, 0, 0, 0],
                [40, 10, 50, 0, 0, 0]
        ];

        skillsLib[ELEMENT_FIRE]=20;
        skillsLib[ELEMENT_WATER]=20;
        skillsLib[ELEMENT_LAND]=20;
        skillsLib[ELEMENT_WIND]=20;
        skillsLib[ELEMENT_LIGHT]=20;
        skillsLib[ELEMENT_DARK]=20;

        skillsLibProb=[
                [0, 10, 90, 0, 0, 0],
                [40, 10, 50, 0, 0, 0]
        ];






        qualityFactors=[0,0,1,2,3];

        marketFeesRate=425;//4.25%
        marketFeesReceiverAddress=_msgSender();

        CSTBonusPoolRate=2000; //20%
        CSTOrganizeRate=1000; //10%
        RUBYBonusPoolRate=2000; //20%
        RUBYOrganizeRate=1000; //10%
        RUBYTeamRate=2000; //20%
        BUSDBonusPoolRate=7000; //70%
        BUSDOrganizeRate=1000; //10%
        BUSDTeamRate=2000; //20%

        outputFoodProbabilityArray=[790,160,40,10,0];
        outputFoodScopeArray[NORMAL_RARITY]=Scope(2000 wei,9999 wei);
        outputFoodScopeArray[GOOD_RARITY]=Scope(10000 wei , 50000 wei);
        outputFoodScopeArray[RARE_RARITY]=Scope(50001 wei , 99999 wei);
        outputFoodScopeArray[EPIC_RARITY]=Scope(100000 wei , 299999 wei);
        outputFoodScopeArray[LEGEND_RARITY]=Scope(0,0);

        rewardHatchingNestsCST=[3000 gwei, 4500 gwei, 15000 gwei, 30000 gwei, 45000 gwei];

    }

    function initAttr() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to initAttr");
        stakingCSTPowerArray[NORMAL_RARITY]=Scope(0,0);//0
        stakingCSTPowerArray[GOOD_RARITY]=Scope(1,9);//1~9
        stakingCSTPowerArray[RARE_RARITY]=Scope(10,19);//10~19
        stakingCSTPowerArray[EPIC_RARITY]=Scope(20,29);//20~29
        stakingCSTPowerArray[LEGEND_RARITY]=Scope(30,40);//30~40

        stakingRubyPowerArray[NORMAL_RARITY]=Scope(10,15);//10~15
        stakingRubyPowerArray[GOOD_RARITY]=Scope(16,20);//16~20
        stakingRubyPowerArray[RARE_RARITY]=Scope(21,25);//21~25
        stakingRubyPowerArray[EPIC_RARITY]=Scope(26,30);//26~30
        stakingRubyPowerArray[LEGEND_RARITY]=Scope(31,40);//31~40


        lifeValueScopeArray[NORMAL_RARITY]=Scope(540,600);
        lifeValueScopeArray[GOOD_RARITY]=Scope(810,900);
        lifeValueScopeArray[RARE_RARITY]=Scope(960,1440);
        lifeValueScopeArray[EPIC_RARITY]=Scope(1260,2340);
        lifeValueScopeArray[LEGEND_RARITY]=Scope(2350,3000);
        
        attackValueScopeArray[NORMAL_RARITY]=Scope(90,110);
        attackValueScopeArray[GOOD_RARITY]=Scope(135,165);
        attackValueScopeArray[RARE_RARITY]=Scope(160,240);
        attackValueScopeArray[EPIC_RARITY]=Scope(210,390);
        attackValueScopeArray[LEGEND_RARITY]=Scope(395,500);

        defenseValueScopeArray[NORMAL_RARITY]=Scope(72,88);
        defenseValueScopeArray[GOOD_RARITY]=Scope(108,132);
        defenseValueScopeArray[RARE_RARITY]=Scope(128,192);
        defenseValueScopeArray[EPIC_RARITY]=Scope(168,312);
        defenseValueScopeArray[LEGEND_RARITY]=Scope(320,420);

        speedValueScopeArray[NORMAL_RARITY]=Scope(9,11);
        speedValueScopeArray[GOOD_RARITY]=Scope(13,17);
        speedValueScopeArray[RARE_RARITY]=Scope(16,24);
        speedValueScopeArray[EPIC_RARITY]=Scope(21,39);
        speedValueScopeArray[LEGEND_RARITY]=Scope(40,50);
        
    }

    function initStarTable() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to initAttr");
        starUpdateTable[NORMAL_RARITY]=[
            [1,0,0,0,0],
            [1,0,0,0,0],
            [2,0,0,0,0],
            [2,0,0,0,0],
            [3,0,0,0,0]
        ];

        starUpdateTable[GOOD_RARITY]=[
            [2,0,0,0,0],
            [2,0,0,0,0],
            [2,1,0,0,0],
            [2,2,0,0,0],
            [2,3,0,0,0]
        ];

        starUpdateTable[RARE_RARITY]=[
            [3,1,0,0,0],
            [3,1,0,0,0],
            [3,2,0,0,0],
            [3,2,0,0,0],
            [3,3,0,0,0]
        ];

        starUpdateTable[EPIC_RARITY]=[
            [4,1,0,0,0],
            [4,1,0,0,0],
            [4,2,0,0,0],
            [4,2,0,0,0],
            [2,4,0,0,0]
        ];

        starUpdateTable[LEGEND_RARITY]=[
            [4,1,0,0,0],
            [4,2,0,0,0],
            [2,4,0,0,0],
            [0,6,0,0,0],
            [0,6,0,0,0]
        ];

    }

    function queryRewardHatchingNestsCST(uint256 stakingCTSAmount) view public returns(uint256){
        for (uint256 i=0;i<5;++i){
            if (stakingCTSAmount<rewardHatchingNestsCST[i]){
                return i;
            }
        }
        return 5;
    }

    function setRewardHatchingNestsCST(uint256 [5] memory nestsCSTs) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRewardHatchingNestsCST");
        rewardHatchingNestsCST=nestsCSTs;
    }

    function setPlayerStatusQueryInterface(address playerStatusQueryInterface_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setPlayerStatusQueryInterface");
        playerStatusQueryInterface=playerStatusQueryInterface_;
    }

    function setDefaultHatchingDuration(uint256 hatchingDuration) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setDefaultHatchingDuration");
        defaultHatchingDuration=hatchingDuration;
    }

    function getOutputFoodProbabilityArray() view public returns(uint256 [RARITY_MAX+1] memory){
        return outputFoodProbabilityArray;
    }

    function setOutputFoodProbabilityArray(uint256 [RARITY_MAX+1] memory outputFoodProbabilityArray_) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setOutputFoodProbabilityArray");
        outputFoodProbabilityArray=outputFoodProbabilityArray_;
    }

    function setRandomHolderInterface(address randomHolder_) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRandomHolderInterface");
        randomHolder=IRandomHolder(randomHolder_);
    }

    function setMarketFeesRate(uint256 marketFeesRate_) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setMarketFeesRate");
        require(marketFeesRate_<FRACTION_INT_BASE,"MetaInfoDb: marketFeesRate invalid");
        marketFeesRate=marketFeesRate_;
    }

    function setMarketFeesReceiverAddress(address marketFeesReceiverAddress_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setMarketFeesReceiverAddress");
        marketFeesReceiverAddress=marketFeesReceiverAddress_;
    }

    function setChestTokenAddress(uint256 kind,address chestAddr) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setChestTokenAddress");
        require(kind < chestAddressArray.length, "MetaInfoDb: index out of bound");
        chestAddressArray[kind]=chestAddr;
    }

    function setRarityParam(uint256 kind,uint256 rarity,uint256 probabilityFloat) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRarityParam");
        require(rarity<=LEGEND_RARITY);
        rarityProbabilityFloatArray[kind][rarity]=probabilityFloat;
    }

    function allRarityProbabilities() view public returns(uint256 [5] memory){
        return rarityProbabilityFloatArray[0];
    }

    function allNormalChestRarityProbabilities() view public returns(uint256 [5] memory){
        return rarityProbabilityFloatArray[1];
    }

    function setHatchCostInfo(uint256 index,uint256 CSTCost,uint256 rubyCost) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setHatchCostInfo");
        require(index<HATCH_MAX_TIMES,"MetaInfo: index must less then HATCH_MAX_TIMES");
        hatchCostInfos[index]=HatchCostInfo(CSTCost,rubyCost);
    }

    function getElementHeredityProbArray() view public returns(uint256 [6] memory){
        return elementHeredityProbArray;
    }

    function setElementHeredityProbArray(uint256 [6] memory probs) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setElementHeredityProbArray");
        elementHeredityProbArray=probs;
    }

    function allElementProbabilities() view public returns(uint256 [6] memory){
        return elementProbArray;
    }

    function getElementId(uint256 index) view public returns(uint256){
        return elementIdArray[index];
    }

    function getPartsLibCount(uint256 elementId) view public returns(uint256 [4] memory){
        return partsLib[elementId];
    }

    function getPartsProb(uint256 index) view public returns(uint256 [6] memory){
        return partsLibProb[index];
    }

    function getSkillsProb(uint256 index) view public returns(uint256 [6] memory){
        return skillsLibProb[index];
    }

    function setCSTAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setCSTAddr");
        CSTAddress = addr;
    }

    function setRubyAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRubyAddr");
        rubyAddress = addr;
    }


    function setDragonNFTAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setDragonNFTAddr");
        dragonNFTAddr = addr;
    }

    function setEggNFTAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setEggNFTAddr");
        eggNFTAddr = addr;
    }

    function setAccountInfoAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setAccountInfoAddr");
        accountInfoAddr = addr;
    }

    function setCSTBonusPoolAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setCSTBonusPoolAddress");
        CSTBonusPoolAddress = addr;
    }
    function setCSTBonusPoolRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setCSTBonusPoolRate");
        CSTBonusPoolRate = rate;
    }


    function setCSTOrganizeAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setCSTOrganizeAddress");
        CSTOrganizeAddress = addr;
    }

    function setCSTOrganizeRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setCSTOrganizeRate");
        CSTOrganizeRate = rate;
    }

    function setRUBYBonusPoolAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYBonusPoolAddress");
        RUBYBonusPoolAddress = addr;
    }
    function setRUBYBonusPoolRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYBonusPoolRate");
        RUBYBonusPoolRate = rate;
    }

    function setRUBYOrganizeAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYOrganizeAddress");
        RUBYOrganizeAddress = addr;
    }
    function setRUBYOrganizeRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYOrganizeRate");
        RUBYOrganizeRate = rate;
    }

    function setRUBYTeamAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYTeamAddress");
        RUBYTeamAddress = addr;
    }
    function setRUBYTeamRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setRUBYTeamRate");
        RUBYTeamRate = rate;
    }

    function setBUSDBonusPoolAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDBonusPoolAddress");
        BUSDBonusPoolAddress = addr;
    }
    function setBUSDBonusPoolRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDBonusPoolRate");
        BUSDBonusPoolRate = rate;
    }

    function setBUSDOrganizeAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDOrganizeAddress");
        BUSDOrganizeAddress = addr;
    }
    function setBUSDOrganizeRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDOrganizeRate");
        BUSDOrganizeRate = rate;
    }

    function setBUSDTeamAddress(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDTeamAddress");
        BUSDTeamAddress = addr;
    }
    function setBUSDTeamRate(uint256 rate) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setBUSDTeamRate");
        BUSDTeamRate = rate;
    }

    function getStarUpdateTable(uint256 rarity,uint256 star) view public returns(uint256[5] memory){
        return starUpdateTable[rarity][star];
    }

    function setStarUpdateTable(uint256 rarity, uint256 star, uint256 [RARITY_MAX+1] memory rarityTable) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setStarUpdateTable");
        starUpdateTable[rarity][star]=rarityTable;
    }

    function setStakingCSTPowerArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setStakingCSTPowerArray");
        stakingCSTPowerArray[rarity]=Scope(lower, upper);
    }

    function setStakingRubyPowerArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setStakingRubyPowerArray");
        stakingRubyPowerArray[rarity]=Scope(lower, upper);
    }

    function setLifeValueScopeArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setLifeValueScopeArray");
        lifeValueScopeArray[rarity]=Scope(lower, upper);
    }
    
    function setAttackValueScopeArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setAttackValueScopeArray");
        attackValueScopeArray[rarity]=Scope(lower, upper);
    }

    function setDefenseValueScopeArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setDefenseValueScopeArray");
        defenseValueScopeArray[rarity]=Scope(lower, upper);
    }

    function setSpeedValueScopeArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setSpeedValueScopeArray");
        speedValueScopeArray[rarity]=Scope(lower, upper);
    }

    function setElementProbArray(uint256 element, uint256 prob) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setElementProbArray");
        elementProbArray[element]=prob;
    }

    function setQualityFactors(uint256 rarity, uint256 factor) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setQualityFactors");
        qualityFactors[rarity]=factor;
    }

    function setOutputFoodScopeArray(uint256 rarity, uint256 lower, uint256 upper) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setOutputFoodScopeArray");
        outputFoodScopeArray[rarity]=Scope(lower, upper);
    }

    function setSkillsLib(uint256 elementId,uint256 count) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setSkillsLib");
        skillsLib[elementId]=count;
    }

    function setPartsLib(uint256 elementId,uint256 [4] memory counts) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setPartsLib");
        partsLib[elementId]=counts;
    }

    function setPartsLibProb(uint256 index, uint256 [6] memory probs) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setPartsLibProb");
        partsLibProb[index]=probs;
    }

    function setSkillsLibProb(uint256 index, uint256 [6] memory probs) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MetaInfoDb: must have admin role to setSkillsLibProb");
        skillsLibProb[index]=probs;
    }


    function rand3() public view returns(uint256) {
        return MathEx.randEx(randomHolder.getSeed());
    }

    function calcRandRarity(uint256 kind) view public returns(uint256){
        return probabilisticRandom5(rarityProbabilityFloatArray[kind]);
    }

    function calcRandRarityR(uint256 kind, uint256 rnd) view public returns(uint256){
        return MathEx.probabilisticRandom5R(rarityProbabilityFloatArray[kind], rnd);
    }

    function isValidSignature(bytes32 messageHash, address publicKey, uint8 v, bytes32 r, bytes32 s) public pure returns(bool){
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address addr = ecrecover(prefixedHash, v, r, s);
        return (addr==publicKey);
    }

    function scopeRand(uint256 beginNumber,uint256 endNumber) public view returns(uint256){
        return MathEx.rand(endNumber-beginNumber+1,randomHolder.getSeed())+beginNumber;
    }


    function probabilisticRandom4(uint256 [4] memory probabilities) view public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<4;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=MathEx.rand(totalRarityProbability,randomHolder.getSeed());
        for (uint256 i=0;i<4;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }


    function probabilisticRandom5(uint256 [5] memory probabilities) view  public returns(uint256/**index*/){

        uint256 totalRarityProbability=0;
        for (uint256 i=0;i<5;++i){
            totalRarityProbability+=probabilities[i];
            if (i>0){
                probabilities[i]+=probabilities[i-1];
            }
        }

        uint256 parityPoint=MathEx.rand(totalRarityProbability,randomHolder.getSeed());
        for (uint256 i=0;i<5;++i){
            if (parityPoint<probabilities[i]){
                return i;
            }
        }

        return 0;
    }
}
