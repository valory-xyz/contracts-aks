/*global describe, context, beforeEach, it*/

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("JobRegistry", function () {
    let componentRegistry;
    let jobRegistry;
    let signers;
    let deployer;
    const totalSupply = 100;
    const AddressZero = ethers.constants.AddressZero;
    const maxUint256 = ethers.constants.MaxUint256;
    const ZeroBytes32 = "0x" + "0".repeat(64);

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
        it("Deploying with the zero componentRegistry address", async function () {
            const JobRegistry = await ethers.getContractFactory("JobRegistry");
            await expect(
                JobRegistry.deploy(AddressZero)
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroAddress");
        });

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

    context("Job registration", async function () {
        it("Should fail when propose with incorrect values", async function () {
            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address, signers[2].address], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "WrongArrayLength");

            await expect(
                jobRegistry.connect(deployer).propose([], [])
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroValue");

            await expect(
                jobRegistry.connect(deployer).propose([AddressZero], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroAddress");

            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address], [0])
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroValue");

            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address], [maxUint256])
            ).to.be.revertedWithCustomError(jobRegistry, "Overflow");

            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address], [totalSupply + 1])
            ).to.be.revertedWithCustomError(jobRegistry, "ComponentDoesNotExist");

            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address, signers[1].address], [1, 1])
            ).to.be.revertedWithCustomError(jobRegistry, "AlreadyProposed");
        });

        it("Propose the same pair", async function () {
            await jobRegistry.connect(deployer).propose([signers[1].address], [1]);
            await expect(
                jobRegistry.connect(deployer).propose([signers[1].address], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "AlreadyProposed");
        });

        it("Propose", async function () {
            // Get initial empty proposed and accepted sets
            let proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(0);
            expect(proposedPairs.componentIds.length).to.equal(0);
            let acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            const account = signers[1];
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 1]);

            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(4);
            expect(proposedPairs.componentIds.length).to.equal(4);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);
        });

        it("Propose several longer sets", async function () {
            const steps = totalSupply / 10;
            // Get the number of account addresses equal to the number of steps
            const accounts = signers.slice(1, steps + 1).map(
                function (currentSigner) {
                    return currentSigner.address;
                }
            );
            for (let i = 0; i < steps; i++) {
                // Get the next batch of component Ids
                let componentIds = Array.from({length: steps}, (_, j) => j + 1);
                componentIds.forEach((element, index) => {
                    componentIds[index] = element + i;
                });
                await jobRegistry.connect(deployer).propose(accounts, componentIds);
            }

            const proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(totalSupply);
            expect(proposedPairs.componentIds.length).to.equal(totalSupply);
            const acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);
        });

        it("Should fail when accepting with incorrect values", async function () {
            const account = signers[1];
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);

            await expect(
                jobRegistry.connect(account).accept([signers[2].address, signers[3].address], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "OwnerOnly");

            await expect(
                jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "WrongArrayLength");

            await expect(
                jobRegistry.connect(deployer).accept([], [])
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroValue");

            await expect(
                jobRegistry.connect(deployer).accept([signers[1].address], [maxUint256])
            ).to.be.revertedWithCustomError(jobRegistry, "Overflow");

            await expect(
                jobRegistry.connect(deployer).accept([signers[1].address], [totalSupply + 1])
            ).to.be.revertedWithCustomError(jobRegistry, "NotProposed");

            await expect(
                jobRegistry.connect(deployer).accept([AddressZero], [0])
            ).to.be.revertedWithCustomError(jobRegistry, "NotProposed");

            await expect(
                jobRegistry.connect(deployer).accept([AddressZero], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "NotProposed");

            await expect(
                jobRegistry.connect(deployer).accept([signers[1].address], [0])
            ).to.be.revertedWithCustomError(jobRegistry, "NotProposed");

            await expect(
                jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [2, 1])
            ).to.be.revertedWithCustomError(jobRegistry, "NotProposed");
        });

        it("Accept", async function () {
            const account = signers[1];
            // Propose
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 1]);

            // Accept
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);

            // Check for accepted and not accepted jobs
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Get component Id and hash
            let componentIdHash = await jobRegistry.getComponentIdHash(signers[2].address);
            expect(componentIdHash.componentId).to.equal(1);
            expect(componentIdHash.componentHash).to.not.equal(ZeroBytes32);
            componentIdHash = await jobRegistry.getComponentIdHash(signers[3].address);
            expect(componentIdHash.componentId).to.equal(1);
            expect(componentIdHash.componentHash).to.not.equal(ZeroBytes32);

            // Get proposed and accepted sets
            const proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(4);
            expect(proposedPairs.componentIds.length).to.equal(4);
            const acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);
        });

        it("Should fail when removing with incorrect values", async function () {
            const account = signers[1];
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);

            await expect(
                jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [1])
            ).to.be.revertedWithCustomError(jobRegistry, "WrongArrayLength");

            await expect(
                jobRegistry.connect(account).remove([], [])
            ).to.be.revertedWithCustomError(jobRegistry, "ZeroValue");

            await expect(
                jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [2, 1])
            ).to.be.revertedWithCustomError(jobRegistry, "OwnerOnly");
        });

        it("Remove", async function () {
            const account = signers[1];
            // Propose
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 1]);

            // Accept all
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [2, 2]);
            // Check for the proposed jobs
            let proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(4);
            expect(proposedPairs.componentIds.length).to.equal(4);
            // We have overwritten accepted jobs with the second accept
            let acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);

            // Remove half
            await jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [2, 2]);

            // All the jobs are unaccepted since the job addresses have been removed
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(2);
            expect(proposedPairs.componentIds.length).to.equal(2);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Accept the remaining ones
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);

            // Check for the accepted jobs status
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Remove remaining jobs
            await jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [1, 1]);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(0);
            expect(proposedPairs.componentIds.length).to.equal(0);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Get component Id and hash
            let componentIdHash = await jobRegistry.getComponentIdHash(signers[2].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
            componentIdHash = await jobRegistry.getComponentIdHash(signers[3].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
        });

        it("Remove by the contract owner", async function () {
            const account = signers[1];
            // Propose
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 1]);

            // Accept all
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [2, 2]);
            // Check for the proposed jobs
            let proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(4);
            expect(proposedPairs.componentIds.length).to.equal(4);
            // We have overwritten accepted jobs with the second accept
            let acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);

            // Remove half
            await jobRegistry.connect(deployer).remove([signers[2].address, signers[3].address], [2, 2]);

            // All the jobs are unaccepted since the job addresses have been removed
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(2);
            expect(proposedPairs.componentIds.length).to.equal(2);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Accept the remaining ones
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);

            // Check for the accepted jobs status
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Remove remaining jobs
            await jobRegistry.connect(deployer).remove([signers[2].address, signers[3].address], [1, 1]);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(0);
            expect(proposedPairs.componentIds.length).to.equal(0);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Get component Id and hash
            let componentIdHash = await jobRegistry.getComponentIdHash(signers[2].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
            componentIdHash = await jobRegistry.getComponentIdHash(signers[3].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
        });

        it("Remove after accepting and removing again", async function () {
            const account = signers[1];
            // Propose
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [1, 2]);
            let numProposedPairs = await jobRegistry.numProposedPairs();
            expect(numProposedPairs).to.equal(2);
            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 1]);
            numProposedPairs = await jobRegistry.numProposedPairs();
            expect(numProposedPairs).to.equal(4);

            // Accept all
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [2, 2]);

            // Remove half and propose again, then remove
            await jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [2, 2]);
            numProposedPairs = await jobRegistry.numProposedPairs();
            expect(numProposedPairs).to.equal(4);
            // Get proposed and accepted sets
            let proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(2);
            expect(proposedPairs.componentIds.length).to.equal(2);
            let acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            await jobRegistry.connect(account).propose([signers[2].address, signers[3].address], [2, 2]);
            numProposedPairs = await jobRegistry.numProposedPairs();
            expect(numProposedPairs).to.equal(4);
            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(4);
            expect(proposedPairs.componentIds.length).to.equal(4);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            await jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [2, 2]);

            // All the jobs are unaccepted since the job addresses have been removed
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(2);
            expect(proposedPairs.componentIds.length).to.equal(2);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Accept the remaining ones
            await jobRegistry.connect(deployer).accept([signers[2].address, signers[3].address], [1, 1]);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(2);
            expect(acceptedPairs.componentIds.length).to.equal(2);

            // Check for the accepted jobs status
            expect(await jobRegistry.isAcceptedJob(signers[2].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJob(signers[3].address)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[2].address, 2)).to.equal(false);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 1)).to.equal(true);
            expect(await jobRegistry.isAcceptedJobComponentId(signers[3].address, 2)).to.equal(false);

            // Remove remaining jobs
            await jobRegistry.connect(account).remove([signers[2].address, signers[3].address], [1, 1]);

            // Get proposed and accepted sets
            proposedPairs = await jobRegistry.getPairs(false);
            expect(proposedPairs.jobs.length).to.equal(0);
            expect(proposedPairs.componentIds.length).to.equal(0);
            acceptedPairs = await jobRegistry.getPairs(true);
            expect(acceptedPairs.jobs.length).to.equal(0);
            expect(acceptedPairs.componentIds.length).to.equal(0);

            // Get component Id and hash
            let componentIdHash = await jobRegistry.getComponentIdHash(signers[2].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
            componentIdHash = await jobRegistry.getComponentIdHash(signers[3].address);
            expect(componentIdHash.componentId).to.equal(0);
            expect(componentIdHash.componentHash).to.equal(ZeroBytes32);
        });
    });
});
