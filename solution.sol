// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
Lab lesson 1 (upgradability) Making an upgradeable voting smart contract 

Create a smart contract (which can be upgraded) where people can submit 
proposals and vote on them. The owner can upgrade the smart contract to add 
functionality or fix bugs. 

Adding a proposal is free (apart from the gas cost of course). A proposal only 
contains the id (uint) of the proposal, you can assume that the additional information 
about the proposal can be found online. 

Voting on a proposal costs 0.5 Ether, this is configurable by the owner of the 
smart contract. The person who submitted the winning proposal gets the money from 
all the votes as a reward. 

A proposal wins if it has the most votes, the owner can customize the "win 
schedule" (for example, a proposal must get at least half of the votes). You do not 
need to implement an additional "win schedule", you may assume that the owner will 
implement any new win schedule if required. The win scheme should get the list of 
proposals with votes, and return only the id of the winning proposal. 

After 1000 blocks, no more voting is possible. Only the function that calculates 
the winner can still be executed. 

Once the winner has been calculated, the winner can receive his Ether (Don't 
forget to use the design patterns from the first lesson!) 

This is an individual task that counts for daily work. You only need to create the 
Solidity code, no website needs to be created. You may put multiple contracts in a 
zip. Only .sol and .zip files are valid. 
*/

// 2 functies : vote and submit

// Struct to hold all relevant proposal information
struct Proposal {
    uint votes;
    uint id;
    address submitter;
}


// Simple' reusable owner contract 
abstract contract Owner{
    address private owner; 

    modifier isOwner(){
        require(msg.sender == owner, "Caller is not owner"); // we check that the person who called the function is the owner
        _;
    }

    constructor(){
        owner = msg.sender; // the person whoe create the contract is the owner
    }

    function transfer(address to) public isOwner{
        owner = to;
    }
}


//Storage contract to make the main contract upgradeable
// This is "Owner" contract, the owner of the StorageContract is the MainContract
contract StorageContract is Owner {
    // A mapping of all proposals, id => proposal struct
    mapping(uint => Proposal) public proposals;
    //Array of all proposal ids, used for iterating the mapping   => if you have a mapping you have to be able to iterate through it
    uint[] public proposalIds;

    //Add a proposal, only the owner can do this
    function addProposal(Proposal memory proposal) external isOwner{
        //Ensure the proposal does not exist
        require(!exists(proposal.id), "Proposal exists");

        //Save the proposal in the mapping
        proposals[proposal.id] = proposal;
        //Add the proposal id to the array
        proposalIds.push(proposal.id);
    }

    //Vote for a proposal, ony the owner can do this
    function voteForProposal(uint proposalId) external isOwner{
        //Ensure the proposal does not exist
        require(exists(proposalIds), "Proposal does not exist");

        //Vote for the proposal
        proposals[proposalId].votes += 1;
    }

    //Check if the proposal exists
    function exists(uint proposalId) public view returns(bool){
        //Use the fact that the id is stored inside each proposal
        return proposals[proposalId].id == proposalId;
    }

    //Return the number of proposals
    function length() external view returns(uint){
        return proposalIds.length;
    }

    //Return an array of all proposals  (gaat die mapping overzetten naar an array)
    function getAllProposals() external view returns (Proposal[] memory){
        uint proposalCount = proposalIds.length;
        //Create a fixed-length array in memory
        Proposal[] memory proposalList = new Proposal[](proposalCount);

        for(uint i=0; i<proposalCount; i++){
            proposalList[i] = proposals[proposalIds[i]];
        }
        return proposalList;
    }

    //Logic contract to make the winningscheme upgradeable
    contract WinCalculatorContract{
        function calculateWinner(Proposal[] memory proposals) public pure returns(uint){  // pure because it only perform calculation on the parameters
            uint maxVotes;
            uint winningProposalId;

            for(uint i=0; i< proposals.length; i++){
                if(proposal[i].votes >maxVotes){
                    winningProposalId = proposals[i].id;
                    maxVotes = proposals[i].votes;
                }
            }
            return winningProposalId;
        }
    }

}

contract MainContract is Owner{  // owner contract is owned by the PROXY
    //How much a vote costs
    uint public voteCost;

    //Until which block voting is valid
    uint public endBlockNumber;

    //Keeps a reference to the wincalculator contract;
    WinCalculatorContract public WinCalculatorContract;

    //Keeps a reference to the storage contract
    StorageContract public store;

    //Who can withdraw the won ether
    address payable proposalWinner;

    //An event in case someone wants to write a website for this
    event ProposalWon(uint proposalId, address submitter, uint votes);

    //A modifier to check if the deadline has been reached
    modifier isExpired{
        require(block.number > endBlockNumber, "Deadline is not yet reached, voting is still in progress");
        _;
    }

    // A modifier to check if the deadline had not been reached 
    modifier isNotExpired{
        require(block.number <= endBlockNumber, "Deadline has been reached, voting is impossible");
    }

    constructor(){
        //Set default vote cost
        voteCost = 0.5 ether;

        //Set end block number
        endBlockNumber = block.number + 1000;

        //Create the storagecontract
        store = new StorageContract();

        //Create the logic contract
        winCalculatorContract = new WinCalculatorContract();
    }

    function moveToV2(address newAddress) public isOwner{
        selfdestruct(newAddress);
    }

    //Function to change the logic contract
    function changeWinCalculatorContract(address newLocation) public isOwner{
        winCalculatorContract(address newLocation) public isOwner{
            winCalculatorContract = WinCalculatorContract(newLocation);
        }
    }

    //Function to change the vote cost
    function changeVoteCost(uint _voteCost) external isOwner {
        voteCost = _voteCost;
    }

    //Vote for a proposal
    function vote(uint proposalId) public payable isNotExpired{
        //Ensure the user pays for voting
        require(msg.value == voteCost, "Please provide the correct amount");

        //Record the vote in the storage contract
        store.voteForProposal(proposalId);
    }

    function suggest(uint proposalId) public isNotExpired{
        store.addProposal(Proposal(0, proposalId, msg.sender));
    }

    //Calculate the winner of the vote
    function calculateWinner() public isExpired{
        // let the logic contract calculate the winner
        uint winningProposalId = WinCalculatorContract.calculateWinner(store.getAllProposals());

        //Get the number of votes and the submitter of the winning proposal
        (uint votes, address submitter) = store.proposals(winningProposalId);

        // Save the winner of the proposal (withdrawal pattern)
        proposalWinner = payable(submitter);
        emit ProposalWon(winningProposalId, submitter, votes);

        //Let the winner withdraw their own money (withdrawal pattern)
        function withdraw() public isExpired{
            require(msg.sender == proposalWinner, "You are not the winner");

            selfdestruct(proposalWinner);
        }
    }



}

//Proxy contract to make the entire contract upgradeable
// !! not the contract in the slide, here it is with a Call succeed
contract Proxy is Owner{
    address currentVersion;

    event CallSucceeded(bool result, bytes data);

    fallback() external payable {
        (bool result, bytes memory data) = currentVersion.call(msg.data);
        emit CallSucceeded(result, data);
    }

    function upgrade(address newAddress) public isOwner{
        currentVersion = newAddress;
    }


}