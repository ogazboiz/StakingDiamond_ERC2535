// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../../contracts/Diamond.sol";
import {DiamondCutFacet} from "../../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../contracts/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../contracts/facets/OwnershipFacet.sol";
import {Staking} from "../../contracts/facets/Staking.sol";
import {IDiamondCut} from "../../contracts/interfaces/IDiamondCut.sol";
import {ERC20Facet} from "../../contracts/facets/ERC20Facet.sol";

contract DiamondUtils is Test {
    Diamond internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal diamondLoupe;
    OwnershipFacet internal ownershipFacet;
    Staking internal stakingFacet;
    ERC20Facet internal erc20Facet;
    address internal diamondOwner;

    function deployDiamond() public {
        diamondOwner = address(this);
        
        // Deploy facets
        cutFacet = new DiamondCutFacet();
        diamond = new Diamond(diamondOwner, address(cutFacet));
        diamondLoupe = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        stakingFacet = new Staking();
        ERC20Facet newERC20Facet = new ERC20Facet();

        // Create FacetCut array
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);

        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        // OwnershipFacet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;

        // Staking - Include all external functions
        bytes4[] memory stakingSelectors = new bytes4[](10);
        stakingSelectors[0] = bytes4(keccak256("applyStaking(uint256,uint256,uint256)"));
        stakingSelectors[1] = bytes4(keccak256("stake(uint8,address,uint256,uint256)"));
        stakingSelectors[2] = bytes4(keccak256("calculateRewards(address)"));
        stakingSelectors[3] = bytes4(keccak256("claimRewards(uint8,uint256)"));
        stakingSelectors[4] = bytes4(keccak256("getStakerInfo(address)"));
        stakingSelectors[5] = bytes4(keccak256("getStakerERC721Info(address,uint256)"));
        stakingSelectors[6] = bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        stakingSelectors[7] = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
        stakingSelectors[8] = bytes4(keccak256("getStakerERC1155Info(address,uint256)"));
        stakingSelectors[9] = bytes4(keccak256("setRewardToken(address)"));
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stakingSelectors
        });

        // Add ERC20 selectors
        bytes4[] memory erc20Selectors = new bytes4[](11);
        erc20Selectors[0] = bytes4(keccak256("transfer(address,uint256)"));
        erc20Selectors[1] = bytes4(keccak256("balanceOf(address)"));
        erc20Selectors[2] = bytes4(keccak256("totalSupply()"));
        erc20Selectors[3] = bytes4(keccak256("approve(address,uint256)"));
        erc20Selectors[4] = bytes4(keccak256("allowance(address,address)"));
        erc20Selectors[5] = bytes4(keccak256("transferFrom(address,address,uint256)"));
        erc20Selectors[6] = bytes4(keccak256("mint(address,uint256)"));
        erc20Selectors[7] = bytes4(keccak256("name()"));
        erc20Selectors[8] = bytes4(keccak256("symbol()"));
        erc20Selectors[9] = bytes4(keccak256("decimals()"));
        erc20Selectors[10] = bytes4(keccak256("applyERC20(string,string,uint8,uint256)"));

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(newERC20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });

        // Upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}
