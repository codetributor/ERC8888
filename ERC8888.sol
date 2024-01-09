//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract Royalty {

	/**
	 * @dev I am not too familar with ERC token standards, but what if we shift the control of the token away from the marketplaces.
	 * I am suggesting to remove the transfer and approve functionality
	 * 
	 * in place of that functionality we give the token owner the ability to change the boolean value of claimble;
	 * we give the token owner the ability to change the value of the token price;
	 * and we give the token owner the option to specify the claimant;
	 * 
	 * if the claimable boolean is true, then anyone can call the claim function(if there is no specified claimant) and send value in accordance to the token price
	 * so essencially we are cutting out the marketplace and the claimant calls the nft contract directly
	 * then we are able to enforce paying out the royalties
	 * 
	 * if the token holder does not want to sell or transfer the nft token, then can keep the claimable boolean to false
	 * and no one can claim the nft token
	 * 
	 * if the token owner wants to move the nft token to a different wallet, they can set the specified claimant to that wallet address
	 * they can set the price to zero
	 * then only that wallet can claim the nft token
	 * 
	 * the token owner has to specify the correct price, because if they try to do a side deal, the claimant will have the nft already
	 * and have no incentive to pay more to the previous nft token holder. The exchange would have happened at the specified price
	 * 
	 * if people try to use marketplaces as thirdparties and give the nft token to the marketplace at zero price and have them
	 * facilitate the trade, we can blacklist that address of the marketplace
	 */

	string private _name;
	string private _symbol;
	uint256 _nextTokenId = 0;

	struct Token {
		uint256 tokenId;
		address tokenOwner;
		bool claimable;
		address specifiedClaimant;
		bool isSpecifiedClaimant;
		uint256 price;
		string uri;
		uint256 royalty;
		address marketplaceAddress;
		uint marketplaceFee;
		bool isMarketplace;
	}

	mapping(address owner => Token[]) private _balances;
	mapping(uint256 tokenId => Token) private tokens;

	address[] blacklist;
	
	constructor(string memory name, string memory symbol) {
		_name = name;
		_symbol = symbol;
	}

	function checkIfBlacklisted(address _receipient) private view returns(bool) {
		for(uint i = 0; i < blacklist.length; i++) {
			if(_receipient == blacklist[i]) {
				return true;
			}
		}
		return false;
	}

	function mint() public {
		uint256 tokenId = _nextTokenId++;
		Token memory token = Token(tokenId, msg.sender, false, address(0), false, 0, "", 20, address(0), 0, false);
		tokens[tokenId] = token;
		_balances[msg.sender].push(token);
	}

	function makeClaimable(uint256 _tokenId, uint256 _price, bool _isSpecifiedClaimant) public {
		require(tokens[_tokenId].tokenOwner == msg.sender, "you are not the owner");
		tokens[_tokenId].claimable = true;
		tokens[_tokenId].price = _price;
		tokens[_tokenId].isSpecifiedClaimant =_isSpecifiedClaimant;
	}

	function changePrice(uint256 _tokenId, uint256 _price) public {
		require(tokens[_tokenId].tokenOwner == msg.sender, "you are not the owner");
		tokens[_tokenId].price = _price;
	}

	function setSpecifiedClaimant(address _specifiedClaimant, uint256 _tokenId) public {
		require(tokens[_tokenId].tokenOwner == msg.sender, "you are not the owner");
		require(checkIfBlacklisted(_specifiedClaimant) == false, "blacklisted");
		tokens[_tokenId].isSpecifiedClaimant = true; 
		tokens[_tokenId].specifiedClaimant = _specifiedClaimant;
	}

	function addToMarketplace(uint256 _tokenId, address _marketAddress, uint256 _marketFee) public {
		tokens[_tokenId].isMarketplace = true;
		tokens[_tokenId].marketplaceFee = _marketFee;
		tokens[_tokenId].marketplaceAddress = _marketAddress;
	}

	function claim(uint256 _tokenId) public payable {
		require( tokens[_tokenId].price <= msg.value, "you did not send enough currency");
		uint royaltyPercentage = tokens[_tokenId].royalty;
		uint sellValue = msg.value * (100 - royaltyPercentage)/100;
		uint royaltyFee= msg.value * royaltyPercentage/100;
		payout(_tokenId, royaltyFee, sellValue);
		
	}

	function payout(uint256 _tokenId, uint256 _royaltyFee, uint256 _sellValue) public {
		if(tokens[_tokenId].isSpecifiedClaimant) {
			require(checkIfBlacklisted(msg.sender) == false, "blacklisted");
			require(tokens[_tokenId].specifiedClaimant == msg.sender, "you are not the specified claimant");
			(bool success0, ) = tokens[_tokenId].tokenOwner.call{value: _sellValue}(""); 
			(bool success1, ) = address(this).call{value: _royaltyFee}("");
			removeToken(_tokenId, tokens[_tokenId].tokenOwner);
			tokens[_tokenId].tokenOwner = msg.sender;
			require(success0 && success1, "distribution did not go through");
		} else {
			(bool success0, ) = tokens[_tokenId].tokenOwner.call{value: _sellValue}(""); 
			(bool success1, ) = address(this).call{value: _royaltyFee}("");
			removeToken(_tokenId, tokens[_tokenId].tokenOwner);
			tokens[_tokenId].tokenOwner = msg.sender;
			require(success0 && success1, "distribution did not go through");
		}
	}

	function removeToken(uint256 _tokenId, address _previousOwner) public {
		for(uint i = 0; i < _balances[_previousOwner].length; i++) {
			if(_tokenId == _balances[_previousOwner][i].tokenId) {
				_balances[_previousOwner][i] = _balances[_previousOwner][_balances[_previousOwner].length - 1];
				_balances[_previousOwner].pop();
			}
		}
	}
}