//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./contracts/utils/Strings.sol";
import "./contracts/access/Ownable.sol";

/*
특징
1. NFT 대량 민트
2. 프론트엔드 없이 NFT 판매

Ex) 발행한 스마트 컨트랙트 주소 : 0xd9145CCE52D386f254917e481eB44e9943F39138
    1. A가 0xd9145CCE52D386f254917e481eB44e9943F39138(발행한 스마트 컨트랙트 주소)에게 0.01 eth(현재 세팅한 가격만큼)전송한다.
    2. 0xd9145CCE52D386f254917e481eB44e9943F39138 A에게 NFT를 발행한다.
    3. A는 15블록이후로 민트 가능하다. 
    4. 배포자는 witdraw 함수로 판매된 NFT의 이더를 갖고 올 수 있다
*/

/*
순서
1. setBaseURI : "ipfs://Qmekywick4QuUtWctd74tJpp4foi2WEPZnvqBGbDuty338/" Metadata 입렵, 뒤에 슬래쉬 꼭 필요!!!
2. NotRe "ipfs://Qma32eRjhhe4wfJZFNYfUhqv3EJzYMHugPSwr66jRmnYhW/" 커버 Metadata 입력
*/

contract myNFT is ERC721Enumerable, Ownable {

    error FailedToWithdraw();

    uint256 private _maxSaleAmount;
    uint256 private _mintIndexForSale;
    uint256 private _mintLimitPerBlock;         // Maximum purchase nft per person per block
    uint256 private _mintLimitPerSale;          // Maximum purchase nft per person per sale
    uint256 private _mintStartBlockNumber;      // In blockchain, blocknumber is the standard of time.
    uint256 private _mintPrice;
    uint256 private _whiteListMintPrice;
    uint256 private _antibotInterval;
    uint256 private revelingBlock;

    string notRevealedUri; 
    string baseURI;

    bool public revealed = false;
    bool public publicMintEnabled = false;

    mapping(address=>uint256) private _lastCallBlockNumber; 

    using Strings for uint256;

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public  onlyOwner() {
      baseURI = _newBaseURI;
    }

    function _notRevealedURI() internal view returns (string memory) {
      return notRevealedUri;
    }

    function setNotRevealedURI(string memory _newNotRevealedURI) public onlyOwner() {
      notRevealedUri = _newNotRevealedURI;
    }

    // NFT 리빌 블록 변경 함수
    function setRevelingBlock(uint256 _revelingBlock) external onlyOwner(){
        revelingBlock = _revelingBlock + block.number;
    } 
     
    // NFT 리빌 블록 얼마나 남았는지 보여주는 함수
    function whenToRevelNFTs() external view returns(uint256) {
       return revelingBlock <= block.number  ? 0 : revelingBlock - block.number ;
    } 

    // if 문 _revelingBlock 넣어서 일정 시간 후에 revealed 되도록 구현 할 수 있음
    function reveal(bool _state) public onlyOwner() {
      revealed = _state;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId); // tokenId 없으면 "ERC721: invalid token ID"

        if(revealed == false)
        {
            string memory currentNotRevealedUri = _notRevealedURI();
            return bytes(currentNotRevealedUri).length > 0
            ? string(abi.encodePacked(currentNotRevealedUri, tokenId.toString(), ".json"))
            : "";
        }
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), ".json"))
            : "";
    }

    constructor(
        string memory _name, 
        string memory _symbol
    ) ERC721(_name, _symbol) 
    {
        _mintIndexForSale = 1;
    }

/*
    // fallback : 불려진 함수가 스마트컨트랙에 없을 때
    // fallback 은 recevie, fallback 두 가지 종류, recieve는 순수하게 ETH 를 받기 위해서
    receive() external payable{
        if (block.number <= block.number + 300) //if 문은 수정... 가능
        {
            mint_whitelist();
        }
        publicMint();
    }
*/

    // 판매금액 출금하기
    function withdraw() external onlyOwner() {
      (bool _result,) = address(msg.sender).call{value:address(this).balance}("");
      if(!_result) revert FailedToWithdraw();
    }

    // 현재 NFT 판매금액
    function currentBalance() external view returns(uint256) {
      return address(this).balance;
    }

    function mintingInformation() external view returns (uint256[7] memory){
      uint256[7] memory info =
        [_antibotInterval, _mintIndexForSale, _mintLimitPerBlock, _mintLimitPerSale, 
          _mintStartBlockNumber, _maxSaleAmount, _mintPrice];
      return info;
    }

    //=======================================================================================//
    //=============================== SetPublic Sale Function ===============================//
    function setPublicMintEnabled(bool _state) public onlyOwner() {
      publicMintEnabled = _state;
    }

    function setupSale(uint256 newAntibotInterval, 
                       uint256 newMintLimitPerBlock,
                       uint256 newMintLimitPerSale,
                       uint256 newMintStartBlockNumber,
                       uint256 newMintIndexForSale,
                       uint256 newMaxSaleAmount,
                       uint256 newMintPrice,
                       uint256 newWhiteListMintPrice) external onlyOwner() {
      _antibotInterval = newAntibotInterval;
      _mintLimitPerBlock = newMintLimitPerBlock;
      _mintLimitPerSale = newMintLimitPerSale;
      _mintStartBlockNumber = newMintStartBlockNumber;
      _mintIndexForSale = newMintIndexForSale;
      _maxSaleAmount = newMaxSaleAmount;
      _mintPrice = newMintPrice;
      _whiteListMintPrice = newWhiteListMintPrice;
    }
    
    //=======================================================================================//
    //================================= PublicMint Function =================================//
    function publicMint(uint256 requestedCount) external payable {
        require(publicMintEnabled, "The public sale is not enabled!");
        require(_lastCallBlockNumber[msg.sender] + _antibotInterval < block.number, "Bot is not allowed");
        require(block.number >= _mintStartBlockNumber, "Not yet started");
        require(requestedCount > 0 && requestedCount <= _mintLimitPerBlock, "Too many requests or zero request");
        require(msg.value == _mintPrice * requestedCount, "Not enough ETH");
        require(_mintIndexForSale + requestedCount <= _maxSaleAmount + 1, "Exceed max amount");
        require(balanceOf(msg.sender) + requestedCount <= _mintLimitPerSale, "Exceed max amount per person");
      
        for(uint256 i = 0; i < requestedCount; i++) {
        _safeMint(msg.sender, _mintIndexForSale);
        _mintIndexForSale = _mintIndexForSale + 1;
        }
        _lastCallBlockNumber[msg.sender] = block.number;
    }

    //=======================================================================================//
    //================================== Air-Drop Function ==================================//
    function airDropMint(address user, uint256 requestedCount) external onlyOwner() {
      require(requestedCount > 0, "zero request");
      require(_mintIndexForSale + requestedCount <= _maxSaleAmount + 1, "Exceed max amount");
      for(uint256 i = 0; i < requestedCount; i++) {
        _safeMint(user, _mintIndexForSale);
        _mintIndexForSale = _mintIndexForSale + 1;
      }
    }

/*
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

    function mint_whitelist(uint256 requestedCount) public payable {
        require(publicMintEnabled, "The public sale is not enabled!");
        require(_lastCallBlockNumber[msg.sender].add(_antibotInterval) < block.number, "Bot is not allowed");
    
        require(whitelist_addr[msg.sender] == 0, "This User is Not in Whitelist");

        ++_mintIndexForSale;
        _safeMint(msg.sender,_mintIndexForSale);
        _lastCallBlockNumber[msg.sender] = block.number;
    }
*/
}