// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../lib/forge-std/src/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/contracts/SecondaryMarket.sol";

contract SecondaryMarketTest is Test {
    PrimaryMarket public primaryMarket;
    PurchaseToken public purchaseToken;
    SecondaryMarket public secondaryMarket;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public danielle = makeAddr("danielle");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        secondaryMarket = new SecondaryMarket(purchaseToken);

        payable(alice).transfer(2e18);
        payable(bob).transfer(3e18);
        payable(charlie).transfer(4e18);
    }

    function testSecondaryMarket() external {
        vm.prank(danielle);
        ITicketNFT danielleNFT = primaryMarket.createNewEvent(
            "Danielle's movie screening",
            50e18,
            5
        );
        assertEq(danielleNFT.creator(), danielle);
        assertEq(danielleNFT.maxNumberOfTickets(), 5);
        assertEq(danielleNFT.eventName(), "Danielle's movie screening");
        assertEq(primaryMarket.getPrice(address(danielleNFT)), 50e18);

        vm.startPrank(alice);
        purchaseToken.mint{value: 2e18}();
        assertEq(purchaseToken.balanceOf(alice), 200e18);
        purchaseToken.approve(address(primaryMarket), 200e18);
        uint256 id_1 = primaryMarket.purchase(address(danielleNFT), "Alice");
        
        assertEq(danielleNFT.balanceOf(alice), 1);
        assertEq(danielleNFT.holderOf(id_1), alice);
        assertEq(danielleNFT.holderNameOf(id_1), "Alice");
        
        danielleNFT.approve(address(secondaryMarket), id_1);
        secondaryMarket.listTicket(address(danielleNFT), id_1, 60e18);
        assertEq(secondaryMarket.getHighestBid(address(danielleNFT), id_1), 60e18);
        assertEq(secondaryMarket.getHighestBidder(address(danielleNFT), id_1), address(0));
        assertTrue(!secondaryMarket.BidExists(address(danielleNFT), id_1)); // there has not been a bid made for the ticket yet.

        assertEq(danielleNFT.balanceOf(alice), 0);
        assertEq(danielleNFT.balanceOf(address(secondaryMarket)), 1);//sends the ticket NFT from the user who listed it to the contract of the secondary market.
        assertEq(danielleNFT.holderOf(id_1), address(secondaryMarket));
        assertEq(danielleNFT.holderNameOf(id_1), "Alice");

        uint256 id_2 = primaryMarket.purchase(address(danielleNFT), "Alice");
        uint256 id_3 = primaryMarket.purchase(address(danielleNFT), "Alice"); //Alice = 50 purchaseToken
        uint256 time = block.timestamp;

        vm.startPrank(danielle);
        danielleNFT.setUsed(id_2);
        //secondaryMarket.listTicket(address(danielleNFT), id_2, 60e18); //this should fail because the ticket is used. This ticket is no longer valid. It has either expired or has already been redeemed. Please list a valid ticket
        vm.stopPrank();

        vm.stopPrank();

        

        vm.startPrank(bob);
        purchaseToken.mint{value: 3e18}();

        assertEq(purchaseToken.balanceOf(bob), 300e18);

        purchaseToken.approve(address(secondaryMarket), 300e18);

        //secondaryMarket.submitBid(address(danielleNFT), id_1, 400e18, "Bob"); //fails as it should. Bob is trying to submit a bid for more than he has given allowance to the market. ERC20: insufficient allowance
        //secondaryMarket.submitBid(address(danielleNFT), id_1, 50e18, "Bob"); //fails as it should. Bob is trying to submit a bid for less thank the asking price. "The bid needs to be greater than the last bid"
        
        secondaryMarket.submitBid(address(danielleNFT), id_1, 100e18, "Bob");

        assertEq(purchaseToken.balanceOf(bob), 200e18); //send thepurchasetoken of the bidder to the contract of the secondary market.
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 100e18);
        assertEq(secondaryMarket.getHighestBid(address(danielleNFT), id_1), 100e18);
        assertEq(secondaryMarket.getHighestBidder(address(danielleNFT), id_1), bob);
        assertTrue(secondaryMarket.BidExists(address(danielleNFT), id_1));
        
        //secondaryMarket.submitBid(address(danielleNFT), id_3, 50e18, "Bob"); //should fail because the listing is not yet available. "This listing is no longer available"
        
        vm.stopPrank();

        vm.startPrank(alice);
        danielleNFT.approve(address(secondaryMarket), id_3);
        secondaryMarket.listTicket(address(danielleNFT), id_3, 50e18);
        vm.stopPrank();
        
        vm.startPrank(bob);
        assertTrue(!danielleNFT.isExpiredOrUsed(id_3));
        // vm.warp(time + 864001);
        // secondaryMarket.submitBid(address(danielleNFT), id_3, 60e18, "Bob"); // should fail because the ticket is expired: This ticket is no longer valid. It has either expired or has already been redeemed
        vm.stopPrank();

        vm.startPrank(charlie);
        purchaseToken.mint{value: 4e18}();
        assertEq(purchaseToken.balanceOf(charlie), 400e18);

        purchaseToken.approve(address(secondaryMarket), 400e18);
        secondaryMarket.submitBid(address(danielleNFT), id_1, 150e18, "Charlie");

        assertEq(purchaseToken.balanceOf(charlie), 250e18);
        assertEq(purchaseToken.balanceOf(bob), 300e18); //money should be sent back to the previous highest bidder
        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 150e18); //the contract should now have control only of the last highest bid.
        assertEq(secondaryMarket.getHighestBid(address(danielleNFT), id_1), 150e18);
        assertEq(secondaryMarket.getHighestBidder(address(danielleNFT), id_1), charlie);
        assertTrue(secondaryMarket.BidExists(address(danielleNFT), id_1));

        //secondaryMarket.acceptBid(address(danielleNFT), id_1); //should fail because only the person who listed the ticket can accept a bid. "Only the holder of a listing can accept a bid"
        vm.stopPrank();

        vm.startPrank(alice);
        secondaryMarket.acceptBid(address(danielleNFT), id_1);

        assertEq(purchaseToken.balanceOf(address(secondaryMarket)), 0);
        uint256 fee = (150e18 * 0.05e18 / 1e18);
        assertEq(purchaseToken.balanceOf(alice), (200e18-fee));//alice had 50 purchasetoken from before plus the bid which was 150
        assertEq(purchaseToken.balanceOf(charlie), 250e18);
        assertEq(purchaseToken.balanceOf(danielle), 150e18 + fee); // alice has bought 3 tickets at the price of 50 purchaseToken each.
        
        assertEq(danielleNFT.balanceOf(charlie), 1);
        assertEq(danielleNFT.eventName(), "Danielle's movie screening");
        assertEq(danielleNFT.holderOf(id_1), charlie);
        assertEq(danielleNFT.holderNameOf(id_1), "Charlie");


        // assertEq(secondaryMarket.getHighestBid(address(danielleNFT), id_1), 150e18); // both should fail becuase the listing is no longer available.  This listing is no longer available
        // assertEq(secondaryMarket.getHighestBidder(address(danielleNFT), id_1), charlie);
        vm.stopPrank();

        vm.startPrank(charlie);
        danielleNFT.approve(address(secondaryMarket), id_1);
        secondaryMarket.listTicket(address(danielleNFT), id_1, 200e18);
        assertEq(danielleNFT.balanceOf(charlie), 0);
        vm.stopPrank();

        vm.startPrank(bob);
        purchaseToken.approve(address(secondaryMarket), 300e18);
        secondaryMarket.submitBid(address(danielleNFT), id_1, 220e18, "Bob");
        assertEq(purchaseToken.balanceOf(bob), 80e18);
        //secondaryMarket.delistTicket(address(danielleNFT), id_1); // fails as it should: Only the holder of a listing can delist
        vm.stopPrank();


        vm.startPrank(charlie);
        secondaryMarket.delistTicket(address(danielleNFT), id_1); //refund the nft ticket to the lister and the highest bid to the bidder.
        assertEq(danielleNFT.balanceOf(charlie), 1);
        assertEq(purchaseToken.balanceOf(bob), 300e18);
        vm.stopPrank();


    }
}