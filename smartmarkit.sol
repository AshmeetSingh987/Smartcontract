//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Counters.sol';


contract Loop is ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    Counters.Counter private _tokensSold;

    address payable public owner;  //main wallet
    address payable public admin; //cloud function address

    uint256 listingPrice =  0.0 ether;

    constructor(address adminAddress,address ownerAddress) {
        owner = payable(ownerAddress);
        admin = payable(adminAddress);
    }

    struct MarketToken{
        uint itemId;
        address nftContract;
        uint tokenId;
        address payable seller;
        address payable owner;
        uint price;
        bool sold;
        bool refund;
    }

    mapping(uint => MarketToken) private idToMarketToken;

    event MarketTokenMinted(
        uint indexed itemId,
        address indexed nftContract,
        uint indexed tokenId,
        address seller,
        address owner,
        uint price,
        bool sold,
        bool refund
    );

    function getListingPrice() public view returns(uint){
        return listingPrice;
    }

    function makeMarketItem(address nftContract,uint tokenId,uint price) public payable nonReentrant {
            require(price > 0,'Price must be more than 1 wei');
            _tokenIds.increment();
            uint itemId = _tokenIds.current();
            idToMarketToken[itemId] = MarketToken(itemId,nftContract,tokenId,payable(msg.sender),payable(address(0)),price,false,false);

            // NFT transaction
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);


            emit MarketTokenMinted(itemId, nftContract, tokenId, msg.sender, address(0), price, false,false);
            
    }

    
            function createMarketSale(address nftContract,uint itemId) public payable nonReentrant {
                uint price = idToMarketToken[itemId].price;
                uint tokenId = idToMarketToken[itemId].tokenId;
                require(msg.value == price, 'Please submit the asking price in order to continue!!');

                idToMarketToken[itemId].seller.transfer( (price) - ((price/100)*5));
                IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
                idToMarketToken[itemId].owner = payable(msg.sender);
                idToMarketToken[itemId].sold = true;
                _tokensSold.increment();

                //payable(owner).transfer(listingPrice);
            }
            
            function refundCall(uint itemId, bool refund) public nonReentrant {
                uint price = idToMarketToken[itemId].price;
                require(payable(msg.sender) == admin, 'Only admin can call this function');
                idToMarketToken[itemId].refund = true;
                if(refund){
                    payable(idToMarketToken[itemId].seller).transfer((price/1000)*25);
                    payable(owner).transfer((price/1000)*25);
                }
                else {
                    payable(owner).transfer((price/100)*5);
                }

            }
            
            
            function changeAdmin(address newAdmin) public nonReentrant {
                require(payable(msg.sender) == admin, 'Only admin can call this function');
                admin = payable(newAdmin);
            }
            
            function changeOwner(address newOwner) public nonReentrant {
                require(payable(msg.sender) == owner, 'Only owner can call this function');
                admin = payable(newOwner);
            }

            function fetchMarketToken() public view returns(MarketToken[] memory){
                uint itemCount = _tokenIds.current();
                uint unsoldItemCount = _tokenIds.current() - _tokensSold.current();
                uint currentIndex = 0;

                MarketToken[] memory items = new MarketToken[](unsoldItemCount);
                for(uint i=0;i<itemCount;i++){
                    if(idToMarketToken[i+1].owner == address(0)){
                        uint currentId = i + 1;
                        MarketToken storage currentItem = idToMarketToken[currentId];
                        items[currentIndex] = currentItem;
                        currentIndex += 1;

                    }
                }
                return items;
            }

            function fetchMyNFTs() public view returns(MarketToken[] memory){
                uint totalItemCount = _tokenIds.current();
                uint itemCount = 0;
                uint currentIndex = 0;

                for(uint i = 0; i<totalItemCount;i++){
                    if(idToMarketToken[i+1].owner == msg.sender ){
                        itemCount += 1;

                    }
                }

                MarketToken[] memory items = new MarketToken[](itemCount);
                for(uint i=0;i<totalItemCount;i++){
                    if(idToMarketToken[i+1].owner == msg.sender){
                        uint currentId = idToMarketToken[i+1].itemId;
                        MarketToken storage currentItem = idToMarketToken[currentId];
                        items[currentIndex] = currentItem;
                        currentIndex += 1;

                    }
                }  
                return items;  
            }

            function fetchItemsCreated() public view returns(MarketToken[] memory) {
                uint totalItemCount = _tokenIds.current();
                uint itemCount = 0;
                uint currentIndex = 0;

                 MarketToken[] memory items = new MarketToken[](itemCount);
                for(uint i=0;i<totalItemCount;i++){
                    if(idToMarketToken[i+1].seller == msg.sender){
                        uint currentId = idToMarketToken[i+1].itemId;
                        MarketToken storage currentItem = idToMarketToken[currentId];
                        items[currentIndex] = currentItem;
                        currentIndex += 1;

                    }
                }  
                return items;  
            }
}
