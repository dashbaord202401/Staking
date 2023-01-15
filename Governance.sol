// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable {
    // ERC20 token contract address
    ERC20 public token;

    // Proposal ID
    uint256 public proposalId;

    // Voting Period
    uint256 votingPeriod;

    // Mapping from proposal ID to proposal details
    mapping(uint256 => Proposal) public proposals;

    // Mapping from proposal ID to the total token weight of votes for and against
    mapping(uint256 => Vote) public voteTotals;

    // Mapping from proposal ID to the voting address to voting status
    mapping(uint256 => mapping(address => bool)) public voters;

    // Proposal state
    enum State {
        Created,
        Executed,
        Failed
    }

    // Event for when a proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed creator,
        string name,
        string description,
        uint256 votingPeriod
    );

    // Event for when a vote is cast
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool vote
    );

    // Event for when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId);

    // Event for when a proposal is failed
    event ProposalFailed(uint256 indexed proposalId);

    // Proposal struct
    struct Proposal {
        address creator;
        string name;
        string description;
        uint256 votingPeriod;
        State state;
    }

    // Vote struct
    struct Vote {
        uint256 yes;
        uint256 no;
    }

    constructor(address _token, uint256 _votingPeriod) {
        token = ERC20(_token);
        votingPeriod = _votingPeriod;
    }

    // Create a new proposal
    function createProposal(string memory _name, string memory _description)
        public
        onlyOwner
    {
        proposalId++;
        proposals[proposalId] = Proposal(
            msg.sender,
            _name,
            _description,
            block.timestamp + votingPeriod,
            State.Created
        );
        voteTotals[proposalId] = Vote(0, 0);
        emit ProposalCreated(
            proposalId,
            msg.sender,
            _name,
            _description,
            block.timestamp + votingPeriod
        );
    }

    // Cast a proposal
    function vote(uint256 _proposalId, bool _vote) public {
        require(proposals[_proposalId].votingPeriod > block.timestamp);
        require(!voters[_proposalId][msg.sender]);
        // require(
        //     voteTotals[_proposalId].yes + voteTotals[_proposalId].no == 0 ||
        //         voteTotals[_proposalId].yes + voteTotals[_proposalId].no > 0
        // );
        // require(_vote == true || _vote == false);
        if (_vote) {
            voteTotals[_proposalId].yes += token.balanceOf(msg.sender);
        } else {
            voteTotals[_proposalId].no += token.balanceOf(msg.sender);
        }
        voters[_proposalId][msg.sender] = true;
        emit VoteCast(_proposalId, msg.sender, _vote);
    }

    // Check if a proposal has passed
    function checkProposalPassed(uint256 _proposalId)
        internal
        view
        returns (bool)
    {
        return voteTotals[_proposalId].yes > voteTotals[_proposalId].no;
    }

    function proposalState(uint256 _proposalId) public view returns (State) {
        return proposals[_proposalId].state;
    }

    function proposalEndsIn(uint256 _proposalId) public view returns (uint256) {
        return proposals[_proposalId].votingPeriod - block.timestamp;
    }

    function checkVoting(uint256 _proposalId)
        public
        view
        returns (Vote memory)
    {
        return voteTotals[_proposalId];
    }

    // Execute a proposal
    function executeProposal(uint256 _proposalId) public onlyOwner {
        require(
            proposals[_proposalId].votingPeriod <= block.timestamp,
            "Voting period not ended"
        );
        require(
            proposals[_proposalId].state == State.Created,
            "Already Executed or failed"
        );
        if (checkProposalPassed(_proposalId)) {
            proposals[_proposalId].state = State.Executed;
            emit ProposalExecuted(_proposalId);
        } else {
            proposals[_proposalId].state = State.Failed;
            emit ProposalFailed(_proposalId);
        }
    }
}
