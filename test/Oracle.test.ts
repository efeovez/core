import { expect } from "chai";
import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { Oracle, MockStaking } from "../typechain-types";

describe("Oracle Contract (Commit-Reveal Scheme)", function () {
  async function deployOracleFixture() {
    const [owner, provider1, provider2, unauthorizedUser] = await ethers.getSigners();

    const MockStakingFactory = await ethers.getContractFactory("MockStaking");
    const mockStaking = (await MockStakingFactory.deploy()) as MockStaking;

    await mockStaking.setProvider(provider1.address, provider1.address);
    await mockStaking.setProvider(provider2.address, provider2.address);

    const OracleFactory = await ethers.getContractFactory("Oracle");
    const oracle = (await OracleFactory.deploy(await mockStaking.getAddress(), await 30)) as Oracle;

    return { oracle, mockStaking, owner, provider1, provider2, unauthorizedUser };
  }

  function createHash(price: number, salt: string) {
    return ethers.solidityPackedKeccak256(["uint224", "bytes32"], [price, salt]);
  }

  function generateSalt() {
    return ethers.hexlify(ethers.randomBytes(32));
  }

  describe("Deployment & Initial State", function () {
    it("Should set the correct staking address", async function () {
      const { oracle, mockStaking } = await loadFixture(deployOracleFixture);
      expect(await oracle.staking()).to.equal(await mockStaking.getAddress());
    });

    it("Should start in PreVote epoch (Epoch 0)", async function () {
      const { oracle } = await loadFixture(deployOracleFixture);
      expect(await oracle.getCurrentEpochType()).to.equal(0); 
    });
  });

  describe("Epoch Management (Time Travel)", function () {
    it("Should switch to Vote epoch after duration passes", async function () {
      const { oracle } = await loadFixture(deployOracleFixture);
      
      await time.increase(30);

      expect(await oracle.getCurrentEpochType()).to.equal(1);
    });

    it("Should cycle back to PreVote epoch", async function () {
      const { oracle } = await loadFixture(deployOracleFixture);

      await time.increase(120);

      expect(await oracle.getCurrentEpochType()).to.equal(0);
    });
  });

  describe("Access Control", function () {
    it("Should revert if non-provider tries to vote", async function () {
      const { oracle, unauthorizedUser } = await loadFixture(deployOracleFixture);
      const salt = generateSalt();
      const hash = createHash(100, salt);

      await expect(
        oracle.connect(unauthorizedUser).pricePreVote(hash)
      ).to.be.revertedWith("Provider not registered");
    });
  });

  describe("Commit-Reveal Flow", function () {
    const PRICE = 25000;
    let salt: string;
    let hash: string;

    beforeEach(async () => {
      salt = generateSalt();
      hash = createHash(PRICE, salt);
    });

    it("Full Cycle: Successful Commit and Reveal", async function () {
      const { oracle, provider1 } = await loadFixture(deployOracleFixture);

      await expect(oracle.connect(provider1).pricePreVote(hash))
        .to.emit(oracle, "PreVoteSubmitted")
        .withArgs(provider1.address, hash);

      expect(await oracle.pricePreVotes(provider1.address)).to.equal(hash);
      expect(await oracle.isValidPrice(provider1.address)).to.be.false;

      await time.increase(30);

      await expect(oracle.connect(provider1).priceVote(PRICE, salt))
        .to.emit(oracle, "VoteRevealed")
        .withArgs(provider1.address, PRICE, true);

      expect(await oracle.isValidPrice(provider1.address)).to.be.true;
      expect(await oracle.priceVotes(provider1.address)).to.equal(PRICE);
    });

    it("Should fail reveal if salt is incorrect", async function () {
      const { oracle, provider1 } = await loadFixture(deployOracleFixture);

      await oracle.connect(provider1).pricePreVote(hash);

      await time.increase(30);

      const wrongSalt = generateSalt();
      
      await expect(oracle.connect(provider1).priceVote(PRICE, wrongSalt))
        .to.emit(oracle, "VoteRevealed")
        .withArgs(provider1.address, PRICE, false);

      expect(await oracle.isValidPrice(provider1.address)).to.be.false;
      expect(await oracle.priceVotes(provider1.address)).to.equal(0);
    });

    it("Should fail reveal if price is incorrect", async function () {
      const { oracle, provider1 } = await loadFixture(deployOracleFixture);

      await oracle.connect(provider1).pricePreVote(hash);

      await time.increase(30);

      const wrongPrice = PRICE + 1;

      await oracle.connect(provider1).priceVote(wrongPrice, salt);

      expect(await oracle.isValidPrice(provider1.address)).to.be.false;
    });

    it("Should revert if actions are performed in wrong epochs", async function () {
      const { oracle, provider1 } = await loadFixture(deployOracleFixture);

      await expect(
        oracle.connect(provider1).priceVote(PRICE, salt)
      ).to.be.revertedWith("Wrong epoch type");

      await time.increase(30);


      await expect(
        oracle.connect(provider1).pricePreVote(hash)
      ).to.be.revertedWith("Wrong epoch type");
    });
    
    it("Should clear previous validation when new round starts", async function () {
        const { oracle, provider1 } = await loadFixture(deployOracleFixture);
  
        await oracle.connect(provider1).pricePreVote(hash);
        await time.increase(30);
        await oracle.connect(provider1).priceVote(PRICE, salt);
        expect(await oracle.isValidPrice(provider1.address)).to.be.true;

        await time.increase(30);
        
        const newHash = createHash(30000, salt);
        await oracle.connect(provider1).pricePreVote(newHash);
        
        expect(await oracle.isValidPrice(provider1.address)).to.be.false;
      });
  });
});