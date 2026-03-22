// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol"; // Optional: for admin functions like parameter updates

/**
 * @title ErgoCity
 * @notice An educational DApp demonstrating ergodicity.
 * Players choose daily odds and volatility. Mathematically, individual scores
 * trend towards zero over time, while the ensemble average score increases.
 * This version uses pre-calculated discrete parameters and simple on-chain randomness.
 */
contract ErgoCity is Ownable {

    // --- Constants ---
    uint256 public constant PERCENTAGE_BASE = 10000; // Represents 100.00% (e.g., 2910 means 29.10%)
    uint8 public constant NUM_SETTINGS = 6;       // 6 discrete choices for the player
    uint256 public constant INITIAL_SCORE = 1000 * PERCENTAGE_BASE; // Initial score, e.g., 1000.00
    uint256 public constant MINIMUM_SCORE_TO_PLAY = 1; // Smallest score unit to be able to play
    uint256 public constant DAILY_COOLDOWN = 24 hours; // Cooldown between plays for a player

    // Pre-calculated Game Parameters (scaled by PERCENTAGE_BASE)
    // Index 0: Pwin=0.55, L=0.3000, G=0.2910
    // Index 1: Pwin=0.60, L=0.4200, G=0.3907
    // Index 2: Pwin=0.65, L=0.5400, G=0.4731
    // Index 3: Pwin=0.70, L=0.6600, G=0.5431
    // Index 4: Pwin=0.75, L=0.7800, G=0.6129
    // Index 5: Pwin=0.80, L=0.9000, G=0.7343
    uint256[NUM_SETTINGS] public pWinValues =  [5500, 6000, 6500, 7000, 7500, 8000];
    uint256[NUM_SETTINGS] public lossFactors = [3000, 4200, 5400, 6600, 7800, 9000];
    uint256[NUM_SETTINGS] public gainFactors = [2910, 3907, 4731, 5431, 6129, 7343];

    // --- Player State ---
    mapping(address => uint256) public playerScores;
    mapping(address => uint256) public lastPlayTimestamp;
    mapping(address => bool) public playerHasRegistered;

    // --- Ensemble State ---
    uint256 public totalSystemScore;
    uint256 public registeredPlayerCount;

    // --- Events ---
    event PlayerRegistered(address indexed player, uint256 initialScore);
    event PlayerReset(address indexed player, uint256 newScore);
    event PlayMade(
        address indexed player,
        uint8 settingChoice,
        bool won,
        uint256 oldScore,
        uint256 newScore
    );
    event EnsembleStatsUpdated(uint256 newTotalSystemScore, uint256 newRegisteredPlayerCount);

    // --- Errors ---
    error ErgoCity_InvalidSettingChoice();
    error ErgoCity_PlayerNotRegistered();
    error ErgoCity_PlayerHasScoreAndCannotReRegister();
    error ErgoCity_ScoreTooLowToPlay();
    error ErgoCity_PlayerIsBankrupt();
    error ErgoCity_PlayerNotBankruptCannotReset();
    error ErgoCity_PlayOnCooldown();

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Allows a new player to register and receive an initial score.
     * A player can only register if they haven't registered before or if their score is 0 (to re-register after bankruptcy).
     */
    function register() external {
        if (playerHasRegistered[msg.sender] && playerScores[msg.sender] > 0) {
            revert ErgoCity_PlayerHasScoreAndCannotReRegister();
        }

        if (!playerHasRegistered[msg.sender]) {
            playerHasRegistered[msg.sender] = true;
            registeredPlayerCount++;
        }
        
        totalSystemScore -= playerScores[msg.sender]; // Subtract old score if it was 0 (no effect)
        playerScores[msg.sender] = INITIAL_SCORE;
        totalSystemScore += INITIAL_SCORE;
        lastPlayTimestamp[msg.sender] = 0; // Allow immediate play after registration/reset

        emit PlayerRegistered(msg.sender, INITIAL_SCORE);
        emit EnsembleStatsUpdated(totalSystemScore, registeredPlayerCount);
    }

    /**
     * @notice Allows a player with a score of 0 to reset their score to the initial amount.
     */
    function resetScoreIfBankrupt() external {
        if (!playerHasRegistered[msg.sender]) {
            revert ErgoCity_PlayerNotRegistered();
        }
        if (playerScores[msg.sender] > 0) {
            revert ErgoCity_PlayerNotBankruptCannotReset();
        }

        playerScores[msg.sender] = INITIAL_SCORE;
        totalSystemScore += INITIAL_SCORE; // Add the new initial score to the total
        lastPlayTimestamp[msg.sender] = 0; // Allow immediate play

        emit PlayerReset(msg.sender, INITIAL_SCORE);
        emit EnsembleStatsUpdated(totalSystemScore, registeredPlayerCount);
    }


    /**
     * @notice Player chooses a setting (0-5) and makes their daily play.
     * @param _settingChoice Integer from 0 to (NUM_SETTINGS - 1).
     */
    function play(uint8 _settingChoice) external {
        if (_settingChoice >= NUM_SETTINGS) {
            revert ErgoCity_InvalidSettingChoice();
        }
        if (!playerHasRegistered[msg.sender]) {
            revert ErgoCity_PlayerNotRegistered();
        }
        if (playerScores[msg.sender] == 0) {
            revert ErgoCity_PlayerIsBankrupt(); // Should call resetScoreIfBankrupt
        }
        if (playerScores[msg.sender] < MINIMUM_SCORE_TO_PLAY) {
            revert ErgoCity_ScoreTooLowToPlay();
        }
        if (block.timestamp < lastPlayTimestamp[msg.sender] + DAILY_COOLDOWN) {
            revert ErgoCity_PlayOnCooldown();
        }

        uint256 pWin = pWinValues[_settingChoice];
        uint256 lossFactor = lossFactors[_settingChoice];
        uint256 gainFactor = gainFactors[_settingChoice];
        uint256 oldScore = playerScores[msg.sender];
        uint256 newScore = oldScore;

        // --- On-chain Pseudo-Randomness ---
        // WARNING: Not cryptographically secure. Suitable for educational purposes where
        // the long-term math is the focus, not individual roll security.
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1), // Recent blockhash
            msg.sender,                  // Player address
            oldScore,                    // Current score
            block.timestamp,             // Current timestamp
            _settingChoice               // Chosen setting
        )));
        bool won = (randomSeed % PERCENTAGE_BASE) < pWin;
        // --- End Randomness ---

        uint256 scoreChange;
        if (won) {
            scoreChange = (oldScore * gainFactor) / PERCENTAGE_BASE;
            newScore = oldScore + scoreChange;
        } else {
            scoreChange = (oldScore * lossFactor) / PERCENTAGE_BASE;
            if (scoreChange >= oldScore) { // Prevents underflow if loss is >100% or due to rounding
                newScore = 0; // Player loses entire score
            } else {
                newScore = oldScore - scoreChange;
            }
        }

        playerScores[msg.sender] = newScore;
        lastPlayTimestamp[msg.sender] = block.timestamp;

        // Update total system score
        totalSystemScore = totalSystemScore - oldScore + newScore;

        emit PlayMade(msg.sender, _settingChoice, won, oldScore, newScore);
        emit EnsembleStatsUpdated(totalSystemScore, registeredPlayerCount);
    }

    // --- View Functions ---

    function getPlayerScore(address _player) external view returns (uint256) {
        return playerScores[_player];
    }

    function getGameParameters(uint8 _settingChoice)
        external
        view
        returns (uint256 pWin, uint256 lossFactor, uint256 gainFactor)
    {
        if (_settingChoice >= NUM_SETTINGS) {
            revert ErgoCity_InvalidSettingChoice();
        }
        return (
            pWinValues[_settingChoice],
            lossFactors[_settingChoice],
            gainFactors[_settingChoice]
        );
    }

    function getEnsembleAverageScore() external view returns (uint256) {
        if (registeredPlayerCount == 0) {
            return 0;
        }
        // Average score will also be scaled by PERCENTAGE_BASE
        return totalSystemScore / registeredPlayerCount; // Integer division
    }
    
    function getTimeUntilNextPlay(address _player) external view returns (uint256) {
        if (!playerHasRegistered[msg.sender]) {
            // If player not registered, arguably they can't have a "next play time"
            // or it should indicate they need to register. Returning 0 implies they can play (or register).
            // Alternatively, revert or return a specific value indicating not registered.
            // For simplicity, returning 0 here means if they register, they can play immediately.
            return 0; 
        }
        uint256 nextPlayTime = lastPlayTimestamp[_player] + DAILY_COOLDOWN;
        if (block.timestamp >= nextPlayTime) {
            return 0;
        }
        return nextPlayTime - block.timestamp;
    }

    // --- Admin Functions (Optional, requires Ownable) ---
    /**
     * @notice Owner can update the game parameter arrays.
     * Ensure arrays are of length NUM_SETTINGS.
     */
    function updateGameParameters(
        uint256[] memory _newPWinValues,
        uint256[] memory _newLossFactors,
        uint256[] memory _newGainFactors
    ) external onlyOwner {
        require(_newPWinValues.length == NUM_SETTINGS, "PWin length mismatch");
        require(_newLossFactors.length == NUM_SETTINGS, "LossFactors length mismatch");
        require(_newGainFactors.length == NUM_SETTINGS, "GainFactors length mismatch");

        // Copy elements one by one from memory arrays to storage arrays
        for (uint8 i = 0; i < NUM_SETTINGS; i++) {
            pWinValues[i] = _newPWinValues[i];
            lossFactors[i] = _newLossFactors[i];
            gainFactors[i] = _newGainFactors[i];
        }
    }

    // Example placeholder for other admin functions.
    // function setInitialScore(uint256 _newInitialScore) external onlyOwner {
    //     // This would require INITIAL_SCORE to not be constant or an upgradable contract.
    //     revert("Changing INITIAL_SCORE requires modifying the constant and redeploying or using upgradable contracts.");
    // }
}