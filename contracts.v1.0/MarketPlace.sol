
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
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MetaInfoDb.sol";

contract MarketPlace is AccessControlEnumerable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    address public metaInfoDbAddr;

    struct OrderInfo{
        address owner;

        address nftAddr;
        uint256 tokenId;

        address priceToken;
        uint256 orderPrice;

        uint256 validPeriod;
        uint256 createTimestamp; 
    }
    
    EnumerableSet.AddressSet supportNFTs;
    mapping(address/**nft address */=>EnumerableSet.UintSet) orderTokenIds;
    mapping(address/**nft address */=>mapping(address/** account address */=>EnumerableSet.UintSet)) userOrderTokenIds;
    mapping(address/**nft address */=>mapping(uint256/** tokenId */=>OrderInfo))  public orderInfos;


    using Counters for Counters.Counter;
    Counters.Counter public lastEventSeqNum;

    event NewSellOrder(address nftAddr, uint256 tokenId, address priceToken, uint256 orderPrice, uint256 validPeriod, uint256 createTimestamp, address owner,uint256 indexed eventSeqNum);
    event CancelSellOrder(address nftAddr, uint256 tokenId,address owner,uint256 indexed eventSeqNum);
    event NewTrade(address nftAddr, uint256 tokenId,uint256 indexed eventSeqNum);

    constructor(address metaInfoDbAddr_) {
        metaInfoDbAddr=metaInfoDbAddr_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function sell(address nftAddr, uint256 tokenId, address priceToken, uint256 price, uint256 validPeriod) external{
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        require(priceToken==metaInfo.rubyAddress(),"MarketPlace: Ruby Only");
        require(supportNFTs.contains(nftAddr),"MarketPlace: Unknown NFT");
        require(IERC721(nftAddr).ownerOf(tokenId)==_msgSender(),"MarketPlace: Not your NFT");

        orderTokenIds[nftAddr].add(tokenId);
        userOrderTokenIds[nftAddr][_msgSender()].add(tokenId);
        orderInfos[nftAddr][tokenId]=OrderInfo(_msgSender(),nftAddr,tokenId,priceToken,price,validPeriod,block.timestamp);

        IERC721(nftAddr).transferFrom(_msgSender(), address(this), tokenId);

        lastEventSeqNum.increment();
        emit NewSellOrder(nftAddr,tokenId,priceToken,price,validPeriod,block.timestamp,_msgSender(),lastEventSeqNum.current());
    }

    function cancelSell(address nftAddr,uint256 tokenId) public {
        require(orderTokenIds[nftAddr].contains(tokenId),"MarketPlace: No such NFT");
        require(orderInfos[nftAddr][tokenId].owner==_msgSender(),"MarketPlace: Not your NFT");
        
        orderTokenIds[nftAddr].remove(tokenId);
        userOrderTokenIds[nftAddr][_msgSender()].remove(tokenId);
        delete orderInfos[nftAddr][tokenId];
    
        IERC721(nftAddr).transferFrom(address(this), _msgSender(), tokenId);

        lastEventSeqNum.increment();
        emit CancelSellOrder(nftAddr,tokenId,_msgSender(),lastEventSeqNum.current());
    }

    function buy(address nftAddr, uint256 tokenId) external{
        require(orderTokenIds[nftAddr].contains(tokenId),"MarketPlace: No such NFT");

        OrderInfo storage info=orderInfos[nftAddr][tokenId];

        require(info.owner!=_msgSender(),"MarketPlace: Is your NFT");
        require(block.timestamp < info.createTimestamp+info.validPeriod,"MarketPlace: Out of the available time");

        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);
        uint256 fees = info.orderPrice * metaInfo.marketFeesRate() / FRACTION_INT_BASE;

        require(IERC20(info.priceToken).balanceOf(_msgSender())>=info.orderPrice,"MarketPlace: Not enough price token");

        orderTokenIds[nftAddr].remove(tokenId);
        userOrderTokenIds[nftAddr][_msgSender()].remove(tokenId);
        address priceToken = info.priceToken;
        address owner = info.owner;
        uint256 orderPrice = info.orderPrice;
        delete orderInfos[nftAddr][tokenId];

        uint256 rubyBonusAmount=fees*metaInfo.RUBYBonusPoolRate()/FRACTION_INT_BASE;
        uint256 rubyOrgAmount=fees*metaInfo.RUBYOrganizeRate()/FRACTION_INT_BASE;
        uint256 rubyTeamAmount=fees*metaInfo.RUBYTeamRate()/FRACTION_INT_BASE;

        IERC20(priceToken).transferFrom(_msgSender(), metaInfo.RUBYBonusPoolAddress(), rubyBonusAmount);
        IERC20(priceToken).transferFrom(_msgSender(), metaInfo.RUBYOrganizeAddress(), rubyOrgAmount);
        IERC20(priceToken).transferFrom(_msgSender(), metaInfo.RUBYTeamAddress(), rubyTeamAmount);
        ERC20Burnable(priceToken).burnFrom(_msgSender(), fees-rubyBonusAmount-rubyOrgAmount-rubyTeamAmount);

        IERC20(priceToken).transferFrom(_msgSender(), owner, orderPrice-fees);
        IERC721(nftAddr).transferFrom(address(this), _msgSender(), tokenId);

        lastEventSeqNum.increment();
        emit NewTrade(nftAddr,tokenId,lastEventSeqNum.current());
    }

    function addNFTs(address [] calldata nftAddrArray) external  {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MarketPlace: must have admin role to addNFTs");
        for(uint256 i=0;i<nftAddrArray.length;++i){
            supportNFTs.add(nftAddrArray[i]);
        }
    }

    function supportNFTCount() view public returns(uint256) {
        return supportNFTs.length();
    }

    function listSupportNFTs(uint256 sizePerPage, uint256 index) view public returns(address [] memory){
        uint256 end=Math.min(sizePerPage*(index+1),supportNFTs.length());
        uint256 begin=sizePerPage*index;
        address [] memory dataArray = new address[](end-begin);
        for (uint256 i = begin; i < end; ++i){
            dataArray[i-begin] = supportNFTs.at(i);
        }
        return dataArray;
    }

    function count(address nftAddr) view public returns(uint256){
        return orderTokenIds[nftAddr].length();
    }

    function listPage(address nftAddr,uint256 sizePerPage,uint256 index) view public returns(OrderInfo [] memory){
        EnumerableSet.UintSet storage tokenIds=orderTokenIds[nftAddr];
        uint256 end=Math.min(sizePerPage*(index+1),tokenIds.length());
        uint256 begin=sizePerPage*index;
        OrderInfo [] memory orderArray = new OrderInfo[](end-begin);
        for (uint256 i = begin; i < end; ++i){
            orderArray[i-begin] = orderInfos[nftAddr][tokenIds.at(i)];
        }
        return orderArray;
    }

    function listIdPage(address nftAddr,uint256 sizePerPage,uint256 index) view public returns(uint256 [] memory){
        EnumerableSet.UintSet storage tokenIds=orderTokenIds[nftAddr];
        uint256 end=Math.min(sizePerPage*(index+1),tokenIds.length());
        uint256 begin=sizePerPage*index;
        uint256 [] memory idArray = new uint256[](end-begin);
        for (uint256 i = begin; i < end; ++i){
            idArray[i-begin] = tokenIds.at(i);
        }
        return idArray;
    }

    function countOf(address user,address nftAddr) view public returns(uint256){
        return userOrderTokenIds[nftAddr][user].length();
    }

    function listPageOf(address user,address nftAddr,uint256 sizePerPage,uint256 index)view public returns(OrderInfo [] memory){
        EnumerableSet.UintSet storage tokenIds=userOrderTokenIds[nftAddr][user];
        uint256 end=Math.min(sizePerPage*(index+1),tokenIds.length());
        uint256 begin=sizePerPage*index;
        OrderInfo [] memory orderArray = new OrderInfo[](end-begin);
        for (uint256 i = begin; i < end; ++i){
            orderArray[i-begin] = orderInfos[nftAddr][tokenIds.at(i)];
        }
        return orderArray;
    }

}
