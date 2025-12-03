// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Encrypted Crypto Credit Scoring Platform
/// @notice Uses FHE (Zama) to handle encrypted credit data, blind bids, and secure settlements
contract EncryptedCreditScore is SepoliaConfig {

    /// @notice Represents an encrypted credit score submission
    struct EncryptedSubmission {
        uint256 id;
        euint32 encryptedScore;       // Encrypted credit score
        euint32 encryptedCategory;    // Encrypted credit category
        uint256 encryptedBid;         // Optional encrypted bid for blind auction
        uint256 timestamp;
    }

    /// @notice Decrypted credit score information
    struct DecryptedScore {
        uint32 score;
        string category;
        bool isRevealed;
    }

    uint256 public submissionCount;
    mapping(uint256 => EncryptedSubmission) public encryptedSubmissions;
    mapping(uint256 => DecryptedScore) public decryptedScores;

    // Encrypted category count tracking
    mapping(string => euint32) private encryptedCategoryCount;
    string[] private categoryList;

    // Mapping decryption requests to submissions
    mapping(uint256 => uint256) private requestToSubmissionId;

    // Events
    event SubmissionCreated(uint256 indexed id, uint256 timestamp);
    event DecryptionRequested(uint256 indexed id);
    event SubmissionDecrypted(uint256 indexed id);
    event BlindBidSettled(uint256 indexed id, uint256 payout);

    modifier onlySubmitter(uint256 submissionId) {
        // Add real access control in production
        _;
    }

    /// @notice Submit a new encrypted credit score
    function submitEncryptedScore(
        euint32 encryptedScore,
        euint32 encryptedCategory,
        uint256 encryptedBid
    ) public {
        submissionCount += 1;
        uint256 newId = submissionCount;

        encryptedSubmissions[newId] = EncryptedSubmission({
            id: newId,
            encryptedScore: encryptedScore,
            encryptedCategory: encryptedCategory,
            encryptedBid: encryptedBid,
            timestamp: block.timestamp
        });

        decryptedScores[newId] = DecryptedScore({
            score: 0,
            category: "",
            isRevealed: false
        });

        emit SubmissionCreated(newId, block.timestamp);
    }

    /// @notice Request decryption of a submission (credit score)
    function requestDecryption(uint256 submissionId) public onlySubmitter(submissionId) {
        EncryptedSubmission storage submission = encryptedSubmissions[submissionId];
        require(!decryptedScores[submissionId].isRevealed, "Already decrypted");

        bytes32 ;
        ciphertexts[0] = FHE.toBytes32(submission.encryptedScore);
        ciphertexts[1] = FHE.toBytes32(submission.encryptedCategory);

        uint256 reqId = FHE.requestDecryption(ciphertexts, this.decryptSubmission.selector);
        requestToSubmissionId[reqId] = submissionId;

        emit DecryptionRequested(submissionId);
    }

    /// @notice Callback for decrypted submission data
    function decryptSubmission(
        uint256 requestId,
        bytes memory cleartexts,
        bytes memory proof
    ) public {
        uint256 submissionId = requestToSubmissionId[requestId];
        require(submissionId != 0, "Invalid request");

        DecryptedScore storage dScore = decryptedScores[submissionId];
        require(!dScore.isRevealed, "Already decrypted");

        FHE.checkSignatures(requestId, cleartexts, proof);

        (uint32 score, string memory category) = abi.decode(cleartexts, (uint32, string));

        dScore.score = score;
        dScore.category = category;
        dScore.isRevealed = true;

        // Update category count
        if (!FHE.isInitialized(encryptedCategoryCount[category])) {
            encryptedCategoryCount[category] = FHE.asEuint32(0);
            categoryList.push(category);
        }
        encryptedCategoryCount[category] = FHE.add(
            encryptedCategoryCount[category],
            FHE.asEuint32(1)
        );

        emit SubmissionDecrypted(submissionId);
    }

    /// @notice Blind auction settlement (example)
    function settleBlindBid(uint256 submissionId, uint256 revealedBid) public onlySubmitter(submissionId) {
        EncryptedSubmission storage submission = encryptedSubmissions[submissionId];
        // Example: simple payout logic
        uint256 payout = revealedBid / 2; // placeholder logic
        payable(msg.sender).transfer(payout);
        emit BlindBidSettled(submissionId, payout);
    }

    /// @notice Get decrypted submission
    function getDecryptedScore(uint256 submissionId) public view returns (
        uint32 score,
        string memory category,
        bool isRevealed
    ) {
        DecryptedScore storage s = decryptedScores[submissionId];
        return (s.score, s.category, s.isRevealed);
    }

    /// @notice Get encrypted category count
    function getEncryptedCategoryCount(string memory category) public view returns (euint32) {
        return encryptedCategoryCount[category];
    }
}
