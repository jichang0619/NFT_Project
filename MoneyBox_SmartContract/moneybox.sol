// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 < 0.9.0;

/*
1. 1 이더만 내야한다
2. 중복해서 참여 불가 (단, 누군가 적립금을 받으면 초기화)
3. 관리자만 적립된 이더 볼 수 있다.
4. 3의 배수 번째 사람에게만 적립된 이더를 준다.

*/
contract MoneyBox {
    event WhoPaid(address indexed sender, uint256 payment); // moneybox 에 돈을 준 sender , 얼마를 줬는지
    address ownwer;
    
    mapping (uint256=> mapping(address => bool)) paidMemberList; // (key, (key, value)) , (round, (address, bool))
    
    /*
    1 round : A : true , B: true ,C : true paidMemberList
    2 round : E, R, D paidMemberList
    3 round : A ,R ,B paidMemberList
    4 round : All false
    */
    
    uint256 round = 1;
    uint256 ownerFee = 5; // 5% 
    uint256 gamePrice = 1000000000000000000; // 1 ETH
    
    constructor(){
        ownwer = msg.sender; // msg.sender == moneybox의 배포자
    }
   
    // external payable : smartcontract 가 ETH 를 받아야하고, 가지고 있어야 해서
    receive() external payable {
        require(msg.value == gamePrice, "Must be 1 ether.");
        require(paidMemberList[round][msg.sender] == false, "Must be a new player in each game.");
        
        paidMemberList[round][msg.sender] = true;
        
        emit WhoPaid(msg.sender,msg.value);
        
        // If 문이 balance 조건이 아닌 다른조건으로.. 
        if(address(this).balance == 3 * gamePrice){
            
            // SmartContract 작성한 사람에게 수수료 전달
            payable(ownwer).transfer((address(this).balance) * ownerFee / 100);
            // call 함수를 이용해서 smartcontract 이 가지고 있는 모든 ETH 전달 msg.sender 에게
            (bool sent,)= payable(msg.sender).call{value:(address(this).balance)}(""); 
            require(sent,"Failed to pay");
            round++;
        }
    }

    
    function checkRound() public view returns(uint256){
        return round;
    }
    
    function checkValue() public view returns(uint256){
        require(ownwer==msg.sender, "Only Onwer can check the value");
        return address(this).balance; // this == smartcontract
    }
}