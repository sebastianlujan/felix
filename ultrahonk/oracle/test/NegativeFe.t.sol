// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {IVerifier} from "../src/HonkVerifier.sol";
import {NegativeBase} from "./NegativeBase.sol";

/// @notice The Fe port, deployed from the initcode `fe build` writes for `../verifier`.
/// @dev Run `fe build` in `../verifier` first; the artifact is not committed.
contract NegativeFe is NegativeBase {
    function _createVerifier() internal override returns (IVerifier deployed) {
        // `fe build` writes the initcode as hex text without a `0x` prefix.
        bytes memory initcode = vm.parseBytes(vm.readFile("../verifier/out/HonkVerifier.bin"));
        assembly {
            deployed := create(0, add(initcode, 0x20), mload(initcode))
        }
        require(address(deployed).code.length != 0, "Fe verifier deployment failed");
    }

    /// @dev Skeleton status: the length check passes and nothing after it exists yet.
    ///      Replaced by the shared accept case once the port verifies proofs.
    function test_ValidProofIsNotAcceptedYet() public {
        vm.expectRevert(bytes4(keccak256("VerificationNotImplemented()")));
        verifier.verify(proof, publicInputs);
    }
}
