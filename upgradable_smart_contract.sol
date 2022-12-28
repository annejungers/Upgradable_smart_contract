pragma solidity >= 0.7.0 < 0.9.0;

contract ContractV1{

    uint public balance;
    string public name;

    function stop(address payable newContractAddress) public {
        selfdestruct(newContractAddress);
    }

    function businessLogic() public returns(uint){
        return balance;
    }
}

contract ContractV2{

    uint balance;
    string name;

    constructor(address migrateFrom){
        ContractV1 c = ContractV1(migrateFrom);
        balance = c.balance();
        name = c.name();
    }

    function businessLogic() public returns(uint){
        return balance*2;
    }
}

// PROXY contract to keep track of the previous address
// interface is a list of contract definition without implementation
// = description of all functions that an object must have  for it to operate
/*
interface ContractInterface {
    function businessLogic() external returns (uint);
}
*/

contract ContractProxy {
    address public currentContract;

    function update (address payable _newContractAddress)public{
        currentContractAddress = _newContractAddress;
    }

    fallback(bytes calldata) external payable returns(bytes memory){
        (bool result, bytes memory data) = 
        currentContractAddress.call(msg.data);  //.call 
        require(result);
        return data;
    }

}

