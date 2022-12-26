//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract Marketplace is ReentrancyGuard {
    //Fixed Listing structure and Mapping
    struct Listing {
        uint256 price;
        address seller;
    }
    mapping(address => mapping(uint256 => Listing)) private f_listings;

    //English Aucton Structure and Mapping
    struct EngListing {
        uint256 basePrice;
        address seller;
        uint256 startAt;
        uint256 endAt;
    }
    mapping(address => mapping(uint256 => EngListing)) private e_listings;

    //Dutch Auction Structure and Mapping
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
    mapping(address => mapping(uint256 => bool)) private CancelledEngAuction;
    mapping(address => mapping(uint256 => bool)) private CancelledFixedPriceMarket;
    mapping(address => mapping(uint256 => bool)) private CancelledDutchAuction;

    //ENGLISH AUCTION VARIABLES
    struct Bidding {
        address[] previousBidder;
        uint256[] previousBid;
        address highestBidder;
        uint256 highestBid;
    }
    mapping(address => mapping(uint256 => Bidding)) private bidding;

    //EVENTS
    //Fixed Listing Event
    event f_ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event f_ItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event f_ItemBought(
        address indexed buyer,
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
    event EngItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event Bid(
        address indexed nftAddress,
        uint256 indexed nftId,
        address indexed highestBidder,
        uint256 highestBid
    );
    event EndEngAuction(
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
    event d_ItemDeleted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed nftId
    );
    event d_ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    //Fixed Listing modifier
    modifier f_notListed(
        address nftAddress,
        uint256 nftId,
        address owner
    ) {
        // Listing memory listing = f_listings[nftAddress][tokenId];
        if (f_listings[nftAddress][nftId].price > 0) {
            revert AlreadyListed(nftAddress, nftId);
        }
        _;
    }
    modifier f_isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        // IERC721 nft = IERC721(nftAddress);
        address owner = IERC721(nftAddress).ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }
    modifier f_isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = f_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    //English Listing Modifiers
    modifier e_notListed(
        address nftAddress,
        uint256 nftId,
        address owner
    ) {
        if(e_listings[nftAddress][nftId].basePrice > 0) {
            revert AlreadyListed(nftAddress, nftId);
        }
        _;
    }
    modifier e_isOwner(
        address nftAddress,
        uint256 nftId,
        address spender
    ) {
        address owner = IERC721(nftAddress).ownerOf(nftId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }
    modifier e_isListed(address _nftAddress, uint256 _nftId) {
        EngListing memory e_listing = e_listings[_nftAddress][_nftId];
        if (e_listing.basePrice <= 0) {
            revert NotListed(_nftAddress, _nftId);
        }
        _;
    }

    //Dutch Listing Modifiers
    modifier d_notListed(
        address nftAddress,
        uint256 nftId,
        address owner
    ) {
        if (d_listings[nftAddress][nftId].startPrice > 0) {
            revert AlreadyListed(nftAddress, nftId);
        }
        _;
    }
    modifier d_isOwner(
        address nftAddress,
        uint256 nftId,
        address spender
    ) {
        address owner = IERC721(nftAddress).ownerOf(nftId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }
    modifier d_isListed(address _nftAddress, uint256 _nftId) {
        DutchListing memory d_listing = d_listings[_nftAddress][_nftId];
        if (d_listing.startPrice <= 0 && d_listing.endPrice <= 0) {
            revert NotListed(_nftAddress, _nftId);
        }
        _;
    }

    //ADD LISTING at FIXED PRICE
    function addItem(
        address _nftAddress,
        uint256 _nftId,
        uint256 _price
    )
        external
        f_notListed(_nftAddress, _nftId, msg.sender)
        f_isOwner(_nftAddress, _nftId, msg.sender)
    {
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }

        IERC721 nft = IERC721(_nftAddress);
        if (nft.getApproved(_nftId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        f_listings[_nftAddress][_nftId] = Listing(_price, msg.sender);
        emit f_ItemListed(msg.sender, _nftAddress, _nftId, _price);
    }

    //ADD LISTING IN ENGLISH AUCTION
    function addEngAuction(
        address _nftAddress,
        uint256 _nftId,
        uint256 _startingBid,
        uint256 _startAt,
        uint256 _endAt
    ) external 
    // f_notListed(_nftAddress, _nftId, msg.sender) 
    e_notListed(_nftAddress, _nftId, msg.sender) 
    e_isOwner(_nftAddress, _nftId, msg.sender) {
         
        if (_startingBid <= 0) {
            revert PriceMustBeAboveZero();
        }
        // IERC721 nft = IERC721(_nftAddress);
        if (IERC721(_nftAddress).getApproved(_nftId) != address(this)) {
            revert NotApprovedForMarketplace();
        }        
        e_listings[_nftAddress][_nftId] = EngListing(_startingBid, msg.sender, _startAt, _endAt);        
        emit EngItemListed(
            msg.sender,
            _nftAddress,
            _nftId,
            _startingBid,
            _startAt,
            _endAt
        );
    }

    //ADD LISTING IN DUTCH AUCTION
    function addDutchAuction(
        address _nftAddress,
        uint256 _nftId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _startAt,
        uint256 _endAt
    ) external 
        // d_notListed(_nftAddress, _nftId, msg.sender)
        d_isOwner(_nftAddress, _nftId, msg.sender) {
        if (_startPrice <= 0 && _endPrice <= 0) {
            revert PriceMustBeAboveZero();
        }
        if (IERC721(_nftAddress).getApproved(_nftId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        d_listings[_nftAddress][_nftId] = DutchListing(_startPrice, _endPrice, (_startPrice - _endPrice)/(_endAt - _startAt), msg.sender, _startAt, _endAt, (_endAt - _startAt));
        emit DutchItemListed(
            msg.sender,
            _nftAddress,
            _nftId,
            _startPrice,
            _endPrice,
            ((_startPrice-_endPrice)/(_endAt-_startAt)),
            _startAt,
            _endAt,
            (_endAt-_startAt)
        );
    }

    //CANCEL FIXED LISTING
    function delListing(address _nftAddress, uint256 _nftId)
        external
        f_isOwner(_nftAddress, _nftId, msg.sender)
        f_isListed(_nftAddress, _nftId)
    {
        delete (f_listings[_nftAddress][_nftId]);
        CancelledFixedPriceMarket[_nftAddress][_nftId] = true;
        emit f_ItemDeleted(msg.sender, _nftAddress, _nftId);
    }

    // CANCEL ENGLISH LISTING
    function delEngListing(address _nftAddress, uint256 _nftId)
        external
        e_isOwner(_nftAddress, _nftId, msg.sender)
        e_isListed(_nftAddress, _nftId)
    {
        // require(bidding[_nftAddress][_nftId].highestBidder != address(0),"there is already a bidder in auction");
        delete (e_listings[_nftAddress][_nftId]);
        CancelledEngAuction[_nftAddress][_nftId] = true;
        emit EngItemDeleted(msg.sender, _nftAddress, _nftId);
    }

    //CANCEL DUTCH AUCTION
    function delDutchListing(address _nftAddress, uint256 _nftId)
        external
        d_isOwner(_nftAddress, _nftId, msg.sender)
        d_isListed(_nftAddress, _nftId)
    {
        delete (d_listings[_nftAddress][_nftId]);
        CancelledDutchAuction[_nftAddress][_nftId] = true;
        emit d_ItemDeleted(msg.sender, _nftAddress, _nftId);
    }

    //buy nft at fixed price set by the seller
    function buyItemAtFixed(address _nftAddress, uint256 _nftId) external payable nonReentrant f_isListed(_nftAddress, _nftId) {
        Listing memory listedItem = f_listings[_nftAddress][_nftId];
        if(msg.value < listedItem.price) {
            revert PriceNotMet(_nftAddress,_nftId,listedItem.price);
        }
        IERC721(_nftAddress).safeTransferFrom(listedItem.seller, msg.sender, _nftId);
        (bool success, ) = payable(listedItem.seller).call{value: msg.value}("");
        require(success, "Transfer Failed!");
        emit f_ItemBought(msg.sender, _nftAddress, _nftId, listedItem.price);
        delete(f_listings[_nftAddress][_nftId]);

    }

    // BID
    function bidFor(address _nftAddress, uint256 _nftId) external payable e_isListed(_nftAddress, _nftId) {
        require(!CancelledEngAuction[_nftAddress][_nftId],"AUCTION CANCELLED");
        EngListing memory e_listing = e_listings[_nftAddress][_nftId];
        require(e_listing.startAt < block.timestamp && e_listing.endAt >= block.timestamp, "reverted!");
        require(
            msg.value > e_listing.basePrice,
            "value must be greater than basePrice!"
        );
        if (bidding[_nftAddress][_nftId].highestBidder != address(0)) {
            require(
                msg.value > bidding[_nftAddress][_nftId].highestBid,
                "value is less than highest bid!"
            );
            bidding[_nftAddress][_nftId].previousBidder.push(
                bidding[_nftAddress][_nftId].highestBidder
            );
            bidding[_nftAddress][_nftId].previousBid.push(
                bidding[_nftAddress][_nftId].highestBid
            );
            bidding[_nftAddress][_nftId].highestBidder = msg.sender;
            bidding[_nftAddress][_nftId].highestBid = msg.value;
        }
        if (bidding[_nftAddress][_nftId].highestBidder == address(0)) {
            bidding[_nftAddress][_nftId].highestBidder = msg.sender;
            bidding[_nftAddress][_nftId].highestBid = msg.value;
        }
        emit Bid(_nftAddress, _nftId, msg.sender, msg.value);
    }

    //END function only called by owner to send nftId to highestBidder, nftAmount to seller and send bid's amount back to participants
    function end(address _nftAddress, uint256 _nftId) external e_isOwner(_nftAddress, _nftId, msg.sender) {
        // require(
        //     block.timestamp < e_listings[_nftAddress][_nftId].startAt,
        //     "Auction has not Started!"
        // );
        require(
            block.timestamp >= e_listings[_nftAddress][_nftId].endAt ||
                CancelledEngAuction[_nftAddress][_nftId],
            "Please wait till Auction is Expired!"
        );
        IERC721(_nftAddress).safeTransferFrom(
            e_listings[_nftAddress][_nftId].seller,
            bidding[_nftAddress][_nftId].highestBidder,
            _nftId
        );
        payable(e_listings[_nftAddress][_nftId].seller).transfer(
            bidding[_nftAddress][_nftId].highestBid
        );
        uint256 transactionCount = 0;
        for(uint256 i = 0; i < bidding[_nftAddress][_nftId].previousBidder.length; i++) {
            (bool success,) = bidding[_nftAddress][_nftId].previousBidder[i].call{value: bidding[_nftAddress][_nftId].previousBid[i]}("");
            require(success,"Transfer Failed");
            transactionCount++;
        }
        emit EndEngAuction(
            _nftAddress,
            _nftId,
            bidding[_nftAddress][_nftId].highestBidder,
            bidding[_nftAddress][_nftId].highestBid
        );
        delete(e_listings[_nftAddress][_nftId]);
    }

    //price function to get the current price of item in dutch auction
    function dutchPrice(address _nftAddress, uint256 _nftId) public view returns (uint256) {
        if(block.timestamp >= d_listings[_nftAddress][_nftId].endAt) {
            return d_listings[_nftAddress][_nftId].endPrice;
        }
        uint256 elapsedTime = (block.timestamp - d_listings[_nftAddress][_nftId].startAt)/60;
        uint256 discount = elapsedTime * d_listings[_nftAddress][_nftId].discountRate;
        uint256 currentPrice = (d_listings[_nftAddress][_nftId].startPrice - discount);
        return currentPrice;
    }

    //buy item at current price 
    function buyFromDutch(address _nftAddress, uint256 _nftId) external payable {
        require(block.timestamp <= d_listings[_nftAddress][_nftId].endAt, "Dutch Auction Expired!");
        uint256 currentPrice = dutchPrice(_nftAddress,_nftId);
        require(msg.value >= currentPrice, "Eth is less than price");
        IERC721(_nftAddress).safeTransferFrom(d_listings[_nftAddress][_nftId].seller, msg.sender, _nftId);
        uint256 refund = msg.value - currentPrice; 
        if(refund > 0) {
            (bool refundSent, ) = payable(msg.sender).call{value: refund}("");
            require(refundSent, "Refund Transfer Failed!");
            //payable(msg.sender).transfer(refund);
        }  
        (bool success, ) = payable(d_listings[_nftAddress][_nftId].seller).call{value: msg.value}("");
        require(success, "Transfer Failed!");
        //payable(d_listings[_nftAddress][_nftId].seller).transfer(msg.value);
        emit d_ItemBought(msg.sender,_nftAddress,_nftId,msg.value);
        delete(d_listings[_nftAddress][_nftId]);
    }

    //Getter functions to reduce gas fees
    function isCancelledFixedPriceItem(address _nftAddress, uint256 _nftId) external view f_isListed(_nftAddress, _nftId) returns(bool) {
        return CancelledFixedPriceMarket[_nftAddress][ _nftId];
    }
    function isCancelledEngAuction(address _nftAddress, uint256 _nftId) external view e_isListed(_nftAddress, _nftId) returns(bool) {
        return CancelledEngAuction[_nftAddress][_nftId];
    }
    function isCancelledDutchAuction(address _nftAddress, uint256 _nftId) external view d_isListed(_nftAddress, _nftId) returns(bool) {
        return CancelledDutchAuction[_nftAddress][_nftId];
    }
    function getFixedListing(address _nftAddress, uint256 _nftId) external view returns (Listing memory) {
        return f_listings[_nftAddress][_nftId];
    }
    function getEngAuctionListing(address _nftAddress, uint256 _nftId)
        external
        view
        returns (EngListing memory)
    {
        return e_listings[_nftAddress][_nftId];
    }
    function getDutchAuctionListing(address _nftAddress, uint256 _nftId)
        external
        view
        returns (DutchListing memory)
    {
        return d_listings[_nftAddress][_nftId];
    }
    function getHighestBid(address _nftAddress, uint256 _nftId)
        external
        view
        returns (Bidding memory)
    {
        return bidding[_nftAddress][_nftId];
    }
}
