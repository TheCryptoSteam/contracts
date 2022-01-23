
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

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MetaInfoDb.sol";

contract AuctionPlace is Context,AccessControlEnumerable{

    address public moneyTokenAddr;
    address immutable nftAddr;
    address public metaInfoDbAddr;
    address public signPublicKey;
    mapping(bytes16=>uint256) public actionUUIDs;

    struct Auction{
        uint256 tokenId; //nft token id
        address beneficiary;
        uint auctionEndTime;

        address highestBidder;
        uint highestBid;
        bool ended;
    }

    using Counters for Counters.Counter;
    Counters.Counter public lastEventSeqNum;

    // Events that will be emitted on changes.
    event AuctionStarted(uint256 tokenId,uint auctionEndTime, address beneficiary, uint256 highestBid,uint256 indexed eventSeqNum);
    event HighestBidIncreased(uint256 tokenId,address highestBidder, uint highestBid,uint256 indexed eventSeqNum);
    event AuctionEnded(uint256 tokenId,address highestBidder, uint highestBid,bytes16 actionUUID,uint256 indexed eventSeqNum);

    mapping(uint256/*tokenId*/=>Auction) public auctions;

    mapping(uint256/*tokenId*/=>mapping(address => uint/*price*/)) pendingReturns;

    constructor(address nftAddr_,address moneyTokenAddr_,address metaInfoDbAddr_,address signPublicKey_){
        moneyTokenAddr=moneyTokenAddr_;
        nftAddr=nftAddr_;
        metaInfoDbAddr=metaInfoDbAddr_;
        signPublicKey=signPublicKey_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }


    function hasRunningAuction(uint256 tokenId) view public returns(bool){
        Auction storage auction=auctions[tokenId];
        if (auction.tokenId==0){
            return false;
        }
        return (auction.ended==false && block.timestamp < auction.auctionEndTime);
    }

    function hasBid(uint256 tokenId) view public returns(bool){
        Auction storage auction=auctions[tokenId];
        if (auction.tokenId==0){
            return false;
        }
        return auction.highestBidder!=address(0);
    }

    function setSignPublicKey(address signPublicKey_) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AuctionPlace: must have admin role");
        signPublicKey = signPublicKey_;
    }

    function setMoneyTokenAddr(address addr) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AuctionPlace: must have admin role to setMoneyTokenAddr");
        moneyTokenAddr = addr;
    }    

    function startAnAuction(uint256 tokenId,uint biddingTime_, address beneficiary_, uint256 minPrice) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AuctionPlace: must have admin role to startAnAuction");
        require(ERC721(nftAddr).ownerOf(tokenId)== beneficiary_,"AuctionPlace: NFT does not belong to the beneficiary");
        Auction storage auction=auctions[tokenId];
        require(auction.tokenId==0 || auction.ended==true,"AuctionPlace: already auctions going on");

        auctions[tokenId]=Auction(tokenId, beneficiary_,block.timestamp + biddingTime_,address(0),minPrice,false);

        ERC721(nftAddr).transferFrom(beneficiary_,address(this),tokenId);

        lastEventSeqNum.increment();
        emit AuctionStarted(tokenId,block.timestamp +biddingTime_,beneficiary_,minPrice,lastEventSeqNum.current());
    }

    function bid(uint256 tokenId,uint256 price) public {
        require(hasRunningAuction(tokenId),"AuctionPlace: Auction not started");
        Auction storage currAction=auctions[tokenId];
        require(currAction.tokenId!=0,"AuctionPlace: no such auction");
        require(currAction.beneficiary!=_msgSender(),"AuctionPlace: The NFT token owner should not bid");

        require(block.timestamp <= currAction.auctionEndTime, "AuctionPlace: The auction has already ended.");

        require(price > currAction.highestBid, "AuctionPlace: There's already a higher bid. Try bidding higher!");


        if(currAction.highestBid != 0) {
            pendingReturns[tokenId][currAction.highestBidder] += currAction.highestBid;
        }

        currAction.highestBidder = _msgSender();
        currAction.highestBid = price;

        uint256 bal0 = ERC20(moneyTokenAddr).balanceOf(address(this));
        ERC20(moneyTokenAddr).transferFrom(_msgSender(),address(this),price);
        require(ERC20(moneyTokenAddr).balanceOf(address(this)) == bal0 + price, "AuctionPlace: received money should be equal to price");

        lastEventSeqNum.increment();
        emit HighestBidIncreased(tokenId,currAction.highestBidder, currAction.highestBid,lastEventSeqNum.current());
    }

    function withdraw(uint256 tokenId) public {
        uint amount = pendingReturns[tokenId][_msgSender()];

        if(amount > 0) {
            require(ERC20(moneyTokenAddr).balanceOf(address(this))>=amount,"AuctionPlace: no enough money");
            pendingReturns[tokenId][_msgSender()] = 0;
            ERC20(moneyTokenAddr).transfer(_msgSender(),amount);
        }
    }

    function auctionEnd(uint256 tokenId, bytes16 actionUUID, uint8 _v, bytes32 _r, bytes32 _s) public {



        Auction storage currAuction =auctions[tokenId];
        require(currAuction.tokenId!=0,"AuctionPlace: no such auction");

        // Conditions
        require(block.timestamp >= currAuction.auctionEndTime, "AuctionPlace: The auction hasn't ended yet");
        require(!currAuction.ended, "AuctionPlace: auctionEnd has already been called.");
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        require(actionUUIDs[actionUUID]==0,"AuctionPlace: action has been executed");
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            bytes32 messageHash =  keccak256(
                abi.encodePacked(
                    signPublicKey,
                    tokenId,
                    actionUUID,
                    "auctionEnd",
                    address(this)
                )
            );
            bool isValidSignature = metaInfo.isValidSignature(messageHash,signPublicKey,_v,_r,_s);
            require(isValidSignature,"AuctionPlace: signature error");
        }
        actionUUIDs[actionUUID]=block.timestamp;


        // Effects
        currAuction.ended = true;

        // Interaction


        uint256 total= currAuction.highestBid;
        uint256 usdOrgAmount=total*metaInfo.USDOrganizeRate()/FRACTION_INT_BASE;
        uint256 usdTeamAmount=total*metaInfo.USDTeamRate()/FRACTION_INT_BASE;

        ERC20(moneyTokenAddr).transfer(currAuction.beneficiary,total-usdOrgAmount-usdTeamAmount);
        ERC20(moneyTokenAddr).transfer(metaInfo.USDOrganizeAddress(),usdOrgAmount);
        ERC20(moneyTokenAddr).transfer(metaInfo.USDTeamAddress(),usdTeamAmount);
        ERC721(nftAddr).transferFrom(address(this), currAuction.highestBidder,tokenId);

        lastEventSeqNum.increment();
        emit AuctionEnded(tokenId, currAuction.highestBidder, currAuction.highestBid,actionUUID,lastEventSeqNum.current());
    }
}
