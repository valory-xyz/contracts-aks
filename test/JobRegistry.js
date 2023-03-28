/*global describe, context, beforeEach, it*/

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("JobRegistry", function () {
    let componentRegistry;
    let jobRegistry;
    let signers;
    let deployer;
    const totalSupply = 10;
    const AddressZero = ethers.constants.AddressZero;
    const maxUint256 = ethers.constants.MaxUint256;

    beforeEach(async function () {
        const ComponentRegistry = await ethers.getContractFactory("MockRegistry");
        componentRegistry = await ComponentRegistry.deploy(totalSupply);
        await componentRegistry.deployed();

        const JobRegistry = await ethers.getContractFactory("JobRegistry");
        jobRegistry = await JobRegistry.deploy(componentRegistry.address);
        await jobRegistry.deployed();
        
        signers = await ethers.getSigners();
        deployer = signers[0];
    });

    context("Initialization", async function () {
        it("Changing the owner", async function () {
            const account = signers[1];

            // Trying to change owner from a non-owner account address
            await expect(
                jobRegistry.connect(account).changeOwner(account.address)
            ).to.be.revertedWithCustomError(jobRegistry, "OwnerOnly");

            // Trying to change the owner to the zero address
            await expect(
                jobRegistry.connect(deployer).changeOwner(AddressZero)
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroAddress");

            // Changing the owner
            await jobRegistry.connect(deployer).changeOwner(account.address);

            // Trying to change owner from the previous owner address
            await expect(
                jobRegistry.connect(deployer).changeOwner(deployer.address)
            ).to.be.revertedWithCustomError(jobRegistry, "OwnerOnly");
        });
    });
});
