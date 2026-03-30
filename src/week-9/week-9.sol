// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Goal: Crowdfund with automatic success/failure and batched refunds.
    - Anyone can contribute ETH until deadline.
    - If goal is met, creator withdraws.
    - If goal is missed, anyone can process refunds in batches.
*/

contract BatchRefundCrowdfund {
    address public immutable creator;
    uint256 public immutable goal;
    uint256 public immutable deadline;

    uint256 public totalRaised;
    bool public finalized;
    bool public successful;
    uint256 public nextRefundIndex;

    address[] public contributors;
    mapping(address => uint256) public contributed;

    constructor(uint256 _goal, uint256 _durationSeconds) {
        require(_goal > 0, "Goal zero");
        creator = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _durationSeconds;
    }

    function contribute() external payable {
        // @audit-low should check if the deadline has passed
        require(msg.value > 0, "No ETH");

        if (contributed[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        contributed[msg.sender] += msg.value;
        totalRaised += msg.value;
    }

    function finalize() external {
        require(block.timestamp >= deadline, "Not ended");
        require(!finalized, "Finalized");

        finalized = true;

        // @audit-low crowdfund should succeed when the goal is met
        // consider adding >= instead of >
        if (totalRaised > goal) {
            successful = true;
        }
    }

    function creatorWithdraw() external {
        require(finalized, "Not finalized");
        require(successful, "Not successful");
        require(msg.sender == creator, "Not creator");

        uint256 amount = address(this).balance;
        (bool ok,) = creator.call{value: amount}("");
        require(ok, "Pay failed");
    }

    // @audit consider adding checks for msg.sender
    function processRefunds(uint256 maxUsers) external {
        require(finalized, "Not finalized");
        require(!successful, "Campaign succeeded");
        require(maxUsers > 0, "Zero batch");

        uint256 processed = 0;
        while (processed < maxUsers && nextRefundIndex < contributors.length) {
            address user = contributors[nextRefundIndex];
            uint256 amount = contributed[user];

            if (amount > 0) {
                contributed[user] = 0;
                (bool ok,) = user.call{value: amount}("");
                require(ok, "Refund failed");
            }

            nextRefundIndex++;
            processed++;
        }
    }
}
