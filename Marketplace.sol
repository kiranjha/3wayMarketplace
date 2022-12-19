//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract Marketplace is ReentrancyGuard {
    //STATE VARIABLES
    struct Listing {
        uint256 price;
        address seller;
    }
    mapping(address => mapping(uint256 => Listing)) private f_listings;

    struct EngListing {
        uint256 basePrice;
        address seller;
        uint256 startAt;
        uint256 endAt;
    }
    mapping(address => mapping(uint256 => EngListing)) private e_listings;

    struct DutchListing {
        uint256 startPrice;
        uint256 endPrice;
        uint256 discountRate;
        address seller;
        uint256 startAt;
        uint256 endAt;
        uint256 duration;
    }
    mapping(address => mapping(uint256 => DutchListing)) private d_listings;

    //CANCELLED
    mapping(address => mapping(uint256 => bool)) public CancelledEngAuction;
    mapping(address => mapping(uint256 => bool)) public CancelledFixedPriceMarket;
    mapping(address => mapping(uint256 => bool)) public CancelledDutchAuction;

    //ENGLISH AUCTION VARIABLES
    struct Bidding {
        address[] previousBidder;
        uint256[] previousBid;
        address highestBidder;
        uint256 highestBid;
    }
    mapping(address => mapping(uint256 => Bidding)) private bidding;
    // mapping(address => mapping(uint256 => mapping(address => uint256))) public bids;    //per person bids

    //DUTCH AUCTION VARIABLES
    // uint256 public immutable startPrice = 10 ether;
    // uint256 public immutable startAt;
    // uint256 public immutable endsAt;
    // uint256 public immutable endPrice = 5 ether;
    // uint256 public immutable discountRate = 1 ether;
    // uint256 public duration = 5 minutes;

    //EVENTS
    //Fixed Listing Event
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    //English Listing Event
    event EngItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed nftId,
        uint256 basePrice,
        uint256 startAt,
        uint256 endAt
    );
    event Bid(
        address indexed nftAddress,
        uint256 indexed nftId,
        address indexed highestBidder,
        uint256 highestBid
    );
    event EndAuction(
        address indexed nftAddress,
        uint256 indexed nftId,
        address indexed highestBidder,
        uint256 highestBid
    );
    //Dutch Listing Event
    event DutchItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed nftId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 discountRate,
        uint256 startAt,
        uint256 endAt,
        uint256 duration
    );
    //English Listing Event
    event EngListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed nftId,
        uint256 basePrice
    );

    //modifier
    modifier s_notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = f_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier e_notListed(
        address nftAddress,
        uint256 nftId,
        address owner
    ) {
        EngListing memory eng_listing = e_listings[nftAddress][nftId];
        if (eng_listing.basePrice > 0) {
            revert AlreadyListed(nftAddress, nftId);
        }
        _;
    }
    modifier e_isOwner(
        address nftAddress,
        uint256 nftId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(nftId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    //ADD LISTING at FIXED PRICE
    function addItem(address _nftAddress, uint256 _tokenId, uint256 _price) 
    external 
    s_notListed(_nftAddress, _tokenId, msg.sender)
    isOwner(_nftAddress, _tokenId, msg.sender) {
        if(_price <= 0) {
            revert PriceMustBeAboveZero();
        }

        IERC721 nft = IERC721(_nftAddress);
        if(nft.getApproved(_tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        f_listings[_nftAddress][_tokenId] = Listing(_price, msg.sender);
        emit ItemListed(msg.sender, _nftAddress, _tokenId, _price);
    }
    //ADD LISTING IN ENGLISH AUCTION
    function addEngAuction(address _nftAddress, uint256 _nftId, uint256 _startingBid, uint256 _startAt, uint256 _endAt) 
    external
     {

        //  e_notListed(_nftAddress, _nftId, msg.sender)
        // e_isOwner(_nftAddress, _nftId, msg.sender)
        if(_startingBid <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(_nftAddress);
        if(nft.getApproved(_nftId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        e_listings[_nftAddress][_nftId] = EngListing(_startingBid, msg.sender, _startAt, _endAt);
        // bidding[_nftAddress][_nftId] = Bidding(previousBidder.push(0),previousBids.push(0),address(0), _startingBid);

        emit EngItemListed(msg.sender, _nftAddress, _nftId, _startingBid, _startAt, _endAt);
    }
    //ADD LISTING IN DUTCH AUCTION
    function addDutchAuction(address _nftAddress, uint256 _nftId, uint256 _startPrice, uint256 _endPrice, uint256 _discountRate, uint256 _startAt, uint256 _endAt, uint256 _duration) external {
        if(_startPrice <= 0 && _endPrice <= 0 && _discountRate <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(_nftAddress);
        if(nft.getApproved(_nftId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        d_listings[_nftAddress][_nftId] = DutchListing(_startPrice, _endPrice, _discountRate, msg.sender, _startAt, _endAt, _duration);
        emit DutchItemListed(msg.sender, _nftAddress, _nftId, _startPrice, _endPrice, _discountRate, _startAt, _endAt, _duration);
    }

    //CANCEL FIXED LISTING
    function delListing(address _nftAddress, uint256 _nftId)
        external
        isOwner(_nftAddress, _nftId, msg.sender)
        isListed(_nftAddress, _nftId)
    {
        delete (f_listings[_nftAddress][_nftId]);
        CancelledFixedPriceMarket[_nftAddress][_nftId] = true;
        emit ItemDeleted(msg.sender, _nftAddress, _nftId);
    }
    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = f_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }
    event ItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // CANCEL ENGLISH LISTING
    function delEngListing(address _nftAddress, uint256 _nftId)
        external
        isOwner(_nftAddress, _nftId, msg.sender)
        e_isListed(_nftAddress, _nftId)
    {
        delete (e_listings[_nftAddress][_nftId]);
        CancelledEngAuction[_nftAddress][_nftId] = true;
        emit e_ItemDeleted(msg.sender, _nftAddress, _nftId);
    }
    modifier e_isListed(address _nftAddress, uint256 _nftId) {
        EngListing memory e_listing = e_listings[_nftAddress][_nftId];
        if (e_listing.basePrice <= 0) {
            revert NotListed(_nftAddress, _nftId);
        }
        _;
    }
    event e_ItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    //CANCEL DUTCH AUCTION
    function delDutchListing(address _nftAddress, uint256 _nftId)
        external
        d_isListed(_nftAddress, _nftId)
    {
        delete (d_listings[_nftAddress][_nftId]);
        CancelledDutchAuction[_nftAddress][_nftId] = true;
        emit d_ItemDeleted(msg.sender, _nftAddress, _nftId);
    }
    modifier d_isListed(address _nftAddress, uint256 _nftId) {
        DutchListing memory d_listing = d_listings[_nftAddress][_nftId];
        if (d_listing.startPrice <= 0 && d_listing.endPrice <= 0) {
            revert NotListed(_nftAddress, _nftId);
        }
        _;
    }
    event d_ItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );   

    // BID
    function bidFor(address _nftAddress, uint256 _nftId) external payable {
        //require(!CancelledEngAuction[_nftAddress][_nftId],"AUCTION CANCELLED");
        EngListing memory e_listing = e_listings[_nftAddress][_nftId];
        require(e_listing.startAt < block.timestamp && e_listing.endAt >= block.timestamp);
        require(msg.value > e_listing.basePrice, "value must be greater than basePrice!");
        if(bidding[_nftAddress][_nftId].highestBidder == address(0)) {
            bidding[_nftAddress][_nftId].highestBidder = msg.sender;
            bidding[_nftAddress][_nftId].highestBid = msg.value;
        }
        
        if(bidding[_nftAddress][_nftId].highestBidder != address(0)) {
            require(msg.value > bidding[_nftAddress][_nftId].highestBid, "value is less than highest bid!");
            bidding[_nftAddress][_nftId].previousBidder.push(bidding[_nftAddress][_nftId].highestBidder);
            bidding[_nftAddress][_nftId].previousBid.push(bidding[_nftAddress][_nftId].highestBid);
            bidding[_nftAddress][_nftId].highestBidder = msg.sender;
            bidding[_nftAddress][_nftId].highestBid = msg.value;
        }
        emit Bid(_nftAddress, _nftId, msg.sender, msg.value);
    } 
    //END by owner to send nftId and send bid's amount back to participants
    function end(address _nftAddress, uint256 _nftId) external{
        require(block.timestamp < e_listings[_nftAddress][_nftId].startAt,"Auction has not Started!");
        require(block.timestamp >= e_listings[_nftAddress][_nftId].endAt || CancelledEngAuction[_nftAddress][_nftId],"Please wait till Auction is Expired!");
        IERC721(_nftAddress).safeTransferFrom(e_listings[_nftAddress][_nftId].seller,bidding[_nftAddress][_nftId].highestBidder,_nftId);
        payable(e_listings[_nftAddress][_nftId].seller).transfer(bidding[_nftAddress][_nftId].highestBid);  
        emit EndAuction(_nftAddress, _nftId, bidding[_nftAddress][_nftId].highestBidder, bidding[_nftAddress][_nftId].highestBid);
    }

    function getFixedListing(address _nftAddress, uint256 _nftId) external view returns (Listing memory)
    {
        return f_listings[_nftAddress][_nftId];
    }

    function getEngAuctionListing(address _nftAddress, uint256 _nftId) external view returns (EngListing memory)
    {
        return e_listings[_nftAddress][_nftId];
    }

    function getDutchAuctionListing(address _nftAddress, uint256 _nftId) external view returns (DutchListing memory)
    {
        return d_listings[_nftAddress][_nftId];
    }
    
} 
