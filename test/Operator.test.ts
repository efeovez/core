import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { Operator } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("Staking Contract", function () {
  let operator: Operator;
  let owner1: HardhatEthersSigner;
  let owner2: HardhatEthersSigner;
  let user: HardhatEthersSigner;

  beforeEach(async function () {
    [owner1, owner2, user] = await ethers.getSigners();

    // deploy operator
    const OperatorFactory = await ethers.getContractFactory("Operator");
    operator = await OperatorFactory.connect(owner1).deploy();
    await operator.waitForDeployment();
  });

  describe("Operator Test", function () {
    it("Should return the correct operator address", async function () {
      const getOperatorFunc = await operator.connect(user).getOperator()

      expect(getOperatorFunc).to.equal(owner1.address);
    });

    it("Should return true when the caller is the operator", async function () {
      const isOperatorFunc = await operator.connect(owner1).isOperator()

      expect(isOperatorFunc).to.equal(true)
    });

    it("Should return false when the caller is not the operator", async function () {
      const isOperatorFunc = await operator.connect(user).isOperator()

      expect(isOperatorFunc).to.equal(false)
    });

    it("Should transfer the operator to a new address when the caller is the operator", async function () {
      const transferOperatorFunc = await operator.connect(owner1).transferOperator(owner2.address)
      const getOperatorFunc = await operator.connect(user).getOperator()

      expect(getOperatorFunc).to.equal(owner2.address)
    });

    it("Should revert if a non-operator tries to transfer the operator", async function () {
      await expect(
        operator.connect(user).transferOperator(owner2)
      ).to.be.revertedWith("msg.sender is not the operator");
    });

    it("Should revert if the new operator address is zero", async function () {
      await expect(
        operator.connect(owner1).transferOperator("0x0000000000000000000000000000000000000000")
      ).to.be.revertedWith("zero address given for new operator");
    });

    it("Should emit OperatorTransfered event", async function () {
      await expect(operator.connect(owner1).transferOperator(owner2.address))
        .to.emit(operator, "OperatorTransfered")
        .withArgs(owner1.address, owner2.address);
    });
  });
});