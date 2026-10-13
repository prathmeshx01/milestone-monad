// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Milestone
/// @notice Testnet prototype for goal-based crowdfunding with contributor-weighted milestone approval.
/// @dev Milestone evidence is an off-chain URI; the approval and fund-release rules execute on-chain.
contract Milestone {
    uint256 public campaignCount;
    uint16 public constant APPROVAL_BPS = 5000; // at least 50% of raised value must approve
    uint256 public constant MAX_MILESTONES = 5;

    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 totalRaised;
        uint256 totalReleased;
        bool exists;
    }

    struct MilestoneData {
        string evidenceURI;
        uint16 shareBps;
        uint256 yesVotes;
        uint256 noVotes;
        bool submitted;
        bool released;
        uint256 voteDeadline;
    }

    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => MilestoneData[]) private campaignMilestones;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasVoted;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionReceived(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event MilestoneSubmitted(uint256 indexed campaignId, uint256 indexed milestoneIndex, string evidenceURI);
    event MilestoneVoteCast(uint256 indexed campaignId, uint256 indexed milestoneIndex, address indexed voter, bool approved, uint256 weight);
    event MilestoneReleased(uint256 indexed campaignId, uint256 indexed milestoneIndex, address indexed creator, uint256 amount);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignCancelled(uint256 indexed campaignId);

    modifier campaignExists(uint256 campaignId) {
        require(campaigns[campaignId].exists, "Campaign does not exist");
        _;
    }

    function createCampaign(
        string calldata title,
        string calldata description,
        uint256 goal,
        uint256 deadline,
        uint16[] calldata milestoneSharesBps
    ) external returns (uint256 campaignId) {
        require(bytes(title).length > 0 && bytes(title).length <= 100, "Invalid title");
        require(bytes(description).length > 0 && bytes(description).length <= 500, "Invalid description");
        require(goal > 0, "Goal must be positive");
        require(deadline > block.timestamp, "Deadline must be in future");
        require(milestoneSharesBps.length > 0 && milestoneSharesBps.length <= MAX_MILESTONES, "Use 1-5 milestones");

        uint256 totalShares;
        for (uint256 i; i < milestoneSharesBps.length; ++i) {
            require(milestoneSharesBps[i] > 0, "Share must be positive");
            totalShares += milestoneSharesBps[i];
        }
        require(totalShares == 10000, "Milestone shares must total 100%");

        campaignId = ++campaignCount;
        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: title,
            description: description,
            goal: goal,
            deadline: deadline,
            totalRaised: 0,
            totalReleased: 0,
            actionDeadline: 0,
            cancelled: false,
            exists: true
        });

        for (uint256 i; i < milestoneSharesBps.length; ++i) {
            campaignMilestones[campaignId].push(MilestoneData({
                evidenceURI: "",
                shareBps: milestoneSharesBps[i],
                yesVotes: 0,
                noVotes: 0,
                submitted: false,
                released: false,
                voteDeadline: 0
            }));
        }

        emit CampaignCreated(campaignId, msg.sender, goal, deadline);
    }

    function contribute(uint256 campaignId) external payable campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(block.timestamp < c.deadline, "Campaign deadline passed");
        require(!c.cancelled, "Campaign cancelled");
        require(c.totalRaised < c.goal, "Campaign already funded");
        require(msg.value > 0 && c.totalRaised + msg.value <= c.goal, "Contribution exceeds remaining goal");

        c.totalRaised += msg.value;
        contributions[campaignId][msg.sender] += msg.value;
        if (c.totalRaised == c.goal) c.actionDeadline = block.timestamp + 7 days;
        emit ContributionReceived(campaignId, msg.sender, msg.value);
    }

    function submitMilestone(uint256 campaignId, uint256 milestoneIndex, string calldata evidenceURI)
        external campaignExists(campaignId)
    {
        Campaign storage c = campaigns[campaignId];
        require(!c.cancelled, "Campaign cancelled");
        require(msg.sender == c.creator, "Only creator");
        require(c.totalRaised == c.goal, "Goal not reached");
        require(c.actionDeadline > 0 && block.timestamp <= c.actionDeadline, "Submission window expired; cancel for refunds");
        require(milestoneIndex < campaignMilestones[campaignId].length, "Invalid milestone");
        require(bytes(evidenceURI).length > 0 && bytes(evidenceURI).length <= 500, "Invalid evidence URI");

        MilestoneData storage m = campaignMilestones[campaignId][milestoneIndex];
        require(!m.submitted && !m.released, "Milestone already submitted");
        if (milestoneIndex > 0) {
            require(campaignMilestones[campaignId][milestoneIndex - 1].released, "Previous milestone not released");
        }
        m.evidenceURI = evidenceURI;
        m.submitted = true;
        m.voteDeadline = block.timestamp + 7 days;
        c.actionDeadline = 0;
        emit MilestoneSubmitted(campaignId, milestoneIndex, evidenceURI);
    }

    function voteMilestone(uint256 campaignId, uint256 milestoneIndex, bool approve)
        external campaignExists(campaignId)
    {
        Campaign storage c = campaigns[campaignId];
        require(!c.cancelled, "Campaign cancelled");
        require(milestoneIndex < campaignMilestones[campaignId].length, "Invalid milestone");
        MilestoneData storage m = campaignMilestones[campaignId][milestoneIndex];
        uint256 weight = contributions[campaignId][msg.sender];
        require(weight > 0, "Contributors only");
        require(m.submitted && !m.released, "Milestone not open for voting");
        require(block.timestamp <= m.voteDeadline, "Voting window expired; cancel for refunds");
        require(!hasVoted[campaignId][milestoneIndex][msg.sender], "Already voted");

        hasVoted[campaignId][milestoneIndex][msg.sender] = true;
        if (approve) {
            m.yesVotes += weight;
        } else {
            m.noVotes += weight;
        }
        emit MilestoneVoteCast(campaignId, milestoneIndex, msg.sender, approve, weight);

        if (m.yesVotes * 10000 >= c.totalRaised * APPROVAL_BPS) {
            m.released = true;
            uint256 amount;
            if (milestoneIndex == campaignMilestones[campaignId].length - 1) {
                amount = c.totalRaised - c.totalReleased;
            } else {
                amount = (c.totalRaised * m.shareBps) / 10000;
            }
            c.totalReleased += amount;
            if (milestoneIndex + 1 < campaignMilestones[campaignId].length) c.actionDeadline = block.timestamp + 7 days;
            (bool success, ) = c.creator.call{value: amount}("");
            require(success, "Payout failed");
            emit MilestoneReleased(campaignId, milestoneIndex, c.creator, amount);
        } else if (m.noVotes * 10000 >= c.totalRaised * APPROVAL_BPS) {
            c.cancelled = true;
            emit CampaignCancelled(campaignId);
        }
    }

    function canCancelAfterTimeout(uint256 campaignId) external view campaignExists(campaignId) returns (bool) {
        Campaign storage c = campaigns[campaignId];
        if (c.cancelled || c.totalRaised != c.goal) return false;
        for (uint256 i; i < campaignMilestones[campaignId].length; ++i) {
            MilestoneData storage m = campaignMilestones[campaignId][i];
            if (m.released) continue;
            if (m.submitted) return block.timestamp > m.voteDeadline;
            return c.actionDeadline > 0 && block.timestamp > c.actionDeadline;
        }
        return false;
    }

    function cancelAfterTimeout(uint256 campaignId) external campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(!c.cancelled && c.totalRaised == c.goal, "Campaign not cancellable");
        bool expired;
        for (uint256 i; i < campaignMilestones[campaignId].length; ++i) {
            MilestoneData storage m = campaignMilestones[campaignId][i];
            if (m.released) continue;
            if (m.submitted) expired = block.timestamp > m.voteDeadline;
            else expired = c.actionDeadline > 0 && block.timestamp > c.actionDeadline;
            break;
        }
        require(expired, "Timeout not reached");
        c.cancelled = true;
        emit CampaignCancelled(campaignId);
    }

    function isCancelled(uint256 campaignId) external view campaignExists(campaignId) returns (bool) {
        return campaigns[campaignId].cancelled;
    }

    function claimRefund(uint256 campaignId) external campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require((c.totalRaised < c.goal && block.timestamp >= c.deadline) || c.cancelled, "Refund not available");
        uint256 contributed = contributions[campaignId][msg.sender];
        require(contributed > 0, "Nothing to refund");
        uint256 amount = c.totalRaised < c.goal ? contributed : (contributed * (c.totalRaised - c.totalReleased)) / c.totalRaised;
        contributions[campaignId][msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");
        emit RefundClaimed(campaignId, msg.sender, amount);
    }

    function getCampaign(uint256 campaignId) external view campaignExists(campaignId) returns (
        address creator, string memory title, string memory description, uint256 goal,
        uint256 deadline, uint256 totalRaised, uint256 totalReleased, uint256 milestoneCount
    ) {
        Campaign storage c = campaigns[campaignId];
        return (c.creator, c.title, c.description, c.goal, c.deadline, c.totalRaised, c.totalReleased, campaignMilestones[campaignId].length);
    }

    function getMilestone(uint256 campaignId, uint256 milestoneIndex) external view campaignExists(campaignId) returns (
        string memory evidenceURI, uint16 shareBps, uint256 yesVotes, uint256 noVotes, bool submitted, bool released
    ) {
        require(milestoneIndex < campaignMilestones[campaignId].length, "Invalid milestone");
        MilestoneData storage m = campaignMilestones[campaignId][milestoneIndex];
        return (m.evidenceURI, m.shareBps, m.yesVotes, m.noVotes, m.submitted, m.released);
    }

    function getContribution(uint256 campaignId, address contributor) external view campaignExists(campaignId) returns (uint256) {
        return contributions[campaignId][contributor];
    }
}