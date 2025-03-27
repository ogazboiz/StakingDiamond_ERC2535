// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils {
    function testDeployDiamond() public {
        deployDiamond();
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external {}
}
