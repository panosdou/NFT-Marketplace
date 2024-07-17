// SPDX-License-Identifier: UNLICENSED
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../interfaces/ITicketNFT.sol";
import "./TicketNFT.sol";
import "./PurchaseToken.sol";


contract SecondaryMarket is ISecondaryMarket {

    PurchaseToken private purchaseToken; //initialize the purchaseToken variable which is of type PurchaseToken and will be the currency used for the primary market.

    constructor(PurchaseToken _Token) {
        purchaseToken = PurchaseToken(_Token);
    }

    struct ListingInfo{ //create a structure that keeps the information relative to the Listing of a ticket such as the address of the holder, address of the collection, the ticketID, the price the owner is asking for, and wether the listing is active or not. The last boolean will be needed if a user wants to delist their listing 
        address holder;
        address collection;
        uint256 ticketId;
        uint256 price;
        bool isAvailable;
    }
    
    
    struct BidInfo { //define a structure that keeps the information regarding a bid for a ticket that has been listed. newName is the name that the ticket will have if the bid is accepted. It is not necceseraly the same as the name of the bidder, because the bidder might want to gift said ticket to someone else.
        address bidder;
        address collection;
        uint256 ticketId;
        uint256 bid;
        string newName;
    }

    mapping(address => mapping(uint256 => ListingInfo)) private ticketListings; // mapping from ticketcollection address to another mapping from ticketID to a ListingInfo structure corresponding to the listing for that ticketID.
    mapping(address => mapping(uint256 => BidInfo)) private Bids; // mapping from ticketcollection address to another mapping from ticketID to a BidInfo structure corresponding to a bid for that ticketID from that ticketCollection.

    function BidExists(address ticketCollection, uint256 ticketID) public view returns (bool){
        return ((Bids[ticketCollection][ticketID].bidder != address(0)));
    }

    function listTicket(address ticketCollection, uint256 ticketID, uint256 price) external override {
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection); //get the instance of the ITicketNFT contract associated with that address.
        require(!(ticketNFT.isExpiredOrUsed(ticketID)), "This ticket is no longer valid. It has either expired or has already been redeemed. Please list a valid ticket"); // makes sure that no expired or used ticket can be listed
        require(ticketNFT.holderOf(ticketID) == msg.sender ,"The caller of the function is not the owner of this ticket "); //require that only the address that owns the ticket can list it

        ticketListings[ticketCollection][ticketID] = ListingInfo(msg.sender, ticketCollection, ticketID, price, true); //map from ticketCollection address to the ticketID inside that collection which maps to a ListingInfo structure
        ticketNFT.transferFrom(msg.sender, address(this), ticketID); //transfers the ticketNFT from the owner to the address of the secondary market contract after listing as outlined in the spec.  
        Bids[ticketCollection][ticketID] = BidInfo(address(0),ticketCollection, ticketID, price, "NULL"); //initialize empty bid for this listing coming from the 0 address for a value of the asking price. This empty bid will be used to differentiate wether a bid has been made for the listing or not.

        emit Listing(msg.sender, ticketCollection, ticketID, price);
    }

    function submitBid(address ticketCollection, uint256 ticketID, uint256 bidAmount, string calldata name) external override {
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
        require(ticketListings[ticketCollection][ticketID].isAvailable, "This listing is no longer available"); //fetch the ListingInfo type variable using the ticketCollection and ticketID keys of the mapping.
        //require(bidAmount >= ticketListings[ticketCollection][ticketID].price, "The bid needs to be greater or equal to the asking price "); // make sure that no bids are below the asking price, dont need anymore since I initialize the first bid to be equal to the asking price anyway 
        require(bidAmount > Bids[ticketCollection][ticketID].bid, "The bid needs to be greater than the last bid");
        require(!ticketNFT.isExpiredOrUsed(ticketID), "This ticket is no longer valid. It has either expired or has already been redeemed");
 
        if(BidExists(ticketCollection,ticketID)){ //if there has been a bid before, the secondary market place needs to return the purchaseTokens to the previous bidder.
            purchaseToken.transfer(Bids[ticketCollection][ticketID].bidder, Bids[ticketCollection][ticketID].bid);
        }
    
        purchaseToken.transferFrom(msg.sender, address(this), bidAmount);
        Bids[ticketCollection][ticketID] = BidInfo(msg.sender,ticketCollection, ticketID, bidAmount, name);//overwrite the previous largest bid with the bid which was just submitted, Keep in mind, it is only saving the highest bid at all times.

        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount, name);
    }

    function getHighestBid(address ticketCollection, uint256 ticketID) external view override returns (uint256) {
        require(ticketListings[ticketCollection][ticketID].isAvailable, "This listing is no longer available");
        return Bids[ticketCollection][ticketID].bid;
    }

    function getHighestBidder(address ticketCollection, uint256 ticketID) external view override returns (address) {
        require(ticketListings[ticketCollection][ticketID].isAvailable, "This listing is no longer available");
        return Bids[ticketCollection][ticketID].bidder;
    }

    function acceptBid(address ticketCollection, uint256 ticketID) external override {
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
        require(BidExists(ticketCollection,ticketID), "There have been no bids submitted yet for this listing");
        require(ticketListings[ticketCollection][ticketID].isAvailable, "This listing is no longer available");
        require(ticketListings[ticketCollection][ticketID].holder == msg.sender, "Only the holder of a listing can accept a bid");
        require(!ticketNFT.isExpiredOrUsed(ticketID), "This ticket is no longer valid. It has either expired or has already been redeemed");

        uint256 fee = (Bids[ticketCollection][ticketID].bid * 0.05e18) / 1e18; //calculates a fee which is always equal to 5% of the bid we accept. Notice that Bids[ticketCollection][ticketID] will always contain the BidInfo structure for the highest bid
        purchaseToken.transfer(ticketListings[ticketCollection][ticketID].holder, Bids[ticketCollection][ticketID].bid - fee); //transfer 95% of the aaccepted bid to the holder of the listing
        purchaseToken.transfer(ticketNFT.creator(), fee); //send the creator of the collection the 5% fee
        ticketNFT.updateHolderName(ticketID, Bids[ticketCollection][ticketID].newName); //update the ticket information
        ticketNFT.transferFrom(address(this), Bids[ticketCollection][ticketID].bidder, ticketID);
        ticketListings[ticketCollection][ticketID].isAvailable = false; //set the listing as unavailable

        emit BidAccepted(Bids[ticketCollection][ticketID].bidder, Bids[ticketCollection][ticketID].collection, Bids[ticketCollection][ticketID].ticketId, Bids[ticketCollection][ticketID].bid, Bids[ticketCollection][ticketID].newName);
    }

    function delistTicket(address ticketCollection, uint256 ticketID) external override {
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
        require(ticketListings[ticketCollection][ticketID].holder == msg.sender, "Only the holder of a listing can delist");
        require(ticketListings[ticketCollection][ticketID].isAvailable, "This listing is no longer available");
    
        ticketListings[ticketCollection][ticketID].isAvailable = false; //set the listing to unavailable.
        ticketNFT.transferFrom(address(this), msg.sender, ticketID); // send the money back to the person who listed the ticket. ticketListings[ticketCollection][ticketID].holder == msg.sender
        if(BidExists(ticketCollection,ticketID)){ //if there has been a bid before, the secondary market place needs to return the purchaseTokens to the previous bidder.
            purchaseToken.transfer(Bids[ticketCollection][ticketID].bidder, Bids[ticketCollection][ticketID].bid);
        }
        

        emit Delisting(ticketCollection, ticketID);
    }
}