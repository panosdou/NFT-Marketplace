// SPDX-License-Identifier: UNLICENSED
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.10;

import "../interfaces/ITicketNFT.sol";


contract TicketNFT is ITicketNFT {

    struct Ticket {
        uint256 ticketIdentifier;
        string holderName;
        bool used;
    }

    string public eventTitle; // String containing the event name
    uint256 private currTicketId = 1;  // Keeps track of the current tivket Id, starting from the number 1.
    address private eventAdmin; // This is the adress of the person who creates the event by calling CreateNewEvent in the primary market
    uint256 public maxTickets; // The maximum number of tickets that can be minted, specified by the admin of the event.
    uint256 private initiatedAt; // The time the contract was initiated.
    address private primaryMarket; //The adress of the primary market that initiated this contract. Users should  be allowed to mint ticketNFTs only through this primary market
    mapping(uint256 => Ticket) private ticketList; // Mapping from ticket ID to a Ticket list.
    mapping(uint256 => address) private ticketHolders;  // Mapping from ticket ID to a list that contains the adresses of all ticket holders
    mapping(address => uint256) private balances; // Mapping from the adress of a holder to the amoount of tickets they hold
    mapping(uint256 => address) private approvedAddress; // Mapping from ticket ID to  a list that contains the approved adresses of all ticket holders .


    constructor(string memory name, uint256 ticketsAmmount, address admin, address market) {
        eventTitle = name; 
        maxTickets = ticketsAmmount; // max number of tickets specified by the person who creates this contract
        eventAdmin = admin; // set the eventAdmin to the adress that created the contract
        primaryMarket = market; //set the address of the primary market this ticketNFT is initialized at.
        initiatedAt = block.timestamp; //set the time the contract was initiated to the time in seconds when the contract is created
    }

    function creator() external view override returns (address) {
        return eventAdmin;
    }

    function maxNumberOfTickets() external view override returns (uint256) {
        return maxTickets;
    }

     function eventName() external view override returns (string memory) {
        return eventTitle;
    }

     function getInitiationTime() private view  returns (uint256) {
        return initiatedAt;
    }

    modifier onlyAdmin() { // Modifier for functions only to be accesible by the admin of the event.
        require(eventAdmin == msg.sender, "Only the admin of this event can access this function");
        _; 
    }

    function mint(address holder, string memory holderName) external override returns (uint256) { //function for the admin of an event to mint a ticket. Holder and holdername will be the admin's adress and their name, using the same variable names as the ITicketNFT.sol
        require(currTicketId <= maxTickets, "The maximum ammount of tickets has already been minted");
        require(primaryMarket == msg.sender, "Only the primary market this event was created on can access this function"); //only the primary market should be able to call this function.
        ticketHolders[currTicketId] = holder; 
        ticketList[currTicketId] = Ticket(currTicketId, holderName, false);
        balances[holder] += 1;
        emit Transfer(address(0), holder, currTicketId);

        currTicketId += 1;
        
        return (currTicketId-1); // return the Id of the last ticket that was minted.
    }

    function balanceOf(address holder) external view override returns (uint256 balance) { //initializing variable since gas efficiency is not a consideration and this is the way the function is defined in the interface. Normally it's not gas efficient to initialize redundant variables.
        balance = balances[holder];
        return balance;
    }

    function holderOf(uint256 ticketID) external view override returns (address holder) { //same as earlier, we do not have to initialize this variable
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");
        holder = ticketHolders[ticketID];
        return holder;
    }

    function transferFrom(address from, address to, uint256 ticketID) external override {
        require(from != address(0), "Cannot transfer from the zero address");
        require(to != address(0), "Cannot transfer to the zero address");
        require(ticketHolders[ticketID] == from, "The caller of this function does not own the ticket");
        require(from == msg.sender || approvedAddress[ticketID] == msg.sender,"The caller of the function is not the owner of this ticket and they have not been approved to transfer this ticket");

        ticketHolders[ticketID] = to;
        balances[from] -= 1;
        balances[to] += 1;
        approvedAddress[ticketID] = address(0); // reset any approved addresses to none.
        
        emit Approval(from, address(0), ticketID); // emit that the only approved address is address(0)
        emit Transfer(from, to, ticketID); //emit that the ticket had been transferred.
         
    }

    function approve(address to, uint256 ticketID) external override {
        require(ticketHolders[ticketID] == msg.sender, "The caller of this function does not own the ticket");
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");

        approvedAddress[ticketID] = to;

        emit Approval(msg.sender, to, ticketID);
    }

    function getApproved(uint256 ticketID) external view override returns (address operator) {
         require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");

        operator = approvedAddress[ticketID];
        
        return operator;
    }

    function holderNameOf(uint256 ticketID) external view override returns (string memory) {
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");

        return ticketList[ticketID].holderName;
    }

    function updateHolderName(uint256 ticketID, string calldata newName) external override {
        require(ticketHolders[ticketID] == msg.sender, "The caller of this function does not own the ticket");
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");
        
        ticketList[ticketID].holderName = newName;
    }

    function setUsed(uint256 ticketID) external override onlyAdmin{
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");
        require(!(ticketList[ticketID].used), "The specified ticket has already been used"); //the ticket must not already be used
        require((block.timestamp - initiatedAt) < 864000, "This ticket has expired"); //get the current time in seconds and compare it to the time the contract was initiated at. The difference has to be less than 864000 seconds, which is 10 days.

        ticketList[ticketID].used = true; 
    }

    function isExpiredOrUsed(uint256 ticketID) external view override returns (bool) {
        require(ticketList[ticketID].ticketIdentifier == ticketID, "The ticket with the specified ticket ID does not exist");
        
        return (ticketList[ticketID].used || (block.timestamp - initiatedAt) >= 864000); //Returns true if the `used` flag associated with a ticket is true or if the ticket has expired
    }
}