// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IBlog } from './IBlog.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ERC1155Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import { ERC1155SupplyUpgradeable } from'@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { IERC165 } from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

contract Blog is
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
    // aderyn-ignore-next-line(unused-state-variable)
    bytes32 private constant BlogStorageLocation = 0xd8bb604eb75c19d7b5da195a10139ccc9ca74bf453bffef10737af641b552500;

    function _getBlogStorage() private pure returns (BlogStorage storage $) {
        assembly {
            $.slot := BlogStorageLocation
        }
    }

    // Define constants for token types
    bytes32 public constant STANDARD = bytes32(uint256(1));
    bytes32 public constant PREMIUM = bytes32(uint256(2));

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __Blog_init(address initialOwner, uint256 premiumFee, string calldata _uri) public virtual initializer {
        __ERC1155_init(_uri);
        __ERC1155Supply_init();
        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Blog_init_unchained(premiumFee);
    }

    function __Blog_init_unchained(
        uint256 premiumFee
    ) internal virtual onlyInitializing {
        _setPremiumFee(premiumFee);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IBlog).interfaceId || super.supportsInterface(interfaceId);
    }

    function version() external pure virtual returns (string memory) {
        return '1.0.0';
    }

    function contractName() external pure virtual returns (string memory) {
        return 'Blog';
    }

    function getPremiumFee() public view virtual returns (uint256) {
        BlogStorage storage $ = _getBlogStorage();
        return $.premiumFee;
    }

    receive() external payable {
        emit FundsReceived(_msgSender(), msg.value);
    }

    // aderyn-ignore-next-line(centralization-risk)
    function pause() external virtual onlyOwner {
        _pause();
    }

    // aderyn-ignore-next-line(centralization-risk)
    function unpause() external virtual onlyOwner {
        _unpause();
    }

    function balance() public view virtual returns (uint256) {
        return address(this).balance;
    }

    // aderyn-fp-next-line(state-change-without-event, centralization-risk)
    function modifyUri(string memory newUri) external virtual onlyOwner {
        _setURI(newUri);
    }

    function mint() external payable virtual nonReentrant whenNotPaused {
        _mint(_msgSender(), uint256(STANDARD), 1, '');
        if (msg.value > 0) emit FundsReceived(_msgSender(), msg.value);
    }

    function mintPremium(
        string calldata tokenURI
    ) public payable virtual nonReentrant whenNotPaused {
        uint256 fee = getPremiumFee();
        require(msg.value >= fee, LessThanPremiumFee(fee));

        _mint(_msgSender(), uint256(PREMIUM), 1, '');

        emit PremiumReceived(_msgSender(), tokenURI);
    }

    // aderyn-ignore-next-line(centralization-risk)
    function withdraw(address payable des) external virtual nonReentrant onlyOwner {
        uint256 bal = address(this).balance;
        if (bal == 0) revert EmptyBalance();

        (bool success, bytes memory returnData) = des.call{ value: bal }('');

        if (!success) {
            if (des.code.length > 0 && returnData.length > 0) {
                assembly ("memory-safe") {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert WithdrawalFailedNoData();
            }
        }
        emit FundsWithdrawn(des, bal);
    }

    // aderyn-ignore-next-line(centralization-risk, state-change-without-event)
    function updatePremiumFee(uint256 newFee) external virtual onlyOwner {
        _setPremiumFee(newFee);
    }

    function _setPremiumFee(
        uint256 newFee
    ) internal virtual {
        BlogStorage storage $ = _getBlogStorage();
        if ($.premiumFee == newFee || newFee == 0) revert InvalidNewFee();
        $.premiumFee = newFee;
    }

    function _setURI(
        string memory newUri
    ) internal virtual override {
        require(bytes(newUri).length > 0, EmptyURI());
        super._setURI(newUri);
    }

    // aderyn-ignore-next-line(centralization-risk)
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {
        require(stringsEqual(IBlog(newImplementation).contractName(), this.contractName()), ContractNameChanged());
        require(!stringsEqual(IBlog(newImplementation).version(), this.version()), UpdateVersionToUpgrade());
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(
        ERC1155Upgradeable, 
        ERC1155SupplyUpgradeable
    ) whenNotPaused {
        super._update(from, to, ids, values);

        bool attemptedPremiumTransfer;
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == uint256(PREMIUM) && from != address(0)) {
                attemptedPremiumTransfer = true;
            }
        }
        if (attemptedPremiumTransfer) {
            revert NonTransferrable();
        }
    }

    function stringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

}
