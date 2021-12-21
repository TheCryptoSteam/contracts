
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//                   Version 2, December 2004
// 
//CryptoSteam @2021,All rights reserved
//
//Everyone is permitted to copy and distribute verbatim or modified
//copies of this license document, and changing it is allowed as long
//as the name is changed.
// 
//           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
//  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
//
// You just DO WHAT THE FUCK YOU WANT TO.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

uint256 constant CST_MAX_SUPPLY = 1000000000 gwei;

contract VaultOwned is Ownable {

    address internal _vault;

    function setVault( address vault_ ) external onlyOwner() returns ( bool ) {
        _vault = vault_;

        return true;
    }

    function vault() public view returns (address) {
        return _vault;
    }

    modifier onlyVault() {
        require( _vault == msg.sender, "VaultOwned: caller is not the Vault" );
        _;
    }

}


contract CstERC20Token is ERC20Permit, VaultOwned {
    uint256 private immutable _cap;

    constructor()
        ERC20Permit("CST Token")
        ERC20("CST Token", "CST")
    {
        _cap = CST_MAX_SUPPLY;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }


    function decimals() public view virtual override returns (uint8) {
        return 9;
    }


    function mint(address account_, uint256 amount_) external onlyVault() {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) public virtual {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) public virtual {
        uint256 decreasedAllowance_ = allowance(account_, msg.sender)-amount_;

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }
}