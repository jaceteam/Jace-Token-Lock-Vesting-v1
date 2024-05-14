// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

 /**
 * @title JaceTokenLockTeamV1
 * @dev Contract for locking and vesting 49% of the JACE token's total supply.
 * Tokens will be released in 7 stages based on the tokenomics outlined in the JACE tokenomics.
 * @notice For more information, visit https://jace.team/jace-tokenomics
 * @notice For support or inquiries, contact dev@jace.team
 */
contract JaceTokenLockVestingV1 is ReentrancyGuard {

    // SafeERC20 is a library from OpenZeppelin Contracts, ensuring safe ERC20 token transfers.
    using SafeERC20 for IERC20;

    // JACE token contract instance.
    IERC20 jaceToken = IERC20(0x0305ce989f3055a6Da8955fc52b615b0086A2157);

    // The address of the vesting wallet.
    address constant vestingWallet = 0xc39B1402a43C623438C30EB5989AAF3CAa59c221;

    // This Variable provides the times when a percentage of the locked tokens is released.
    uint[7] tokensLockupPeriodCycles = [
        1744202727, // April, 2025 | (13.3% of locekd tokens)
        1763037927, // November, 2025 | (13.3% of locekd tokens)
        1772714727, // March, 2026 | (13.3% of locekd tokens)
        1797338727, // December, 2026 | (13.3% of locekd tokens)
        1810817127, // May, 2027 | (13.3% of locekd tokens)
        1829047527, // December, 2027 | (13.3% of locekd tokens)
        1838376000 // April, 2028 | (20.2% of locekd tokens)
    ];

    // Admin address.
    address immutable admin;

    // totalJaceClaimed tracks the total number of the JACE tokens claimed by the vesting wallet.
    uint totalJaceClaimed = 0;

    // totalJaceLocked represents the total number of the JACE tokens locked in the contract.
    uint totalJaceLocked = 0;

    // Event emitted upon the locking of JACE tokens.
    event JaceTokensLocked(address indexed walletAddress, uint amountLocked);

    // Event emitted upon successful claiming of JACE tokens after the lockup period.
    event JaceTokensClaimed(address indexed recipient, uint amountJace);

    // Event emitted when the admin withdraws the remaining JACE tokens after 30 days have passed since the last release time.
    event RemainingJaceTokensWithdrawByAdmin(address indexed withdrawAddress, uint withdrawAmount);

    constructor() {
        admin = msg.sender;
    }

    // Modifier to restrict access to admin.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    // Modifier to restrict access to vesting wallet.
    modifier onlyVestingWallet() {
        require(msg.sender == vestingWallet, "Only vesting wallet can call this function");
        _;
    }

    // This function retrieves essential details about the contract.
    function getContractDetails() external view
    returns (
        uint _contractJaceBalance,
        address _vestingWalletAddress,
        uint _totalJaceLocked,
        uint _totalJaceClaimed,
        uint[7] memory _tokensLockupPeriodCycles
    ) {
        return (
            jaceToken.balanceOf(address(this)),
            vestingWallet,
            totalJaceLocked,
            totalJaceClaimed,
            tokensLockupPeriodCycles
        );
    }

    // Function to lock a specified amount of JACE tokens, restricting them from being transferred by the sender.
    function lockJaceTokens(uint _jaceAmountToLock) external onlyVestingWallet nonReentrant returns (bool) {
        require(_jaceAmountToLock > 0, "Amount must be greater than 0");

        require(jaceToken.balanceOf(vestingWallet) >= _jaceAmountToLock, "Insufficient JACE token");

        require(_jaceAmountToLock <= jaceToken.allowance(vestingWallet, address(this)), "Make sure to add enough allowance");

        jaceToken.safeTransferFrom(vestingWallet, address(this), _jaceAmountToLock);
        
        totalJaceLocked += _jaceAmountToLock;

        emit JaceTokensLocked(vestingWallet, _jaceAmountToLock); 

        return true;
    }

    // Function to claim JACE tokens according to each lockup period cycle.
    function claimJaceTokens() external onlyVestingWallet nonReentrant {
        require(jaceToken.balanceOf(address(this)) > 0, "Nothing to claim");

        require(tokensLockupPeriodCycles[0] <= block.timestamp, "Lockup period has not ended yet");
        
        uint claimableTokens = 0;
        for (uint i = 0; i < 7; i++) {
            if (tokensLockupPeriodCycles[i] <= block.timestamp) {
                if (i < 6) {
                    claimableTokens += totalJaceLocked * 133 / 1000;
                } else {
                    claimableTokens += totalJaceLocked * 202 / 1000;
                }
            }
        }

        claimableTokens -= totalJaceClaimed;
        
        require(claimableTokens > 0, "Nothing to claim");

        jaceToken.safeTransfer(vestingWallet, claimableTokens);

        totalJaceClaimed += claimableTokens;

        emit JaceTokensClaimed(vestingWallet, claimableTokens);
    }

    // Allows the admin to withdraw the remaining Jace tokens after 30 days have passed since the last release time.
    function withdrawRemainingTokens(address _to) external onlyAdmin {
        require (tokensLockupPeriodCycles[6] + 30 days <= block.timestamp, "Lockup period for the 7th cycle has not elapsed yet");

        require(_to != address(0), "Invalid recipient address");

        uint withdrawAmount = jaceToken.balanceOf(address(this));
        require(withdrawAmount > 0, "Nothing to transfer");

        jaceToken.safeTransfer(_to, withdrawAmount);

        emit RemainingJaceTokensWithdrawByAdmin(_to, withdrawAmount);
    }
}