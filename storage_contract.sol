// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 < 0.9.0;

/*
*/

contract StorageContract {
    uint public balance;
    string  public name;

    function setBalance(uint _balance) external {
        balance = _balance;
    }

    function setName(string memory _name) external {
        name = _name;
    }
}

contract ContractV1{
    StorageContract public store;

    function businessLogic() public view returns(uint){
        return store.balance();
    }
}

contract ContractV2{
    StorageContract public store;

    constructor(address migrateFrom){
        ContractV1 c = ContractV1(migrateFrom);
        store= c.store();
    }

    function businessLogic() public view returns(uint){
        return store.balance()*2;
    }
}