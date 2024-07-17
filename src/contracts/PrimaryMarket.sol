// SPDX-License-Identifier: UNLICENSED
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "./PurchaseToken.sol";
import "./TicketNFT.sol";

contract PrimaryMarket is IPrimaryMarket {

    PurchaseToken private purchaseToken; //initialize the purchaseToken variable which is of type PurchaseToken and will be the currency used for the primary market.

    constructor(PurchaseToken _Token) {
        purchaseToken = PurchaseToken(_Token);
    }

    struct Event{ //create a structure called Event that will store the information about the NFT collection created relating to an event.
        string eventName;
        uint256 maxTickets;
        address creator;
        uint256 price;
    }

    mapping(address => Event) private eventList; //create a mapping from ticketNFT addresses to the Event structure defined above in order to save all the different events in the eventList


    function createNewEvent(string memory eventName, uint256 price, uint256 maxNumberOfTickets) external override returns (ITicketNFT ticketCollection) {
        TicketNFT ticketNFT = new TicketNFT(eventName, maxNumberOfTickets, msg.sender, address(this)); // creates a new instance of the contract called ticketNFT with the parameters given by the function.
        eventList[address(ticketNFT)] = Event(ticketNFT.eventName(), ticketNFT.maxNumberOfTickets(), msg.sender, price); //map the adress of the instance that was initiated to an event structure
        
        emit EventCreated(msg.sender, address(ticketNFT), eventName, price, maxNumberOfTickets); //emit that an event has been created
        
        return ITicketNFT(address(ticketNFT));
    }

    function purchase(address ticketCollection,string memory holderName) external override returns (uint256 id) {
        //there is no need to add require statements since the transferFrom and mint function already implements them.
        purchaseToken.transferFrom(msg.sender, eventList[ticketCollection].creator, eventList[ticketCollection].price); //calls the transferFrom function from the PurchaseToken contract to send the creator of the  ticket collection "price" ammount of the purchaseToken instance of the PurchaseToken conract.
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection); //get the instance of the ITicketNFT contract associated wihth that address.
        uint256 ticketId = ticketNFT.mint(msg.sender, holderName);

        emit Purchase(msg.sender, ticketCollection, ticketId, holderName);
        
        return ticketId;
    }

    function getPrice(address ticketCollection) external view override returns (uint256 price) {
        return eventList[ticketCollection].price;
    }

}
