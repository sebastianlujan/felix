// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Errors, HonkVerifier, IVerifier, NUMBER_OF_PUBLIC_INPUTS, PAIRING_POINTS_SIZE} from "../src/HonkVerifier.sol";
import {NegativeBase} from "./NegativeBase.sol";

/// @notice The oracle: the Solidity verifier bb generated for `vectors/vk`.
contract NegativeSol is NegativeBase {
    // Proof word layout: 8 pairing limbs, then 8 commitments of 2 words each.
    uint256 internal constant FIRST_SUMCHECK_UNIVARIATE_WORD = 24;

    function _createVerifier() internal override returns (IVerifier) {
        return new HonkVerifier();
    }

    function test_ValidProofIsAccepted() public view {
        assertTrue(verifier.verify(proof, publicInputs));
    }

    function test_VectorSizesMatchVerifierConstants() public view {
        assertEq(proof.length, PROOF_LENGTH, "proof file size");
        assertEq(publicInputs.length, NUMBER_OF_PUBLIC_INPUTS - PAIRING_POINTS_SIZE, "public_inputs file size");
    }

    function test_PublicInputsAreSquareThenRecipient() public view {
        assertEq(publicInputs[0], bytes32(uint256(9)), "y");
        assertEq(publicInputs[1], bytes32(uint256(0xc0ffe)), "recipient");
    }

    /// @dev The circuit has no recursive verifier, so the proof carries the default
    ///      (all-zero) pairing points and the verifier skips their aggregation.
    function test_PairingPointLimbsAreZero() public view {
        for (uint256 i = 0; i < PAIRING_POINTS_SIZE * WORD; i++) {
            assertEq(proof[i], bytes1(0));
        }
    }

    function test_RevertWhen_SumcheckUnivariateIsTampered() public {
        bytes memory tampered = _proofWithFlippedBit(FIRST_SUMCHECK_UNIVARIATE_WORD);
        vm.expectRevert(Errors.SumcheckFailed.selector);
        verifier.verify(tampered, publicInputs);
    }

    function test_RevertWhen_PublicInputIsChanged() public {
        bytes32[] memory changed = publicInputs;
        changed[0] = bytes32(uint256(10));
        vm.expectRevert(Errors.SumcheckFailed.selector);
        verifier.verify(proof, changed);
    }

    function test_RevertWhen_RecipientIsChanged() public {
        bytes32[] memory changed = publicInputs;
        changed[1] = bytes32(uint256(0xbeef));
        vm.expectRevert(Errors.SumcheckFailed.selector);
        verifier.verify(proof, changed);
    }
}
