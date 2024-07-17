// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../lib/forge-std/src/Test.sol";
import "../src/contracts/PurchaseToken.sol";


contract PrimaryMarketTest is Test {
    PurchaseToken public purchaseToken;
    PrimaryMarket public primaryMarket;
    PrimaryMarket public fakePrimaryMarket;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        fakePrimaryMarket = new PrimaryMarket(purchaseToken);

        payable(bob).transfer(3e18);
        payable(charlie).transfer(5e18);
        
    }

    function testPrivateMarket() external {
        vm.prank(alice);
        ITicketNFT aliceNFT = primaryMarket.createNewEvent(
            "Alice's event",
            10e18,
            300
        );

        assertEq(purchaseToken.balanceOf(alice), 0);
        assertEq(aliceNFT.creator(), alice);
        assertEq(aliceNFT.maxNumberOfTickets(), 300);
        assertEq(aliceNFT.eventName(), "Alice's event");
        assertEq(primaryMarket.getPrice(address(aliceNFT)), 10e18);

        vm.startPrank(bob);
        purchaseToken.mint{value: 3e18}();
        assertEq(purchaseToken.balanceOf(bob), 300e18);
        purchaseToken.approve(address(primaryMarket), 10e18);
        uint256 id_1 = primaryMarket.purchase(address(aliceNFT), "Bob");

        assertEq(aliceNFT.balanceOf(bob), 1);
        assertEq(aliceNFT.holderOf(id_1), bob);
        assertEq(aliceNFT.holderNameOf(id_1), "Bob");

        purchaseToken.approve(address(primaryMarket), 10e18);
        uint256 id_2 = primaryMarket.purchase(address(aliceNFT), "Bob");
        purchaseToken.approve(address(primaryMarket), 10e18);
        uint256 id_3 = primaryMarket.purchase(address(aliceNFT), "Bob's Friend");

        assertEq(aliceNFT.holderOf(id_2), bob);
        assertEq(aliceNFT.holderNameOf(id_2), "Bob");
        assertEq(aliceNFT.holderOf(id_3), bob);
        assertEq(aliceNFT.holderNameOf(id_3), "Bob's Friend");

        assertEq(aliceNFT.balanceOf(bob), 3);
        assertEq(purchaseToken.balanceOf(alice), 30e18);

        vm.stopPrank();

        vm.startPrank(charlie);
        purchaseToken.mint{value: 5e18}();
        assertEq(purchaseToken.balanceOf(charlie), 500e18);
        //purchaseToken.approve(address(fakePrimaryMarket), 10e18);
        //uint256 id_4 = fakePrimaryMarket.purchase(address(aliceNFT), "Charlie"); fails as it should. Users should only be able to purchase tickets from the private market that initiated the collection.
        
        //purchaseToken.approve(address(primaryMarket), 5e18);
        //uint256 id_4 = primaryMarket.purchase(address(aliceNFT), "Charlie"); //fails as it should: ERC20: insufficient allowance
        purchaseToken.approve(address(primaryMarket), 50e18); // enough purchaseToken for exactly 5 tickets.
        uint256 id_4 = primaryMarket.purchase(address(aliceNFT), "Charlie 1st");
        uint256 id_5 = primaryMarket.purchase(address(aliceNFT), "Charlie 2nd");
        uint256 id_6 = primaryMarket.purchase(address(aliceNFT), "Charlie 3rd");
        uint256 id_7 = primaryMarket.purchase(address(aliceNFT), "Charlie 4th");
        uint256 id_8 = primaryMarket.purchase(address(aliceNFT), "Charlie 5th");
        //uint256 id_9 = primaryMarket.purchase(address(aliceNFT), "Charlie 6th"); // fails as it should. Charlie only gave allowance for the market to use 50 purchaseToken, which is equal to 5 tickets but in this case he is trying to buy six. "ERC20: insufficient allowance".
        
        assertEq(aliceNFT.holderOf(id_4), charlie);
        assertEq(aliceNFT.holderNameOf(id_4), "Charlie 1st");

        assertEq(aliceNFT.holderOf(id_5), charlie);
        assertEq(aliceNFT.holderNameOf(id_5), "Charlie 2nd");

        assertEq(aliceNFT.holderOf(id_6), charlie);
        assertEq(aliceNFT.holderNameOf(id_6), "Charlie 3rd");

        assertEq(aliceNFT.holderOf(id_7), charlie);
        assertEq(aliceNFT.holderNameOf(id_7), "Charlie 4th");

        assertEq(aliceNFT.holderOf(id_8), charlie);
        assertEq(aliceNFT.holderNameOf(id_8), "Charlie 5th");

        assertEq(aliceNFT.balanceOf(charlie), 5);
        assertEq(purchaseToken.balanceOf(charlie), 450e18); //Charlie paid 50 purchaseToken for purchasing 5 tickets.
        assertEq(purchaseToken.balanceOf(alice), 30e18 + 50e18); //Alice should have got paid 30 purchase token from Bob and 50 from Charlie, totalling to 80.

        ITicketNFT charlieNFT = primaryMarket.createNewEvent(
            "Charlie's private event",
            20e18,
            2
        );

        assertEq(charlieNFT.creator(), charlie);
        assertEq(charlieNFT.maxNumberOfTickets(), 2);
        assertEq(charlieNFT.eventName(), "Charlie's private event");
        assertEq(primaryMarket.getPrice(address(charlieNFT)), 20e18);

        vm.stopPrank();

        vm.startPrank(alice);
        purchaseToken.approve(address(primaryMarket), 60e18);
        uint256 charlies_id_1 = primaryMarket.purchase(address(charlieNFT), "Alice");

        assertEq(charlieNFT.balanceOf(alice), 1);
        assertEq(charlieNFT.holderOf(charlies_id_1), alice);
        assertEq(charlieNFT.holderNameOf(charlies_id_1), "Alice");

        uint256 charlies_id_2 = primaryMarket.purchase(address(charlieNFT), "Alice");

        assertEq(charlieNFT.balanceOf(alice), 2);
        assertEq(charlieNFT.holderOf(charlies_id_2), alice);
        assertEq(charlieNFT.holderNameOf(charlies_id_2), "Alice");

        //uint256 charlies_id_3 = primaryMarket.purchase(address(charlieNFT), "Alice"); // fails as it should : The maximum ammount of tickets has already been minted
        assertEq(charlieNFT.balanceOf(alice), 2);
        assertEq(purchaseToken.balanceOf(charlie), 490e18);
        assertEq(purchaseToken.balanceOf(alice), 80e18 - 40e18);


        vm.stopPrank();

    }
}