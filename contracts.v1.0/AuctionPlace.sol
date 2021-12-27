
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
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
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
    event AuctionStarted(uint256 tokenId,uint biddingTime, address beneficiary, uint256 minPrice,uint256 indexed eventSeqNum);
    event HighestBidIncreased(uint256 tokenId,address bidder, uint amount,uint256 indexed eventSeqNum);
    event AuctionEnded(uint256 tokenId,address winner, uint amount,uint256 indexed eventSeqNum);

    mapping(uint256/*tokenId*/=>Auction[]) public auctions;

    mapping(uint256/*tokenId*/=>mapping(address => uint/*price*/)) pendingReturns;

    constructor(address nftAddr_,address moneyTokenAddr_,address metaInfoDbAddr_,address signPublicKey_){
        moneyTokenAddr=moneyTokenAddr_;
        nftAddr=nftAddr_;
        metaInfoDbAddr=metaInfoDbAddr_;
        signPublicKey=signPublicKey_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function currentRunningAuction(uint256 tokenId) view public returns(Auction memory){
        Auction[] storage aucts=auctions[tokenId];
        require(aucts.length>0,"AuctionPlace: no any auctions");
        Auction storage auction=aucts[aucts.length-1];
        require(auction.ended==false,"AuctionPlace: no any running auctions");
        return auction;
    }

    function hasRunningAuction(uint256 tokenId) view public returns(bool){
        Auction[] storage aucts=auctions[tokenId];
        if (aucts.length==0){
            return false;
        }
        Auction storage auction=aucts[aucts.length-1];
        return (auction.ended==false);
    }

    function hasBid(uint256 tokenId) view public returns(bool){
        Auction[] storage aucts=auctions[tokenId];
        if (aucts.length==0){
            return false;
        }
        Auction storage auction=aucts[aucts.length-1];
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
        require(!hasRunningAuction(tokenId),"AuctionPlace: already auctions going on");

        auctions[tokenId].push(Auction(tokenId, beneficiary_,block.timestamp + biddingTime_,address(0),minPrice,false));

        ERC721(nftAddr).transferFrom(beneficiary_,address(this),tokenId);

        lastEventSeqNum.increment();
        emit AuctionStarted(tokenId,biddingTime_,beneficiary_,minPrice,lastEventSeqNum.current());
    }

    function bid(uint256 tokenId,uint256 price) public {
        require(hasRunningAuction(tokenId),"AuctionPlace: Auction not started");
        Auction[] storage aucts=auctions[tokenId];
        Auction storage currAction=aucts[aucts.length-1];
        require(currAction.beneficiary!=_msgSender(),"AuctionPlace: The NFT token owner should not bid");

        require(block.timestamp <= currAction.auctionEndTime, "AuctionPlace: The auction has already ended.");

        require(price > currAction.highestBid, "AuctionPlace: There's already a higher bid. Try bidding higher!");


        if(currAction.highestBid != 0) {
            pendingReturns[tokenId][currAction.highestBidder] += currAction.highestBid;
        }

        currAction.highestBidder = _msgSender();
        currAction.highestBid = price;

        ERC20(moneyTokenAddr).transferFrom(_msgSender(),address(this),price);

        lastEventSeqNum.increment();
        emit HighestBidIncreased(tokenId,_msgSender(), price,lastEventSeqNum.current());
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

        require(hasRunningAuction(tokenId),"AuctionPlace: The auction of the token has running");

        Auction[] storage aucts=auctions[tokenId];
        Auction storage currAction=aucts[aucts.length-1];


        // Conditions
        require(block.timestamp >= currAction.auctionEndTime, "AuctionPlace: The auction hasn't ended yet");
        require(!currAction.ended, "AuctionPlace: auctionEnd has already been called.");
        MetaInfoDb metaInfo=MetaInfoDb(metaInfoDbAddr);

        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())){
            require(actionUUIDs[actionUUID]==0,"AuctionPlace: action has been executed");
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
            actionUUIDs[actionUUID]=block.timestamp;
        }


        // Effects
        currAction.ended = true;

        // Interaction


        uint256 total=currAction.highestBid;
        uint256 busdOrgAmount=total*metaInfo.BUSDOrganizeRate()/FRACTION_INT_BASE;
        uint256 busdTeamAmount=total*metaInfo.BUSDTeamRate()/FRACTION_INT_BASE;

        ERC20(moneyTokenAddr).transfer(currAction.beneficiary,total-busdOrgAmount-busdTeamAmount);
        ERC20(moneyTokenAddr).transfer(metaInfo.BUSDOrganizeAddress(),busdOrgAmount);
        ERC20(moneyTokenAddr).transfer(metaInfo.BUSDTeamAddress(),busdTeamAmount);
        ERC721(nftAddr).transferFrom(address(this),currAction.highestBidder,tokenId);

        lastEventSeqNum.increment();
        emit AuctionEnded(tokenId,currAction.highestBidder, currAction.highestBid,lastEventSeqNum.current());
    }
}
