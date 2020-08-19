// Copyright (C) 2020 Cartesi Pte. Ltd.

// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: This component currently has dependencies that are licensed under the GNU
// GPL, version 3, and so you should treat this component as a whole as being under
// the GPL version 3. But all Cartesi-written code in this component is licensed
// under the Apache License, version 2, or a compatible permissive license, and can
// be used independently under the Apache v2 license. After this component is
// rewritten, the entire component will be released under the Apache v2 license.

/// @title GpgVerify
/// @author Milton Jonathan
pragma solidity >=0.4.25 <0.7.0;
pragma experimental ABIEncoderV2;

import "@cartesi/descartes-sdk/contracts/DescartesInterface.sol";


contract GpgVerify {

    DescartesInterface descartes;

    bytes32 templateHash = 0x368aca58c884ef4ce2fa5c58b3f859ce8d001e725706f2d1e329fa1d7ae72f52;

    // this DApp has an ext2 file-system (at 0x9000..) and two input drives (at 0xa000.. and 0xb000..), so the output will be at 0xc000..
    uint64 outputPosition = 0xc000000000000000;
    // output will be "0" (success, no errors), "1" (failure), or some other error code that certainly fits into the minimum size of 32 bytes
    uint64 outputLog2Size = 5;

    uint256 finalTime = 1e13;
    uint256 roundDuration = 45;

    // document that was signed
    bytes document = "My public statement\n";

    // detached signature for the document, produced with a private key
    // - the DApp off-chain code must contain the corresponding public key in order to verify the signature
    bytes signature = hex'8901d20400010a003d162104dbbbb50ddc0910795f7c0b48a86d9cb964eb527e05025f19fa431f1c6465736361727465732e'
                      hex'7475746f7269616c7340636172746573692e696f000a0910a86d9cb964eb527ed88f0bf745cac22eca54a050edf5ce62ab5c'
                      hex'8857bab9807d4b6cc4b01b47c640669f14c9457d129225d005585f7a4cec2c41bd088b0d622c4ee29eecb4a451461e421d00'
                      hex'67575bd845818a12df0b197e525da3dea2c89f0210325d766a11da824d9469bea5add6c9f91c09098f72cca806f4b0eb3ff6'
                      hex'22531171f9ae5b855366d250d08e05327549a9a958b44530f2a05cd9b6aa463eda223f16ff8655ab2e4bf7f66bb2fa29913c'
                      hex'1f04080a24dd10e754d277c346909a3510305b7fd9ca2a4bbd412fc50818331b40461380174434f90046bfb6278419b69259'
                      hex'e56abfa504c5965e37d1aa355302d8b6aac98abe5be1c02c78d5a2e9e4df0eba43a91717407811e20b800120f349aa1b51a1'
                      hex'e4ad5ffdf6248ef0201b275e947d81ed8267a473778cab78ead5f39e60edaf9c17a6c558eeb0ca7e7acc1343a1f7a431d215'
                      hex'98edd470a080ed377ab0c4824f95589ab1c40568e8a28b36ac20116586f89ebe193af5898aa947ada15bbbb8d09e3894c33d'
                      hex'7bdb20a8b1bc6be60ac03fdbc0be0ffdfa326c';

    // corresponding document and signature data to be sent as input drives to the off-chain Cartesi Machine
    // - this machine expects the first two bytes of the input data to encode the length of the content of interest
    bytes documentData = new bytes(1024);
    bytes signatureData = new bytes(1024);

    constructor(address descartesAddress) public {
        descartes = DescartesInterface(descartesAddress);

        // prepares data: computation expects input data to be prepended by two bytes that encode the length of the content
        prependDataWithContentLength(document, documentData);
        prependDataWithContentLength(signature, signatureData);
    }

    function prependDataWithContentLength(bytes storage input, bytes storage output) internal {
        // length is assumed to fit in two bytes
        assert(input.length <= 0xffff);

        // sets first two bytes in output as the input length
        bytes memory inputLength = abi.encodePacked(input.length);
        output[0] = inputLength[inputLength.length-2];
        output[1] = inputLength[inputLength.length-1];

        // subsequent bytes in output are the input bytes themselves
        for (uint i = 0; i < input.length && i+2 < output.length; i++) {
          output[i+2] = input[i];
        }
    }

    function instantiate(address claimer, address challenger) public returns (uint256) {

        // specifies two input drives containing the document and the signature
        DescartesInterface.Drive[] memory drives = new DescartesInterface.Drive[](2);
        drives[0] = DescartesInterface.Drive(
            0xa000000000000000,    // 3rd drive position: 1st is the root file-system (0x8000..), 2nd is the dapp-data file-system (0x9000..)
            10,                    // driveLog2Size
            documentData,          // directValue
            0x00,                  // loggerRootHash
            claimer,               // provider
            false,                 // waitsProvider
            false                  // needsLogger
        );
        drives[1] = DescartesInterface.Drive(
            0xb000000000000000,    // 4th drive position
            10,                    // driveLog2Size
            signatureData,         // directValue
            0x00,                  // loggerRootHash
            claimer,               // provider
            false,                 // waitsProvider
            false                  // needsLogger
        );

        // instantiates the computation
        return descartes.instantiate(
            finalTime,
            templateHash,
            outputPosition,
            outputLog2Size,
            roundDuration,
            claimer,
            challenger,
            drives
        );
    }

    function getResult(uint256 index) public view returns (bool, bool, address, bytes memory) {
        return descartes.getResult(index);
    }

    function destruct(uint256 index) public {
        descartes.destruct(index);
    }
}
