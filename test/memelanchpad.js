const { expect } = require("chai");
const { ethers } = require("hardhat");
const { ConsoleLogger } = require("ts-generator/dist/logger");

async function showTx(tx1){
    const receipt1 = await tx1.wait(); // 等待事务被矿工打包
    // 现在你可以查询receipt1.events来查找你的事件
    receipt1.events?.forEach(event => {
        console.log(event); // 打印所有相关事件
    });
}

describe("MemeLaunchPad", function () {
    let deployer, user1, user2, admin;
    let memeLaunchPad, mBTC, memeToken;
    let startTime, endTime;
    let events = []

    beforeEach(async function () {
        [deployer, user1, user2 ] = await ethers.getSigners();
        admin = deployer;

        // Mock mBTC token setup
        const MockERC20 = await ethers.getContractFactory("ERC20Mock");
        mBTC = await MockERC20.deploy("Mock BTC", "mBTC", ethers.utils.parseEther("1000"));
        await mBTC.deployed();

        await mBTC.transfer(user1.address, ethers.utils.parseEther("100"));
        await mBTC.transfer(user2.address, ethers.utils.parseEther("100"));

        // Setting up start and end time for the launchpad event
        startTime = (await ethers.provider.getBlock('latest')).timestamp + 100; // 100 seconds from now
        endTime = startTime + 86400; // 24 hours after start time

        // Deploy the MemeLaunchPad contract
        const MemeLaunchPad = await ethers.getContractFactory("MemeLaunchPad");
        memeLaunchPad = await MemeLaunchPad.deploy(mBTC.address, startTime, endTime);
        await memeLaunchPad.deployed();
        await mBTC.connect(user1).approve(memeLaunchPad.address, ethers.utils.parseEther("100"));
        await mBTC.connect(user2).approve(memeLaunchPad.address, ethers.utils.parseEther("100"));


        memeLaunchPad.on("*", (event) => {
            console.log("receive event ",event)
            events.push(event);
        });
    });

    // Tests will be added here
    it("should set up initial parameters correctly", async function () {
        expect(await memeLaunchPad.mBTC()).to.equal(mBTC.address);
        expect(await memeLaunchPad.startTime()).to.be.equal(startTime);
        expect(await memeLaunchPad.endTime()).to.be.equal(endTime);
        expect(await memeLaunchPad.totalContribution()).to.equal(0);

        expect(await memeLaunchPad.balanceOf(memeLaunchPad.address)).to.equal(ethers.utils.parseEther("21000000"));
    });


    it("allows valid contributions", async function () {
        await network.provider.send("evm_increaseTime", [101]); // Fast forward 101 seconds to be within the contribution window
        await network.provider.send("evm_mine");
    
        const contributeAmount = ethers.utils.parseEther("1");
       
        await expect(memeLaunchPad.connect(user1).contribute(contributeAmount))
            .to.emit(memeLaunchPad, "Contributed")
            .withArgs(user1.address, contributeAmount);
        
        expect(await memeLaunchPad.totalContribution()).to.equal(contributeAmount);
        expect(await memeLaunchPad.contributions(user1.address)).to.equal(contributeAmount);
    });

    it("rejects contributions outside the contribution period", async function () {
        // Before start time
        await expect(memeLaunchPad.connect(user1).contribute(ethers.utils.parseEther("1"))).to.be.revertedWith("Not within the contribution period.");
        // In event time
        await network.provider.send("evm_increaseTime", [ 101 ]);
        await network.provider.send("evm_mine");

        
        await expect(memeLaunchPad.connect(user1).contribute(ethers.utils.parseEther("1")))
        .to.emit(memeLaunchPad, "Contributed")
        .withArgs(user1.address, ethers.utils.parseEther("1"));
        // After end time
        await network.provider.send("evm_increaseTime", [endTime + 100 - startTime]);
        await network.provider.send("evm_mine");
        await expect(memeLaunchPad.connect(user1).contribute(ethers.utils.parseEther("1"))).to.be.revertedWith("Not within the contribution period.");
    });

    

    it("rejects contributions over the individual limit", async function () {
        await network.provider.send("evm_increaseTime", [101]);
        await network.provider.send("evm_mine");
    
        const overLimitAmount = ethers.utils.parseEther("3"); // Over the 2 ether limit
        await mBTC.connect(user1).approve(memeLaunchPad.address, overLimitAmount);
        await expect(memeLaunchPad.connect(user1).contribute(overLimitAmount)).to.be.revertedWith("Contribution amount invalid.");
    });

    it("allows the owner to mint and distribute tokens after event ends", async function () {
        // Fast forward to after the event
        await network.provider.send("evm_increaseTime", [endTime + 101 - startTime]);
        await network.provider.send("evm_mine");
    

        const totalContribution = await memeLaunchPad.totalContribution()

        await expect(memeLaunchPad.mintAndDistribute())
            .to.emit(memeLaunchPad, "Transfer") // Assuming Transfer event upon token transfer
            .withArgs(memeLaunchPad.address, admin.address, ethers.utils.parseEther("10500000"))
            .to.emit(mBTC, "Transfer") 
            .withArgs(memeLaunchPad.address, admin.address,totalContribution);

    
    });

    it("allows claims after distribution", async function () {
        // Simulate contributions
        await network.provider.send("evm_increaseTime", [101]); // Fast forward to be within the contribution period
        await network.provider.send("evm_mine");
    
        const contributeAmount1 = ethers.utils.parseEther("0.5");
        await memeLaunchPad.connect(user1).contribute(contributeAmount1);

        const contributeAmount2 = ethers.utils.parseEther("1.5");
        await memeLaunchPad.connect(user2).contribute(contributeAmount2);
    
        // End the event by simulating time past the end time
        await network.provider.send("evm_increaseTime", [endTime - startTime + 102]);
        await network.provider.send("evm_mine");
    
        // Call mintAndDistribute as the owner to simulate distribution
        await memeLaunchPad.mintAndDistribute();
    
        await expect(memeLaunchPad.connect(user1).claim()).to.be.revertedWith("Withdraw not started.");
        // Set withdrawStarted to true to allow claiming
        await memeLaunchPad.setWithdrawStarted(true);
    
        const expectedTokens = ethers.utils.parseEther("10500000").div(4); // Entire participant share since user1 is the only contributor
    
        
        // User1 claims their tokens
        await expect(memeLaunchPad.connect(user1).claim())
            .to.emit(memeLaunchPad, "Claimed")
            .withArgs(user1.address, expectedTokens);
    
        const postClaimTokenBalance = await memeLaunchPad.balanceOf(user1.address);
        expect(postClaimTokenBalance).to.equal(expectedTokens, "User1's token balance should match the expected tokens after claiming");


        // double claime should fail
        await expect(memeLaunchPad.connect(user1).claim()).to.be.revertedWith("Already claimed.");
    });



    it("allows the owner to set withdrawStarted", async function () {
        // Assume mintAndDistribute has been called successfully
        await expect(memeLaunchPad.connect(user1).setWithdrawStarted(true)).to.be.revertedWith("Ownable: caller is not the owner");
        await expect(memeLaunchPad.setWithdrawStarted(true)).to.be.revertedWith("Can only start withdraw after distribution.");

        // End the event by simulating time past the end time
        await network.provider.send("evm_increaseTime", [endTime - startTime + 102]);
        await network.provider.send("evm_mine");

        await expect(memeLaunchPad.setWithdrawStarted(true)).to.be.ok
    });

});
