// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ERC1155Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import { ERC1155SupplyUpgradeable } from
    '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { IERC165 } from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import { IBlog } from 'src/IBlog.sol';

/// @custom:oz-upgrades-from src/Blog.sol:Blog
contract BlogV2 is
    Initializable,
    IBlog,
    ERC1155Upgradeable,
    ERC1155SupplyUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{

    /// @custom:storage-location erc7201:sashaflores.storage.Blog
    struct BlogStorage {
        uint256 premiumFee;
    }

    // keccak256(abi.encode(uint256(keccak256("sashaflores.storage.Blog")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BlogStorageLocation = 0xd8bb604eb75c19d7b5da195a10139ccc9ca74bf453bffef10737af641b552500;

    /// @custom:storage-location erc7201:sashaflores.storage.Blog
    function _getBlogStorage() private pure returns (BlogStorage storage $) {
        assembly {
            $.slot := BlogStorageLocation
        }
    }

    // SAME CONSTANTS
    bytes32 public constant STANDARD = bytes32(uint256(1));
    bytes32 public constant PREMIUM = bytes32(uint256(2));

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // lock implementation (same as V1)
    }

    /// @custom:oz-upgrades-unsafe-allow missing-initializer-call
    function __Blog_init(address, uint256, string calldata) public override initializer { }

    // === METADATA ===
    function version() external pure override returns (string memory) {
        return '1.1.0';
    }

    function contractName() external pure override returns (string memory) {
        return 'Blog';
    }

    // === VIEWS ===
    function getPremiumFee() public view override returns (uint256) {
        return _getBlogStorage().premiumFee;
    }

    function balance() public view override returns (uint256) {
        return address(this).balance;
    }

    // === NEW FUNCTION (read-only; no storage change) BUT NOT ADDED TO IBlog ===
    function isPremiumHolder(
        address who
    ) external view returns (bool) {
        return balanceOf(who, uint256(PREMIUM)) > 0;
    }

    // === MONEY IN ===
    receive() external payable {
        emit FundsReceived(_msgSender(), msg.value);
    }

    // === ADMIN ===
    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function modifyUri(
        string memory newUri
    ) external override onlyOwner {
        _setURI(newUri);
    }

    function updatePremiumFee(
        uint256 newFee
    ) external override onlyOwner {
        BlogStorage storage $ = _getBlogStorage();
        if ($.premiumFee == newFee || newFee == 0) revert InvalidNewFee();
        $.premiumFee = newFee;
    }

    // === MINT ===
    function mint() external payable override whenNotPaused nonReentrant {
        _mint(_msgSender(), uint256(STANDARD), 1, '');
        if (msg.value > 0) emit FundsReceived(_msgSender(), msg.value);
    }

    function mintPremium(
        string calldata tokenURI
    ) public payable override whenNotPaused nonReentrant {
        uint256 fee = getPremiumFee();
        require(msg.value >= fee, LessThanPremiumFee(fee));
        _mint(_msgSender(), uint256(PREMIUM), 1, '');
        emit PremiumReceived(_msgSender(), tokenURI);
    }

    // === WITHDRAW CHANGED TO BE ACCESSIBLE WHEN NOT PAUSED===
    function withdraw(
        address payable des
    ) external override onlyOwner whenNotPaused nonReentrant {
        uint256 bal = address(this).balance;
        if (bal == 0) revert EmptyBalance();
        (bool ok, bytes memory ret) = des.call{ value: bal }('');
        if (!ok) {
            if (des.code.length > 0 && ret.length > 0) {
                assembly ("memory-safe") {
                    revert(add(ret, 32), mload(ret))
                }
            } else {
                revert WithdrawalFailedNoData();
            }
        }
        emit FundsWithdrawn(des, bal);
    }

    // === INTERNALS (same logic as V1 for URI + nontransferable premium) ===
    function _setURI(
        string memory newUri
    ) internal override {
        require(bytes(newUri).length > 0, EmptyURI());
        super._setURI(newUri);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) whenNotPaused {
        super._update(from, to, ids, values);
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == uint256(PREMIUM) && from != address(0)) {
                revert NonTransferrable();
            }
        }
    }

    // === UUPS ===
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {
        require(stringsEqual(IBlog(newImplementation).contractName(), this.contractName()), ContractNameChanged());
        require(!stringsEqual(IBlog(newImplementation).version(), this.version()), UpdateVersionToUpgrade());
    }

    // === ERC165 ===
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IBlog).interfaceId || super.supportsInterface(interfaceId);
    }

    function stringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

}
