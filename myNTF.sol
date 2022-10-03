//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// 추가 mint 할 때 번호 랜덤으로 주는 것? 


/*
특징
1. NFT 대량 민트
2. 프론트엔드 없이 NFT 판매

Ex) 발행한 스마트 컨트랙트 주소 : 0xD597FE42818d60B3c919368336A67e3070a5C6DB
    1. A가 0xD597FE42818d60B3c919368336A67e3070a5C6DB(발행한 스마트 컨트랙트 주소)에게 0.01 eth(현재 세팅한 가격만큼)전송한다.
    2. 0xD597FE42818d60B3c919368336A67e3070a5C6DB A에게 NFT를 발행한다.
    3. A는 15블록이후로 민트 가능하다. 
    4. 배포자는 witdraw 함수로 판매된 NFT의 이더를 갖고 올 수 있다

NFT 발행 순서

1._baseURI함수에서 메타데이터(metadata) CID 추가
2. 컴파일 (ctrl+s)
3. DEPLOY & RUN TRANSACTIONS : Environment -> Injected Provider - Metamask 선택
4. CONTRACT -> myNFT 선택
5. myNFT의 아규먼트(argument) 넣어주기

    -_NAME : 토큰 이름 JichangNFT2
    -_SYMBOL : 토큰 심볼 JCNFT2
    -_LIMIT : NFT 최대 발행 개수 10  
    EX)
    첫번째 발행된 NFT의 id : 1 -> 메타데이터 1.json -> 그림 1.png
    두번째 발행된 NFT의 id : 2 -> 메타데이터 2.json -> 그림 2.png
        ...
    열번째 발행된 NFT의 id : 10 -> 메타데이터 10.json -> 그림 10.png     
    limit = 10 
    열한번째 발행된 NFT의 id : 11 -> 메타데이터 11.json -> 그림 11.png   -> X  

    -_PRICE : NFT 판매 가격  10000000000000000
    1ETH = 10^18 / 0.1 eth = 10^17 / 0.01 eth = 10^16 (O) 

    -_INTERVAL : NFT 민트 간격 (봇이 독점 방지) 15
        EX) 현재 블록 : 100 
            간격 : 15 블록
            A -> 100번째 블록에서 NFT 민트(mint) -> 101~114 블록 민트 불가 ->115블록 부터 다시 NFT 민트(mint) 가능
            B -> 105번째 블록에서 NFT 민트(mint)
            (클레이튼 초당 1블록)

    -_REAVELINGBLOCK : 언제 NFT가 공개되는지 25
        EX) 현재 블록 : 100 
            공개 시작 블록 : 25블록 
            cvoer.js 파일에 있는 그림(NFT공개전 그림) -> 125 블록 -> 진짜 NFT 그림

    -_NOTREVELEDNFTURI : 진짜 NFT를 공개 하기전의 그림의 메타데이터 즉 Cover.js URI 
        EX)  ipfs://Qma32eRjhhe4wfJZFNYfUhqv3EJzYMHugPSwr66jRmnYhW 에서 YOUR_CID를 Cover.js의 CID로 변경하기.
   
6. Deploy 또는 transact 버튼 누르기

*/

contract myNFT is ERC721Enumerable, Ownable {
    
    error WaitForACoupleOfBlocks(uint256 tillBlock, uint256 currentBlock);
    error IncorrectValue(uint256 paidPrice, uint256 price);
    error OutOfNfts();
    error FailedToWithdraw();

    uint256 public limit;
    uint256 public latestId;
    uint256 public price;
    uint256 public whitelistPrice;
    uint256 public interval;
    uint256 public revelingBlock;
    string public notReveledNFTURI; 
    mapping(address=>uint256) public NumberTracker; 
    mapping(address=>uint256) public whitelist_addr;

    using Strings for uint256;

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _limit, 
        uint256 _price, // public sale 가격
        uint256 _whitelistPrice,
        uint256 _interval,
        uint256 _revelingBlock,
        string memory _notReveledNFTURI
    ) ERC721(_name, _symbol) 
    {
        limit = _limit;
        price = _price;
        whitelistPrice = _whitelistPrice;
        interval = _interval;
        revelingBlock = _revelingBlock + block.number; // deploy 시 block number 에서 더하기
        notReveledNFTURI = _notReveledNFTURI; // _notReveledNFTURI 를 직접 적어줘야함.
    }

    // fallback : 불려진 함수가 스마트컨트랙에 없을 때
    // fallback 은 recevie, fallback 두 가지 종류, recieve는 순수하게 ETH 를 받기 위해서
    receive() external payable{
        if (block.number <= block.number + 300)
        {
            mint_whitelist();
        }
        mint();
    }

    // 추가기능 <airdrop> : 원하는 유저에게 NFT를 줄 수 있음 (to : NFT를 받는 주소, _number : 몇개의 NFT를 줄것인지)
    function u_airdrop(address _to, uint256 _number) external onlyOwner() {
        for(uint256 i; i < _number; ++i){
            if(latestId>=limit) {
                revert OutOfNfts();
            }
            ++latestId; 
            _safeMint(_to,latestId);
        }
    }

    // 추가기능 <Whitelist> : Whitelist 추가, 제거는 Owner 만 가능
    // https://www.youtube.com/watch?v=jEpKPYbctlg&t=2s 화리 목록도 보려면 이거 추가
    function add_whitelist(address addr) external onlyOwner() {
        require(whitelist_addr[addr] == 0);
        whitelist_addr[addr] = 1;
    }

    function del_whitelist(address addr) external onlyOwner() {
        require(whitelist_addr[addr] != 0);
        whitelist_addr[addr] = 0;
    }

    function mint_whitelist() public payable {
    
        require(whitelist_addr[msg.sender] == 0, "This User is Not in Whitelist");

         // msg.sender 가 interval 이후에 한번 더 mint 할 수 있음 (interval 이내 여러번 mint 불가능)
        if(NumberTracker[msg.sender] == 0 ? false : NumberTracker[msg.sender] + interval >= block.number) 
        {
            revert WaitForACoupleOfBlocks(NumberTracker[msg.sender] + interval,block.number);
        }
        // msg.sender 가 보낸 value 값이 whitelist mint 설정 가격과 다른경우
        if(whitelistPrice != msg.value) 
        {
            revert IncorrectValue(msg.value, price);
        }
        if(latestId>=limit) 
        {
            revert OutOfNfts();
        }
        ++latestId;
        _safeMint(msg.sender,latestId);
        NumberTracker[msg.sender] = block.number;
    }
    

    // ERC721.sol 의 _safeMint 함수 사용 <<public sale>> : 선착순
    function mint() public payable {
         // msg.sender 가 interval 이후에 한번 더 mint 할 수 있음 (interval 이내 여러번 mint 불가능)
        if(NumberTracker[msg.sender] == 0 ? false : NumberTracker[msg.sender] + interval >= block.number) 
        {
            revert WaitForACoupleOfBlocks(NumberTracker[msg.sender] + interval,block.number);
        }
        // msg.sender 가 보낸 value 값이 mint 설정 가격과 다른경우
        if(price != msg.value) 
        {
            revert IncorrectValue(msg.value, price);
        }
        if(latestId>=limit) 
        {
            revert OutOfNfts();
        }
        ++latestId;
        _safeMint(msg.sender,latestId);
        NumberTracker[msg.sender] = block.number;
    }

    // Your_CID를 metadata CID로 변경해야 함
    // ipfs://____ / 뒤에 슬래쉬 꼭 필요!!!
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://Qmekywick4QuUtWctd74tJpp4foi2WEPZnvqBGbDuty338/";
    }

    // ERC721.sol 의 tokenURI 함수 사용 + 응용 : 리빌 기능!
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId); // tokenId 없으면 "ERC721: invalid token ID"

        if(revelingBlock<=block.number)
        {
            string memory baseURI = _baseURI();
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : "";
        }
        else
        {
            return notReveledNFTURI;
        }
    }

    // NFT 판매 가격 변경하는 함수
    function u_setPrice(uint256 _price) external onlyOwner()  {
        price = _price;
    } 

    // NFT 민트할 수 있는 간격 변경 함수
    function u_setInterval(uint256 _interval) external onlyOwner(){
        interval = _interval;
    } 

    // NFT 리빌 블록 변경 함수
    function u_setRevelingBlock(uint256 _revelingBlock) external onlyOwner(){
        revelingBlock = _revelingBlock + block.number;
    } 
     
    // NFT 리빌 블록 얼마나 남았는지 보여주는 함수
    function u_whenToRevelNFTs() external view returns(uint256) {
       return revelingBlock <= block.number  ? 0 : revelingBlock - block.number ;
    } 
   
    // 현재 NFT 판매금액
    function u_currentBalance() external view returns(uint256) {
      return address(this).balance;
    }
    
    // 판매금액 출금하기
    function u_withdraw() external onlyOwner() {
      (bool _result,) = address(msg.sender).call{value:address(this).balance}("");
      if(!_result) revert FailedToWithdraw();
    }
}