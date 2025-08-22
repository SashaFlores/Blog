// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC1155Holder } from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import { ERC1155 } from '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import { IBlog, Blog } from 'src/Blog.sol';

contract MockMinterMissingHolder {

    
    IBlog public blog;

    constructor(address blogAddress) {
        blog = IBlog(blogAddress);
    }

    function mintStandardToken() external payable{
        blog.mint();
    }
}

contract MockMinter is ERC1155Holder {

    IBlog public blog;

    constructor(address blogAddress) {
        blog = IBlog(blogAddress);
    }

    function mintPremiumToken(string calldata uri) external payable {
        blog.mintPremium(uri);
    }
}

