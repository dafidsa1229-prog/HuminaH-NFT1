// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    ██╗  ██╗██╗   ██╗███╗   ███╗██╗███╗   ██╗ █████╗ ██╗  ██╗
    ██║  ██║██║   ██║████╗ ████║██║████╗  ██║██╔══██╗██║  ██║
    ███████║██║   ██║██╔████╔██║██║██╔██╗ ██║███████║███████║
    ██╔══██║██║   ██║██║╚██╔╝██║██║██║╚██╗██║██╔══██║██╔══██║
    ██║  ██║╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║██║  ██║██║  ██║
    ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝
    
    H U M I N A H    N F T    C O L L E C T I O N
    Created with ❤️ by Dafid Saeful Arifin
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract HuminaH is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string private baseTokenURI;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public mintPrice = 0.01 ether;
    bool public isMintingActive = false;

    uint256 public constant MAX_PER_WALLET = 20;
    mapping(address => uint256) public walletMintCount;

    bool public isBaseURILocked = false;
    bool public isMintPriceLocked = false;
    uint256 public maxWithdrawPerTx = 50 ether;

    mapping(address => uint256) public pendingWithdrawals;

    // Events
    event Mint(address indexed minter, uint256 tokenId);
    event WithdrawQueued(address indexed owner, uint256 amount);
    event BaseURIChanged(string newBaseURI);
    event MintPriceChanged(uint256 newPrice);
    event MintingStateChanged(bool newState);
    event BaseURILocked();
    event MintPriceLocked();

    constructor(string memory _initBaseURI)
        ERC721("HuminaH NFT Collection", "HMH")
        Ownable(msg.sender)
    {
        require(bytes(_initBaseURI).length > 0, "Base URI tidak boleh kosong");
        baseTokenURI = _initBaseURI;
    }

    function mintNFT(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(isMintingActive, "Minting belum dibuka");
        require(_mintAmount >= 1 && _mintAmount <= 10, "Mint 1-10 NFT per transaksi");
        require(walletMintCount[msg.sender] + _mintAmount <= MAX_PER_WALLET, "Maksimal 20 NFT per wallet");
        require(supply + _mintAmount <= MAX_SUPPLY, "Supply habis");
        require(msg.value >= mintPrice * _mintAmount, "ETH tidak cukup");

        walletMintCount[msg.sender] += _mintAmount;

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 tokenId = supply + i;
            _safeMint(msg.sender, tokenId);
            emit Mint(msg.sender, tokenId);
        }
    }

    function ownerMint(address to, uint256 _mintAmount) public onlyOwner {
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= MAX_SUPPLY, "Supply habis");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 tokenId = supply + i;
            _safeMint(to, tokenId);
            emit Mint(to, tokenId);
        }
    }

    function setMintingActive(bool _state) public onlyOwner {
        isMintingActive = _state;
        emit MintingStateChanged(_state);
    }

    function setMintPrice(uint256 _newPrice) public onlyOwner {
        require(!isMintPriceLocked, "Mint price sudah dikunci");
        require(_newPrice > 0, "Mint price harus > 0");
        mintPrice = _newPrice;
        emit MintPriceChanged(_newPrice);
    }

    function lockMintPrice() public onlyOwner {
        isMintPriceLocked = true;
        emit MintPriceLocked();
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(!isBaseURILocked, "Base URI sudah dikunci");
        require(bytes(_newBaseURI).length > 0, "Base URI tidak boleh kosong");
        baseTokenURI = _newBaseURI;
        emit BaseURIChanged(_newBaseURI);
    }

    function lockBaseURI() public onlyOwner {
        isBaseURILocked = true;
        emit BaseURILocked();
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token belum ada");
        return string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }

    function queueWithdraw(uint256 amount) public onlyOwner {
        require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        require(amount <= maxWithdrawPerTx, "Amount melebihi limit per tx");
        pendingWithdrawals[msg.sender] += amount;
        emit WithdrawQueued(msg.sender, amount);
    }

    function executeWithdraw() public nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {}
    fallback() external payable {}
}
