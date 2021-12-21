
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

contract AuctionPlace is Context,AccessControlEnumerable{

    address immutable moneyTokenAddr;
    address immutable nftAddr;

    struct Auction{
        uint256 tokenId; //nft token id
        address beneficiary;
        uint auctionEndTime;

        address highestBidder;
        uint highestBid;
        bool ended;
    }

    // Events that will be emitted on changes.
    event HighestBidIncreased(uint256 tokenId,address bidder, uint amount);
    event AuctionEnded(uint256 tokenId,address winner, uint amount);

    mapping(uint256/*tokenId*/=>Auction[]) public auctions;

    mapping(uint256/*tokenId*/=>mapping(address => uint/*price*/)) pendingReturns;

    constructor(address nftAddr_,address moneyTokenAddr_){
        moneyTokenAddr=moneyTokenAddr_;
        nftAddr=nftAddr_;
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

    function startAnAuction(uint256 tokenId,uint biddingTime_, address beneficiary_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AuctionPlace: must have admin role to startAnAuction");
        require(ERC721(nftAddr).ownerOf(tokenId)== beneficiary_,"AuctionPlace: NFT does not belong to the beneficiary");
        require(!hasRunningAuction(tokenId),"AuctionPlace: already auctions going on");

        auctions[tokenId].push(Auction(tokenId, beneficiary_,block.timestamp + biddingTime_,address(0),0,false));

        ERC721(nftAddr).transferFrom(beneficiary_,address(this),tokenId);
    }

    function bid(uint256 tokenId,uint256 price) public {
        require(hasRunningAuction(tokenId),"AuctionPlace: Auction not started");
        Auction[] storage aucts=auctions[tokenId];
        Auction storage currAction=aucts[aucts.length-1];

        require(block.timestamp <= currAction.auctionEndTime, "AuctionPlace: The auction has already ended.");

        require(price >= currAction.highestBid, "AuctionPlace: There's already a higher bid. Try bidding higher!");


        if(currAction.highestBid != 0) {
            pendingReturns[tokenId][currAction.highestBidder] += currAction.highestBid;
        }

        currAction.highestBidder = _msgSender();
        currAction.highestBid = price;

        ERC20(moneyTokenAddr).transferFrom(_msgSender(),address(this),price);

        emit HighestBidIncreased(tokenId,_msgSender(), price);
    }

    function withdraw(uint256 tokenId) public {
        uint amount = pendingReturns[tokenId][_msgSender()];

        if(amount > 0) {
            require(ERC20(moneyTokenAddr).balanceOf(address(this))>=amount,"AuctionPlace: no enough money");
            pendingReturns[tokenId][_msgSender()] = 0;
            ERC20(moneyTokenAddr).transfer(_msgSender(),amount);
        }
    }

    function auctionEnd(uint256 tokenId) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AuctionPlace: must have admin role to startAnAuction");

        require(hasRunningAuction(tokenId),"");

        Auction[] storage aucts=auctions[tokenId];
        Auction storage currAction=aucts[aucts.length-1];


        // Conditions
        require(block.timestamp >= currAction.auctionEndTime, "AuctionPlace: The auction hasn't ended yet.");
        require(!currAction.ended, "AuctionPlace: auctionEnd has already been called.");

        // Effects
        currAction.ended = true;
        emit AuctionEnded(tokenId,currAction.highestBidder, currAction.highestBid);

        // Interaction
        ERC20(moneyTokenAddr).transfer(currAction.beneficiary,currAction.highestBid);
        ERC721(nftAddr).transferFrom(address(this),currAction.highestBidder,tokenId);
    }
}
