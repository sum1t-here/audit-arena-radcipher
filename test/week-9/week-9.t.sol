// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BatchRefundCrowdfund} from "src/week-9/week-9.sol";

contract Week9Test is Test {
    BatchRefundCrowdfund public crowdfund;

    address public CREATOR;
    address public CONTRIBUTOR_1;
    address public CONTRIBUTOR_2;
    address public CONTRIBUTOR_3;

    function setUp() public {
        CREATOR = makeAddr("CREATOR");
        CONTRIBUTOR_1 = makeAddr("CONTRIBUTOR_1");
        CONTRIBUTOR_2 = makeAddr("CONTRIBUTOR_2");
        CONTRIBUTOR_3 = makeAddr("CONTRIBUTOR_3");

        vm.prank(CREATOR);
        crowdfund = new BatchRefundCrowdfund(100 ether, 1 days);
        vm.deal(CONTRIBUTOR_1, 100 ether);
        vm.deal(CONTRIBUTOR_2, 100 ether);
        vm.deal(CONTRIBUTOR_3, 100 ether);
    }

    function test_contribute() public {
        console.log("Balance of contract before contribute: ", address(crowdfund).balance);

        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 10 ether}();

        console.log("Balance of contract after contribute: ", address(crowdfund).balance);

        assertGt(address(crowdfund).balance, 0 ether);
        assertEq(address(crowdfund).balance, 10 ether);
        assertEq(crowdfund.contributed(CONTRIBUTOR_1), 10 ether);
        assertEq(crowdfund.contributors(0), CONTRIBUTOR_1);
        assertEq(crowdfund.totalRaised(), 10 ether);
    }

    function test_user_can_contribute_multiple_times() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 10 ether}();

        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 20 ether}();

        assertEq(crowdfund.contributed(CONTRIBUTOR_1), 30 ether);
        assertEq(crowdfund.contributors(0), CONTRIBUTOR_1);
        assertEq(crowdfund.totalRaised(), 30 ether);
    }

    function test_multiple_users_can_contribute() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 10 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        assertEq(crowdfund.contributed(CONTRIBUTOR_1), 10 ether);
        assertEq(crowdfund.contributed(CONTRIBUTOR_2), 20 ether);
        assertEq(crowdfund.contributed(CONTRIBUTOR_3), 30 ether);
        assertEq(crowdfund.contributors(0), CONTRIBUTOR_1);
        assertEq(crowdfund.contributors(1), CONTRIBUTOR_2);
        assertEq(crowdfund.contributors(2), CONTRIBUTOR_3);
        assertEq(crowdfund.totalRaised(), 60 ether);
    }

    function test_finalize() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 51 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        // warp to deadline + 1 day
        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        assertEq(crowdfund.finalized(), true);
        assertEq(crowdfund.successful(), true);
    }

    function test_finalize_fail_if_goal_not_met() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 51 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        assertEq(crowdfund.finalized(), true);
        assertEq(crowdfund.successful(), false);
    }

    function test_fail_if_finalize_before_deadline() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 51 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.expectRevert();
        vm.warp(block.timestamp);
        crowdfund.finalize();
    }

    function test_creator_withdraw() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 51 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        vm.prank(CREATOR);
        crowdfund.creatorWithdraw();

        assertEq(address(crowdfund).balance, 0 ether);
    }

    function test_creator_cannot_withdraw_if_goal_not_met() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 49 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        vm.expectRevert();
        vm.prank(CREATOR);
        crowdfund.creatorWithdraw();
    }

    function test_fail_if_non_creator_withdraw() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 49 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        vm.expectRevert();
        vm.prank(CONTRIBUTOR_1);
        crowdfund.creatorWithdraw();
    }

    function test_process_refunds() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 10 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        uint256 bal1Before = CONTRIBUTOR_1.balance;
        uint256 bal2Before = CONTRIBUTOR_2.balance;
        uint256 bal3Before = CONTRIBUTOR_3.balance;

        crowdfund.processRefunds(3);

        assertEq(crowdfund.contributed(CONTRIBUTOR_1), 0 ether);
        assertEq(crowdfund.contributed(CONTRIBUTOR_2), 0 ether);
        assertEq(crowdfund.contributed(CONTRIBUTOR_3), 0 ether);

        assertEq(CONTRIBUTOR_1.balance, bal1Before + 10 ether);
        assertEq(CONTRIBUTOR_2.balance, bal2Before + 20 ether);
        assertEq(CONTRIBUTOR_3.balance, bal3Before + 30 ether);
    }

    function test_anyone_can_process_refunds() public {
        uint256 numContributors = 500;
        for (uint256 i = 1; i <= numContributors; i++) {
            address contributor = address(uint160(i + 100));
            vm.deal(contributor, 1 ether);
            vm.prank(contributor);
            crowdfund.contribute{value: 0.1 ether}();
        }

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        address attacker = makeAddr("attacker");

        uint256 totalGasWasted = 0;
        for (uint256 i = 0; i < 10; i++) {
            uint256 gasBefore = gasleft();
            vm.prank(attacker);
            crowdfund.processRefunds(1);
            totalGasWasted += gasBefore - gasleft();
        }

        console.log("Attacker processed index:   ", crowdfund.nextRefundIndex());
        console.log("Total gas used by attacker: ", totalGasWasted);
        console.log("Remaining contributors:     ", numContributors - crowdfund.nextRefundIndex());

        // now a legit user tries to refund the rest efficiently
        address legitUser = makeAddr("legitUser");
        uint256 gasBefore = gasleft();
        vm.prank(legitUser);
        crowdfund.processRefunds(type(uint256).max);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used by legit user:     ", gasUsed);

        // prove attacker had zero right to do this
        assertEq(crowdfund.contributed(attacker), 0); // attacker never contributed
        assertEq(crowdfund.nextRefundIndex(), numContributors); // queue fully drained by o
    }

    function test_DOS_attack() public {
        MaliciousContributor maliciousContributor = new MaliciousContributor(address(crowdfund));
        vm.deal(address(maliciousContributor), 10 ether);

        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 10 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();

        maliciousContributor.contribute();

        vm.prank(CONTRIBUTOR_3);
        crowdfund.contribute{value: 30 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        vm.expectRevert();
        crowdfund.processRefunds(4);
    }

    function test_finalize_exact_goal() public {
        // contribute exactly 100 ether — should succeed but doesn't
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 100 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        // fails with current code (> instead of >=)
        assertEq(crowdfund.successful(), false);
    }

    function test_contribute_after_finalize() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 100 ether}();

        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 50 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        console.log("Creator Balance before withdraw: ", CREATOR.balance);

        vm.prank(CREATOR);
        crowdfund.creatorWithdraw();

        console.log("Creator Balance after withdraw: ", CREATOR.balance);

        // CONTRIBUTOR_2 mistakenly contributes after finalization
        vm.prank(CONTRIBUTOR_2);
        crowdfund.contribute{value: 20 ether}();
        assertEq(address(crowdfund).balance, 20 ether);

        // creator steals post-finalization deposit
        vm.prank(CREATOR);
        crowdfund.creatorWithdraw();

        // CONTRIBUTOR_2 lost 20 ether with no recovery path
        assertEq(CREATOR.balance, 170 ether); // creator got both
        assertEq(address(crowdfund).balance, 0 ether); // funds gone
        assertEq(crowdfund.contributed(CONTRIBUTOR_2), 70 ether); // mapping still shows it
    }
}

contract MaliciousContributor {
    BatchRefundCrowdfund public crowdfund;

    constructor(address _crowdfund) {
        crowdfund = BatchRefundCrowdfund(_crowdfund);
    }

    function contribute() external payable {
        crowdfund.contribute{value: 5 ether}();
    }

    receive() external payable {
        revert();
    }
}
