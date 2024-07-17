// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/TicketNFT.sol";
import "../lib/forge-std/src/Test.sol";
import "../src/contracts/PurchaseToken.sol";

contract TicketNFTTest is Test {
    PurchaseToken public purchaseToken;


    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        purchaseToken = new PurchaseToken();

        payable(bob).transfer(3e18);
        payable(charlie).transfer(50e18);

        
    }

    function testTicketNFT() external {
        vm.startPrank(charlie);
        ITicketNFT charlieNFT = new TicketNFT("Charlie's event",1000,charlie,address(this));
        purchaseToken.mint{value: 50e18}();

        assertEq(purchaseToken.balanceOf(charlie), 5000e18);
        assertEq(charlieNFT.creator(), charlie);
        assertEq(charlieNFT.maxNumberOfTickets(), 1000);
        assertEq(charlieNFT.eventName(), "Charlie's event");
        vm.stopPrank();

        vm.prank(alice);
        ITicketNFT aliceNFT = new TicketNFT("Alice's event",2,alice,address(this));
        uint256 time = block.timestamp;
       
        assertEq(purchaseToken.balanceOf(alice), 0);
        assertEq(aliceNFT.creator(), alice);
        assertEq(aliceNFT.maxNumberOfTickets(), 2);
        assertEq(aliceNFT.eventName(), "Alice's event");

        
        vm.startPrank(bob);
        purchaseToken.mint{value: 3e18}();
        assertEq(purchaseToken.balanceOf(bob), 300e18);
        //uint256 id_1 = aliceNFT.mint(bob, "Bob");// fails as it should : "Only the primary market this event was created on can access this function"
        vm.stopPrank();

        vm.startPrank(address(this));

        uint256 id_1 = aliceNFT.mint(bob, "Bob"); //only the address of the primary market should be ableto mint, in this case we set it to the adress of the test contract.
        assertEq(aliceNFT.balanceOf(bob), 1);
        assertEq(aliceNFT.holderOf(id_1), bob);
        assertEq(aliceNFT.holderNameOf(id_1), "Bob");

        uint256 id_2 = aliceNFT.mint(bob, "Bob");
        assertEq(aliceNFT.balanceOf(bob), 2);
        assertEq(aliceNFT.holderOf(id_2), bob);
        assertEq(aliceNFT.holderNameOf(id_2), "Bob");

        // uint256 id_3 = aliceNFT.mint(bob, "Bob"); fails as it should: "The maximum ammount of tickets has already been minted"
        vm.startPrank(alice);
        assertEq(aliceNFT.balanceOf(alice), 0);

        //aliceNFT.transferFrom(address(0), charlie, id_1); //fails as it should: Cannot transfer from the zero address
        //aliceNFT.transferFrom(bob, address(0), id_1); //fails as it should: Cannot transfer to the zero address
        //aliceNFT.transferFrom(bob, alice, id_1); //fails as it should: "The caller of the function is not the owner of this ticket and they have not been approved to transfer this ticket"
        //aliceNFT.transferFrom(alice, charlie, id_1); //fails as it should : The caller of this function does not own the ticket
        //aliceNFT.holderOf(3); //fails as it should: The ticket with the specified ticket ID does not exist
        //aliceNFT.approve(charlie,id_2); //fails as it should: "The caller of this function does not own the ticket"
        //aliceNFT.updateHolderName(id_1, "Alice"); //fails as it should : "The caller of this function does not own the ticket"
        
        vm.stopPrank();

        vm.startPrank(bob);

        aliceNFT.updateHolderName(id_1, "Alice");
        aliceNFT.transferFrom(bob, alice, id_1);
        assertEq(aliceNFT.balanceOf(alice), 1);
        assertEq(aliceNFT.holderNameOf(id_1), "Alice");
        aliceNFT.updateHolderName(id_2, "Bob's ticket that Charlie gifted to Alice");

        //aliceNFT.approve(charlie,3); //fails as it should: "The ticket with the specified ticket ID does not exist"
        //aliceNFT.updateHolderName(5, "Alice"); //fails as it should : "The caller of this function does not own the ticket"
        aliceNFT.approve(charlie, id_2);
        vm.stopPrank();

        vm.startPrank(charlie);
        //aliceNFT.getApproved(5); //fails as it should: "The ticket with the specified ticket ID does not exist"

        assertEq(aliceNFT.getApproved(id_2), charlie);
        aliceNFT.transferFrom(bob, alice, id_2);
        assertEq(aliceNFT.balanceOf(alice), 2);
        assertEq(aliceNFT.holderNameOf(id_2), "Bob's ticket that Charlie gifted to Alice");

        vm.stopPrank();

        vm.startPrank(bob);
        //aliceNFT.setUsed(id_1); // fails as it should: Only the admin of this event can access this function
        vm.stopPrank();

        

        vm.startPrank(alice);
        vm.warp(time);
        //vm.warp(time+864001);
        //aliceNFT.setUsed(1); // fails as it should:This ticket has expired
        assertTrue(!aliceNFT.isExpiredOrUsed(1));
        aliceNFT.setUsed(1);
        assertTrue(aliceNFT.isExpiredOrUsed(1));

        assertTrue(!aliceNFT.isExpiredOrUsed(2));
        vm.warp(time);
        assertTrue(!aliceNFT.isExpiredOrUsed(2));
        vm.warp(time+863999);
        assertTrue(!aliceNFT.isExpiredOrUsed(2));
        vm.warp(time+864001);
        assertTrue(aliceNFT.isExpiredOrUsed(2));

        vm.stopPrank();
     
    }
}