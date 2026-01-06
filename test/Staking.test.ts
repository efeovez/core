import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { Staking, Basis } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { days } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration";

describe("Staking Contract", function () {
  let staking: Staking;
  let basis: Basis;
  let basis2: Basis;
  let owner: HardhatEthersSigner;
  let operator: HardhatEthersSigner;
  let governor: HardhatEthersSigner;
  let provider1: HardhatEthersSigner;
  let provider2: HardhatEthersSigner;
  let delegator1: HardhatEthersSigner;
  let delegator2: HardhatEthersSigner;
  let user: HardhatEthersSigner;

  const LOCK_PERIOD = 21 * 24 * 60 * 60; // 21 days
  const STAKE_AMOUNT = ethers.parseEther("1000");
  const REWARD_AMOUNT = ethers.parseEther("100");

  beforeEach(async function () {
    [owner, operator, provider1, provider2, delegator1, delegator2, user] = await ethers.getSigners();

    // Deploy Mock basis Token
    const MockERC20Factory = await ethers.getContractFactory("Basis");
    basis = await MockERC20Factory.connect(owner).deploy();
    await basis.waitForDeployment();

    // Deploy Staking Contract
    const StakingFactory = await ethers.getContractFactory("Staking");
    staking = await StakingFactory.connect(owner).deploy(await basis.getAddress());
    await staking.waitForDeployment();

    // Set operator
    await staking.connect(owner).transferOperator(operator.getAddress());

    await basis.mint(await owner.getAddress(), ethers.parseEther("1000000000"));

    // Distribute tokens
    await basis.transfer(delegator1.address, ethers.parseEther("10000"));
    await basis.transfer(delegator2.address, ethers.parseEther("10000"));
    await basis.transfer(provider1.address, ethers.parseEther("5000"));
  });

  describe("Provider Management", function () {
    it("Should create a provider successfully", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);

      const ProviderData = await staking.providers(provider1.address);
      expect(ProviderData.providerAddr).to.equal(provider1.address);
      expect(ProviderData.description).to.equal("Provider One");
      expect(ProviderData.commission).to.equal(10);
      expect(ProviderData.power).to.equal(0);
    });

    it("Should revert if description is too long", async function () {
      const longDescription = "a".repeat(51);
      await expect(
        staking.connect(provider1).createProvider(longDescription, 10)
      ).to.be.revertedWith("description must be under 50 characters");
    });

    it("Should revert if commission exceeds 100", async function () {
      await expect(
        staking.connect(provider1).createProvider("Provider One", 101)
      ).to.be.revertedWith("commission must not exceed 100");
    });

    it("Should revert if provider already exists", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await expect(
        staking.connect(provider1).createProvider("Provider Two", 15)
      ).to.be.revertedWith("provider already exists");
    });

    it("Should edit provider successfully", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await staking.connect(provider1).editProvider("Updated Provider", 20);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.description).to.equal("Updated Provider");
      expect(providerData.commission).to.equal(20);
    });

    it("Should revert edit if provider not registered", async function () {
      await expect(
        staking.connect(provider1).editProvider("Updated", 10)
      ).to.be.revertedWith("provider not registered");
    });

    it("Should emit ProviderCreated event", async function () {
      await expect(staking.connect(provider1).createProvider("Provider One", 10))
        .to.emit(staking, "ProviderCreated")
        .withArgs(provider1.address, "Provider One", 10);
    });

    it("Should emit ProviderEdited event", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await expect(staking.connect(provider1).editProvider("Updated", 20))
        .to.emit(staking, "ProviderEdited")
        .withArgs(provider1.address, "Updated", 20, time.latest);
    });

    it("Should return the operator address", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      const getProviderFunc = await staking.connect(user).getProvider(provider1.address)

      const providerData = await staking.providers(provider1.address);
      expect(providerData.providerAddr).to.equal(provider1.address);
    });

    it("Should return the zero address if provider not registered", async function () {
      const getProviderFunc = await staking.connect(user).getProvider(user.address)

      const providerData = await staking.providers(user.address);
      expect(providerData.providerAddr).to.equal("0x0000000000000000000000000000000000000000");
    });
  });

  describe("Delegation", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
    });

    it("Should delegate successfully", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);

      const delegation = await staking.delegations(delegator1.address, provider1.address);
      expect(delegation.share).to.equal(STAKE_AMOUNT);
      expect(delegation.provider).to.equal(provider1.address);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.power).to.equal(STAKE_AMOUNT);

      const totalShare = await staking.totalShare();
      expect(totalShare).to.equal(STAKE_AMOUNT);
    });

    it("Should revert delegation to non-existent provider", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await expect(
        staking.connect(delegator1).delegate(provider2.address, STAKE_AMOUNT)
      ).to.be.revertedWith("provider not registered");
    });

    it("Should revert delegation with zero amount", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await expect(
        staking.connect(delegator1).delegate(provider1.address, 0)
      ).to.be.revertedWith("you cannot delegate zero");
    });

    it("Should revert delegation without approval", async function () {
      await expect(
        staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT)
      ).to.be.revertedWith("approved amount is not sufficient");
    });

    it("Should allow multiple delegations to same provider", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT * 2n);
      
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);

      const delegation = await staking.delegations(delegator1.address, provider1.address);
      expect(delegation.share).to.equal(STAKE_AMOUNT * 2n);
    });

    it("Should update unlock time on re-delegation", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT * 2n);
      
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      const firstDelegation = await staking.delegations(delegator1.address, provider1.address);
      
      await time.increase(3600); // 1 hour later
      
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      const secondDelegation = await staking.delegations(delegator1.address, provider1.address);
      
      expect(secondDelegation.unlockTime).to.be.gt(firstDelegation.unlockTime);
    });

    it("Should emit Delegated event", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await expect(staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT))
        .to.emit(staking, "Delegated")
        .withArgs(delegator1.address, provider1.address, STAKE_AMOUNT, time.latest);
    });
  });

  describe("Undelegation", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
    });

    it("Should revert undelegation before lock period", async function () {
      await expect(
        staking.connect(delegator1).undelegate(provider1.address)
      ).to.be.revertedWith("your token is locked");
    });

    it("Should undelegate successfully after lock period", async function () {
      await time.increase(LOCK_PERIOD + 1);

      const initialBalance = await basis.balanceOf(delegator1.address);
      await staking.connect(delegator1).undelegate(provider1.address);

      const finalBalance = await basis.balanceOf(delegator1.address);
      expect(finalBalance - initialBalance).to.equal(STAKE_AMOUNT);

      const delegation = await staking.delegations(delegator1.address, provider1.address);
      expect(delegation.share).to.equal(0);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.power).to.equal(0);
    });

    it("Should revert undelegation with no delegation", async function () {
      await expect(
        staking.connect(delegator2).undelegate(provider1.address)
      ).to.be.revertedWith("you do not have an existing delegation");
    });

    it("Should revert undelegation from non-existent provider", async function () {
      await expect(
        staking.connect(delegator1).undelegate(provider2.address)
      ).to.be.revertedWith("provider not registered");
    });

    it("Should emit Undelegated event", async function () {
      await time.increase(LOCK_PERIOD + 1);
      await expect(staking.connect(delegator1).undelegate(provider1.address))
        .to.emit(staking, "Undelegated")
        .withArgs(delegator1.address, provider1.address, STAKE_AMOUNT);
    });
  });

  describe("Reward Distribution", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);

      // Fund staking contract with rewards
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
    });

    it("Should notify reward amount correctly", async function () {
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.rewardRate).to.be.gt(0);
      expect(providerData.periodFinish).to.be.gt(await time.latest());
    });

    it("Should revert notify reward if not operator", async function () {
      await expect(
        staking.connect(user).notifyRewardAmount(REWARD_AMOUNT, provider1.address)
      ).to.be.reverted;
    });

    it("Should calculate earned rewards correctly", async function () {
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      
      await time.increase(LOCK_PERIOD / 2);

      const earned = await staking.earned(delegator1.address, provider1.address);
      expect(earned).to.be.gt(0);
      
      const halfReward = REWARD_AMOUNT / 2n;
      const tolerance = ethers.parseEther("1");
      expect(earned).to.be.closeTo(halfReward, tolerance);
    });

    it("Should withdraw delegator rewards with commission", async function () {
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      const initialBalance = await basis.balanceOf(delegator1.address);
      const earned = await staking.earned(delegator1.address, provider1.address);

      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);

      const finalBalance = await basis.balanceOf(delegator1.address);
      const netReward = earned * 90n / 100n; // 10% commission

      const tolerance = ethers.parseEther("0.01");
      expect(finalBalance - initialBalance).to.be.closeTo(netReward, tolerance);

      const providerData = await staking.providers(provider1.address);
      const expectedCommission = earned * 10n / 100n;
      expect(providerData.commissionRewards).to.be.closeTo(expectedCommission, tolerance);
    });

    it("Should handle multiple delegators correctly", async function () {
      await basis.connect(delegator2).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator2).delegate(provider1.address, STAKE_AMOUNT);

      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      const earned1 = await staking.earned(delegator1.address, provider1.address);
      const earned2 = await staking.earned(delegator2.address, provider1.address);

      const tolerance = ethers.parseEther("0.1");
      expect(earned1).to.be.closeTo(earned2, tolerance);
      expect(earned1 + earned2).to.be.closeTo(REWARD_AMOUNT, tolerance);
    });

    it("Should accumulate commission rewards correctly", async function () {
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.commissionRewards).to.be.gt(0);
    });

    it("Should emit RewardAdded event", async function () {
      await expect(staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address))
        .to.emit(staking, "RewardAdded")
        .withArgs(provider1.address, REWARD_AMOUNT);
    });

    it("Should emit WithdrawDelegatorReward event", async function () {
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      const earned = await staking.earned(delegator1.address, provider1.address);
      const netReward = earned * 90n / 100n;

      await expect(staking.connect(delegator1).withdrawDelegatorReward(provider1.address))
        .to.emit(staking, "WithdrawDelegatorReward");
    });

    it("Should revert withdraw with no delegation", async function () {
      await expect(
        staking.connect(delegator2).withdrawDelegatorReward(provider1.address)
      ).to.be.revertedWith("no delegation");
    });
  });

  describe("Provider Commission Withdrawal", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);
      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);
    });

    it("Should withdraw provider commission", async function () {
      const providerDataBefore = await staking.providers(provider1.address);
      const commission = providerDataBefore.commissionRewards;

      const initialBalance = await basis.balanceOf(provider1.address);
      await staking.connect(provider1).withdrawProviderCommission();
      const finalBalance = await basis.balanceOf(provider1.address);

      expect(finalBalance - initialBalance).to.equal(commission);

      const providerDataAfter = await staking.providers(provider1.address);
      expect(providerDataAfter.commissionRewards).to.equal(0);
    });

    it("Should revert if no commission to withdraw", async function () {
      await staking.connect(provider1).withdrawProviderCommission();
      await expect(
        staking.connect(provider1).withdrawProviderCommission()
      ).to.be.revertedWith("no commission to withdraw");
    });

    it("Should revert if caller is not a provider", async function () {
      await expect(
        staking.connect(user).withdrawProviderCommission()
      ).to.be.revertedWith("provider not registered");
    });

    it("Should emit WithdrawProviderCommission event", async function () {
      const providerData = await staking.providers(provider1.address);
      const commission = providerData.commissionRewards;

      await expect(staking.connect(provider1).withdrawProviderCommission())
        .to.emit(staking, "WithdrawProviderCommission")
        .withArgs(provider1.address, commission);
    });
  });

  describe("Governance Functions", function () {
    it("Should migrate new lpBasis token address", async function () {
      const Basis2Factory = await ethers.getContractFactory("Basis");
      basis2 = await Basis2Factory.connect(owner).deploy();
      await basis2.waitForDeployment();

      await staking.connect(owner).setLpBasis(await basis2.getAddress())
      expect(await staking.connect(user).lpBasis()).to.equal(await basis2.getAddress())
    });

    it("Should emit LpBasisUpdated event", async function () {
      const oldLpBasis = await staking.connect(user).lpBasis()
      const Basis2Factory = await ethers.getContractFactory("Basis");
      basis2 = await Basis2Factory.connect(owner).deploy();
      await basis2.waitForDeployment();

      const newLpBasis = await basis2.getAddress();

      await expect(staking.connect(owner).setLpBasis(newLpBasis))
        .to.emit(staking, "LpBasisUpdated")
        .withArgs(oldLpBasis, newLpBasis);
    });

    it("Should set new max provider limit", async function () {
      await staking.connect(owner).setMaxProviders(100)

      expect(await staking.connect(user).maxProviders()).to.equal(100)
    });

    it("Should emit MaxProvidersUpdated event", async function () {
      const oldMaxProviders = await staking.connect(user).maxProviders()

      await expect(staking.connect(owner).setMaxProviders(100))
        .to.emit(staking, "MaxProvidersUpdated")
        .withArgs(oldMaxProviders, 100);
    });

    it("Should set new lock period", async function () {
      await staking.connect(owner).setLockPeriod(86400)

      expect(await staking.connect(user).lockPeriod()).to.equal(86400)
    });

    it("Should emit LockPeriodUpdated event", async function () {
      const oldLockPeriod = await staking.connect(user).lockPeriod()

      await expect(staking.connect(owner).setLockPeriod(86400))
        .to.emit(staking, "LockPeriodUpdated")
        .withArgs(oldLockPeriod, 86400);
    });

    it("Should revert if a non-governor tries to migrate lpBasis token address", async function () {
      await expect(
        staking.connect(user).setLpBasis("0x0000000000000000000000000000000000000000")
      ).to.be.revertedWith("msg.sender is not the governor");
    });

    it("Should revert if a non-governor tries to set max provider limit", async function () {
      await expect(
        staking.connect(user).setMaxProviders(1)
      ).to.be.revertedWith("msg.sender is not the governor");
    });

    it("Should revert if a non-governor tries to set lock period", async function () {
      await expect(
        staking.connect(user).setLockPeriod(1)
      ).to.be.revertedWith("msg.sender is not the governor");
    });
  });

  describe("Edge Cases", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 0);
      await staking.connect(provider2).createProvider("Provider Two", 50);
    });

    it("Should handle 0% commission correctly", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      const earned = await staking.earned(delegator1.address, provider1.address);
      const initialBalance = await basis.balanceOf(delegator1.address);

      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);

      const finalBalance = await basis.balanceOf(delegator1.address);
      const tolerance = ethers.parseEther("0.01");
      expect(finalBalance - initialBalance).to.be.closeTo(earned, tolerance);
    });

    it("Should handle 100% commission correctly", async function () {
      await staking.connect(provider1).editProvider("Provider One", 100);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD);

      const initialBalance = await basis.balanceOf(delegator1.address);
      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);
      const finalBalance = await basis.balanceOf(delegator1.address);

      expect(finalBalance - initialBalance).to.equal(0);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.commissionRewards).to.be.gt(0);
    });

    it("Should handle reward rollover correctly", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 20n);

      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await time.increase(LOCK_PERIOD / 2);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);

      const providerData = await staking.providers(provider1.address);
      expect(providerData.rewardRate).to.be.gt(0);
    });

    it("Should maintain correct totalShare across operations", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT * 2n);
      await basis.connect(delegator2).approve(await staking.getAddress(), STAKE_AMOUNT);

      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await staking.connect(delegator2).delegate(provider2.address, STAKE_AMOUNT);
      
      let totalShare = await staking.totalShare();
      expect(totalShare).to.equal(STAKE_AMOUNT * 2n);

      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      totalShare = await staking.totalShare();
      expect(totalShare).to.equal(STAKE_AMOUNT * 3n);

      await time.increase(LOCK_PERIOD + 1);
      await staking.connect(delegator1).undelegate(provider1.address);
      
      totalShare = await staking.totalShare();
      expect(totalShare).to.equal(STAKE_AMOUNT);
    });

    it("Should handle zero power provider correctly", async function () {
      const rewardPerLpBasis = await staking.rewardPerLpBasis(provider1.address);
      expect(rewardPerLpBasis).to.equal(0);
    });

    it("Should handle partial period rewards", async function () {
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);

      await time.increase(LOCK_PERIOD / 4);

      const earned = await staking.earned(delegator1.address, provider1.address);
      const quarterReward = REWARD_AMOUNT / 4n;
      const tolerance = ethers.parseEther("1");
      expect(earned).to.be.closeTo(quarterReward, tolerance);
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
    });

    it("Should return correct lastTimeRewardApplicable", async function () {
      const current = await time.latest();
      const lastTime = await staking.lastTimeRewardApplicable(provider1.address);
      expect(lastTime).to.be.gte(current);
    });

    it("Should return correct rewardPerLpBasis", async function () {
      await time.increase(LOCK_PERIOD / 2);
      const rewardPerLpBasis = await staking.rewardPerLpBasis(provider1.address);
      expect(rewardPerLpBasis).to.be.gt(0);
    });

    it("Should return correct getRewardForDuration", async function () {
      const rewardForDuration = await staking.getRewardForDuration(provider1.address);
      const tolerance = ethers.parseEther("0.1");
      expect(rewardForDuration).to.be.closeTo(REWARD_AMOUNT, tolerance);
    });

    it("Should return zero earned for non-delegator", async function () {
      const earned = await staking.earned(user.address, provider1.address);
      expect(earned).to.equal(0);
    });

    it("Should track rewards continuously", async function () {
      await time.increase(LOCK_PERIOD / 4);
      const earned1 = await staking.earned(delegator1.address, provider1.address);

      await time.increase(LOCK_PERIOD / 4);
      const earned2 = await staking.earned(delegator1.address, provider1.address);

      expect(earned2).to.be.gt(earned1);
    });
  });

  describe("Integration Tests", function () {
    it("Should handle complete lifecycle with multiple providers and delegators", async function () {
      // Create providers
      await staking.connect(provider1).createProvider("Provider One", 5);
      await staking.connect(provider2).createProvider("Provider Two", 15);

      // Delegate to providers
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT * 2n);
      await basis.connect(delegator2).approve(await staking.getAddress(), STAKE_AMOUNT);

      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider2.address, STAKE_AMOUNT);
      await staking.connect(delegator2).delegate(provider1.address, STAKE_AMOUNT);

      // Add rewards
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 20n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider2.address);

      // Wait and withdraw rewards
      await time.increase(LOCK_PERIOD);

      await staking.connect(delegator1).withdrawDelegatorReward(provider1.address);
      await staking.connect(delegator1).withdrawDelegatorReward(provider2.address);
      await staking.connect(delegator2).withdrawDelegatorReward(provider1.address);

      // Providers withdraw commission
      await staking.connect(provider1).withdrawProviderCommission();
      await staking.connect(provider2).withdrawProviderCommission();

      // Undelegate
      await staking.connect(delegator1).undelegate(provider1.address);
      await staking.connect(delegator1).undelegate(provider2.address);
      await staking.connect(delegator2).undelegate(provider1.address);

      const totalShare = await staking.totalShare();
      expect(totalShare).to.equal(0);
    });

    it("Should handle sequential delegations and undelegations", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);

      for (let i = 0; i < 3; i++) {
        await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
        await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
        
        await time.increase(LOCK_PERIOD + 1);
        
        await staking.connect(delegator1).undelegate(provider1.address);
      }

      const totalShare = await staking.totalShare();
      expect(totalShare).to.equal(0);
    });

    it("Should handle commission changes mid-period", async function () {
      await staking.connect(provider1).createProvider("Provider One", 10);
      await basis.connect(delegator1).approve(await staking.getAddress(), STAKE_AMOUNT);
      await staking.connect(delegator1).delegate(provider1.address, STAKE_AMOUNT);
      await basis.transfer(await staking.getAddress(), REWARD_AMOUNT * 10n);
      await staking.connect(operator).notifyRewardAmount(REWARD_AMOUNT, provider1.address);

      await time.increase(LOCK_PERIOD / 2);
      await staking.connect(provider1).editProvider("Provider One", 20);
      await time.increase(LOCK_PERIOD / 2);

      const earned = await staking.earned(delegator1.address, provider1.address);
      expect(earned).to.be.gt(0);
    });
  });
});