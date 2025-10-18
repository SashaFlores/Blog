// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract RevertingReceiver {

    receive() external payable {
        revert('Reverted Data');
    }

}
