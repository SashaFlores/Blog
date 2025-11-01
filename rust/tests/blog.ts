import * as anchor from "@coral-xyz/anchor";
import type { Program } from "@coral-xyz/anchor";
import { Blog } from "../target/types/blog";
import BN from "bn.js";
import { expect } from "chai";
import {
  Keypair,
  LAMPORTS_PER_SOL,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";


const TOKEN_PROGRAM_ID = anchor.utils.token.TOKEN_PROGRAM_ID;
const ASSOCIATED_TOKEN_PROGRAM_ID = anchor.utils.token.ASSOCIATED_PROGRAM_ID;
const PREMIUM_FEE = new BN(50_000_000); // 0.05 SOL
const INITIAL_URI = "https://example.com/metadata/";

const amountToBuffer = (amount: BN | number): Buffer => {
  const value = BN.isBN(amount) ? amount : new BN(amount);
  return value.toArrayLike(Buffer, "le", 8);
};

const expectAnchorError = async (
  handler: () => Promise<unknown>,
  expectedName: string
) => {
  try {
    await handler();
    expect.fail(`Expected Anchor error ${expectedName}`);
  } catch (err: any) {
    const lowerExpected = expectedName.toLowerCase();
    const name = (err?.error?.errorCode?.name ?? err?.errorCode?.name ?? "")
      .toString()
      .toLowerCase();
    const code = (err?.error?.errorCode?.code ?? err?.errorCode?.code ?? "")
      .toString()
      .toLowerCase();
    const message = (err?.error?.errorMessage ?? err?.message ?? "")
      .toString()
      .toLowerCase();
    const logs = Array.isArray(err?.logs)
      ? err.logs.join(" ").toLowerCase()
      : "";

    if (
      name !== lowerExpected &&
      code !== lowerExpected &&
      !message.includes(lowerExpected) &&
      !logs.includes(lowerExpected)
    ) {
      throw err;
    }
  }
};

type PublicKey = anchor.web3.PublicKey;

describe("blog owner and mint flows", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const program = anchor.workspace.Blog as Program<Blog>;

  const authority = provider.wallet;
  const standardUser = Keypair.generate();
  const premiumUser = Keypair.generate();
  const outsider = Keypair.generate();
  const withdrawRecipient = Keypair.generate();

  let blogState: PublicKey;
  let premiumMint: PublicKey;
  let standardMint: PublicKey;

  const ataFor = (mint: PublicKey, owner: PublicKey) =>
    anchor.utils.token.associatedAddress({ mint, owner });

  const confirm = async (signature: string) => {
    const latest = await provider.connection.getLatestBlockhash();
    await provider.connection.confirmTransaction(
      { signature, ...latest },
      "confirmed"
    );
  };

  const airdrop = async (to: PublicKey, amount = LAMPORTS_PER_SOL) => {
    const sig = await provider.connection.requestAirdrop(to, amount);
    await confirm(sig);
  };

  const mintStandard = async (payer: Keypair, donation: BN) => {
    const ata = ataFor(standardMint, payer.publicKey);
    await program.methods
      .mintStandard(donation)
      .accounts({
        payer: payer.publicKey,
        blogState,
        standardMint,
        userStandardToken: ata,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      } as any)
      .signers([payer])
      .rpc();
    return ata;
  };

  const mintPremium = async (payer: Keypair, payment: BN, uri: string) => {
    const ata = ataFor(premiumMint, payer.publicKey);
    await program.methods
      .mintPremium(payment, uri)
      .accounts({
        payer: payer.publicKey,
        blogState,
        premiumMint,
        userPremiumToken: ata,
        tokenProgram: TOKEN_PROGRAM_ID,
        associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      } as any)
      .signers([payer])
      .rpc();
    return ata;
  };

  before("initialize program", async () => {
    await Promise.all([
      airdrop(authority.publicKey),
      airdrop(standardUser.publicKey),
      airdrop(premiumUser.publicKey),
      airdrop(outsider.publicKey),
      airdrop(withdrawRecipient.publicKey),
    ]);

    [blogState] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("blog"), authority.publicKey.toBuffer()],
      program.programId
    );
    [premiumMint] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("premium-mint"), blogState.toBuffer()],
      program.programId
    );
    [standardMint] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("standard-mint"), blogState.toBuffer()],
      program.programId
    );

    await program.methods
      .initialize(PREMIUM_FEE, INITIAL_URI)
      .accounts({
        payer: authority.publicKey,
        authority: authority.publicKey,
        blogState,
        premiumMint,
        standardMint,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId,
        rent: anchor.web3.SYSVAR_RENT_PUBKEY,
      } as any)
      .rpc();
  });

  describe("initialization state", () => {
    it("stores authority, URI, fee, and pause flag", async () => {
      const state = await program.account.blogState.fetch(blogState);
      expect(state.authority.toBase58()).to.eq(authority.publicKey.toBase58());
      expect(state.uri).to.eq(INITIAL_URI);
      expect(state.premiumFee.toNumber()).to.eq(PREMIUM_FEE.toNumber());
      expect(state.paused).to.be.false;
    });
  });

  describe("owner-only controls", () => {
    it("rejects non-authority callers", async () => {
      await expectAnchorError(
        () =>
          program.methods
            .updatePremiumFee(PREMIUM_FEE.add(new BN(1)))
            .accounts({ authority: outsider.publicKey, blogState } as any)
            .signers([outsider])
            .rpc(),
        "unauthorized"
      );

      await expectAnchorError(
        () =>
          program.methods
            .modifyUri("https://bad.example")
            .accounts({ authority: outsider.publicKey, blogState } as any)
            .signers([outsider])
            .rpc(),
        "unauthorized"
      );

      await expectAnchorError(
        () =>
          program.methods
            .pause()
            .accounts({ authority: outsider.publicKey, blogState } as any)
            .signers([outsider])
            .rpc(),
        "unauthorized"
      );
    });

    it("updates premium fee with validation", async () => {
      const higherFee = PREMIUM_FEE.add(new BN(10));
      await program.methods
        .updatePremiumFee(higherFee)
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      let state = await program.account.blogState.fetch(blogState);
      expect(state.premiumFee.toNumber()).to.eq(higherFee.toNumber());

      await expectAnchorError(
        () =>
          program.methods
            .updatePremiumFee(new BN(0))
            .accounts({ authority: authority.publicKey, blogState } as any)
            .rpc(),
        "invalidNewFee"
      );

      await expectAnchorError(
        () =>
          program.methods
            .updatePremiumFee(higherFee)
            .accounts({ authority: authority.publicKey, blogState } as any)
            .rpc(),
        "invalidNewFee"
      );

      await program.methods
        .updatePremiumFee(PREMIUM_FEE)
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      state = await program.account.blogState.fetch(blogState);
      expect(state.premiumFee.toNumber()).to.eq(PREMIUM_FEE.toNumber());
    });

    it("modifies URI and rejects empty strings", async () => {
      const newUri = "https://blog.test/v2/";
      await program.methods
        .modifyUri(newUri)
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      let state = await program.account.blogState.fetch(blogState);
      expect(state.uri).to.eq(newUri);

      await expectAnchorError(
        () =>
          program.methods
            .modifyUri("")
            .accounts({ authority: authority.publicKey, blogState } as any)
            .rpc(),
        "emptyUri"
      );

      await program.methods
        .modifyUri(INITIAL_URI)
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();
    });

    it("pauses and unpauses only for authority", async () => {
      await program.methods
        .pause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      let state = await program.account.blogState.fetch(blogState);
      expect(state.paused).to.be.true;

      await expectAnchorError(
        () =>
          program.methods
            .unpause()
            .accounts({ authority: outsider.publicKey, blogState } as any)
            .signers([outsider])
            .rpc(),
        "unauthorized"
      );

      await program.methods
        .unpause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      state = await program.account.blogState.fetch(blogState);
      expect(state.paused).to.be.false;
    });
  });

  describe("standard minting", () => {
    it("mints for free when not paused", async () => {
      const ata = await mintStandard(standardUser, new BN(0));
      const balance = await provider.connection.getTokenAccountBalance(ata);
      expect(balance.value.uiAmount).to.eq(1);
    });

    it("accepts donations and emits fundsReceived", async () => {
      const donor = Keypair.generate();
      await airdrop(donor.publicKey);
      const donation = new BN(250_000_000);

      let observed: any = null;
      const listener = await program.addEventListener("fundsReceived", (evt) => {
        observed = evt;
      });

      await mintStandard(donor, donation);
      await new Promise((resolve) => setTimeout(resolve, 200));
      await program.removeEventListener(listener);

      expect(observed).to.not.be.null;
      expect(observed.sender.toBase58()).to.eq(donor.publicKey.toBase58());
      expect((observed.amount as BN).toNumber()).to.eq(donation.toNumber());
    });

    it("reverts minting when paused", async () => {
      await program.methods
        .pause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      await expectAnchorError(() => mintStandard(standardUser, new BN(0)), "paused");

      await program.methods
        .unpause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();
    });
  });

  describe("premium minting", () => {
    it("requires fee, emits event, and freezes account", async () => {
      await expectAnchorError(
        () => mintPremium(premiumUser, PREMIUM_FEE.sub(new BN(1)), "bad"),
        "lessThanPremiumFee"
      );

      let captured: any = null;
      const listener = await program.addEventListener("premiumReceived", (evt) => {
        captured = evt;
      });

      const ata = await mintPremium(
        premiumUser,
        PREMIUM_FEE,
        "https://premium.uri"
      );
      await new Promise((resolve) => setTimeout(resolve, 200));
      await program.removeEventListener(listener);

      expect(captured).to.not.be.null;
      expect(captured.sender.toBase58()).to.eq(premiumUser.publicKey.toBase58());
      expect(captured.tokenUri).to.eq("https://premium.uri");

      const parsed = await provider.connection.getParsedAccountInfo(ata);
      const state = (parsed.value?.data as any)?.parsed?.info?.state;
      expect(state).to.eq("frozen");

      const recipient = Keypair.generate();
      await airdrop(recipient.publicKey);
      const recipientAta = ataFor(premiumMint, recipient.publicKey);

      const createAtaIx = new TransactionInstruction({
        programId: ASSOCIATED_TOKEN_PROGRAM_ID,
        keys: [
          { pubkey: premiumUser.publicKey, isSigner: true, isWritable: true },
          { pubkey: recipientAta, isSigner: false, isWritable: true },
          { pubkey: recipient.publicKey, isSigner: false, isWritable: false },
          { pubkey: premiumMint, isSigner: false, isWritable: false },
          { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
          { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
          { pubkey: anchor.web3.SYSVAR_RENT_PUBKEY, isSigner: false, isWritable: false },
        ],
        data: Buffer.alloc(0),
      });

      const transferIx = new TransactionInstruction({
        programId: TOKEN_PROGRAM_ID,
        keys: [
          { pubkey: ata, isSigner: false, isWritable: true },
          { pubkey: recipientAta, isSigner: false, isWritable: true },
          { pubkey: premiumUser.publicKey, isSigner: true, isWritable: false },
        ],
        data: Buffer.concat([Buffer.from([3]), amountToBuffer(1)]),
      });

      const tx = new Transaction().add(createAtaIx, transferIx);
      try {
        await provider.sendAndConfirm(tx, [premiumUser]);
        expect.fail("transfer succeeded from frozen account");
      } catch (err: any) {
        const message = String(err?.message ?? "").toLowerCase();
        expect(message).to.include("account is frozen");
      }
    });
  });

  describe("standard transfers", () => {
    it("allows transfers while unpaused", async () => {
      const sender = Keypair.generate();
      const recipient = Keypair.generate();
      await airdrop(sender.publicKey);
      await airdrop(recipient.publicKey);

      const senderAta = await mintStandard(sender, new BN(0));
      const recipientAta = ataFor(standardMint, recipient.publicKey);

      const createAtaIx = new TransactionInstruction({
        programId: ASSOCIATED_TOKEN_PROGRAM_ID,
        keys: [
          { pubkey: sender.publicKey, isSigner: true, isWritable: true },
          { pubkey: recipientAta, isSigner: false, isWritable: true },
          { pubkey: recipient.publicKey, isSigner: false, isWritable: false },
          { pubkey: standardMint, isSigner: false, isWritable: false },
          { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
          { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
          { pubkey: anchor.web3.SYSVAR_RENT_PUBKEY, isSigner: false, isWritable: false },
        ],
        data: Buffer.alloc(0),
      });

      const transferIx = new TransactionInstruction({
        programId: TOKEN_PROGRAM_ID,
        keys: [
          { pubkey: senderAta, isSigner: false, isWritable: true },
          { pubkey: recipientAta, isSigner: false, isWritable: true },
          { pubkey: sender.publicKey, isSigner: true, isWritable: false },
        ],
        data: Buffer.concat([Buffer.from([3]), amountToBuffer(1)]),
      });

      const tx = new Transaction().add(createAtaIx, transferIx);
      await provider.sendAndConfirm(tx, [sender]);

      const senderBalance = await provider.connection.getTokenAccountBalance(senderAta);
      const recipientBalance = await provider.connection.getTokenAccountBalance(recipientAta);
      expect(senderBalance.value.uiAmount).to.eq(0);
      expect(recipientBalance.value.uiAmount).to.eq(1);
    });
  });

  describe("withdrawals", () => {
    it("allows owner withdrawal (even when paused) and emits event", async () => {
      const donation = new BN(1_000_000);
      await mintStandard(standardUser, donation);

      await program.methods
        .pause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();

      const before = await provider.connection.getBalance(withdrawRecipient.publicKey);

      let captured: any = null;
      const listener = await program.addEventListener("fundsWithdrawn", (evt) => {
        captured = evt;
      });

      await program.methods
        .withdraw()
        .accounts({
          authority: authority.publicKey,
          blogState,
          recipient: withdrawRecipient.publicKey,
          systemProgram: SystemProgram.programId,
        } as any)
        .rpc();

      await new Promise((resolve) => setTimeout(resolve, 200));
      await program.removeEventListener(listener);

      const after = await provider.connection.getBalance(withdrawRecipient.publicKey);
      expect(captured).to.not.be.null;
      const withdrawn = (captured.amount as anchor.BN).toNumber();
      expect(withdrawn).to.be.gte(donation.toNumber());
      expect(after - before).to.eq(withdrawn);
      expect(captured.recipient.toBase58()).to.eq(withdrawRecipient.publicKey.toBase58());

      await program.methods
        .unpause()
        .accounts({ authority: authority.publicKey, blogState } as any)
        .rpc();
    });
  });
});
