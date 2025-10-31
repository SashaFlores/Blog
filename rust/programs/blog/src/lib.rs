use anchor_lang::prelude::*;
use anchor_lang::system_program::{self, Transfer as SystemTransfer};
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, FreezeAccount, Mint, MintTo, ThawAccount, Token, TokenAccount},
};

declare_id!("2KH5fQNCT2BNLqcdVDzi4kCjWhBW9Js4VXXWEjjYt4xu");

pub const CONTRACT_VERSION: &str = "1.0.0";
pub const CONTRACT_NAME: &str = "Blog";

#[program]
pub mod blog {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, premium_fee: u64, uri: String) -> Result<()> {
        require!(premium_fee > 0, BlogError::InvalidNewFee);
        require!(!uri.is_empty(), BlogError::EmptyUri);
        require!(uri.len() <= BlogState::URI_MAX_LEN, BlogError::UriTooLong);

        let state = &mut ctx.accounts.blog_state;
        state.authority = ctx.accounts.authority.key();
        state.premium_fee = premium_fee;
        state.uri = uri;
        state.paused = false;
        state.bump = ctx.bumps.blog_state;
        state.standard_mint = ctx.accounts.standard_mint.key();
        state.standard_mint_bump = ctx.bumps.standard_mint;
        state.premium_mint = ctx.accounts.premium_mint.key();
        state.premium_mint_bump = ctx.bumps.premium_mint;
        state.total_standard = 0;
        state.total_premium = 0;

        Ok(())
    }

    pub fn pause(ctx: Context<TogglePause>) -> Result<()> {
        let state = &mut ctx.accounts.blog_state;
        require!(
            ctx.accounts.authority.key() == state.authority,
            BlogError::Unauthorized
        );
        state.paused = true;
        Ok(())
    }

    pub fn unpause(ctx: Context<TogglePause>) -> Result<()> {
        let state = &mut ctx.accounts.blog_state;
        require!(
            ctx.accounts.authority.key() == state.authority,
            BlogError::Unauthorized
        );
        state.paused = false;
        Ok(())
    }

    pub fn update_premium_fee(ctx: Context<OwnerMutation>, new_fee: u64) -> Result<()> {
        let state = &mut ctx.accounts.blog_state;
        require!(
            ctx.accounts.authority.key() == state.authority,
            BlogError::Unauthorized
        );
        require!(new_fee > 0, BlogError::InvalidNewFee);
        require!(new_fee != state.premium_fee, BlogError::InvalidNewFee);
        state.premium_fee = new_fee;
        Ok(())
    }

    pub fn modify_uri(ctx: Context<OwnerMutation>, new_uri: String) -> Result<()> {
        require!(!new_uri.is_empty(), BlogError::EmptyUri);
        require!(
            new_uri.len() <= BlogState::URI_MAX_LEN,
            BlogError::UriTooLong
        );
        let state = &mut ctx.accounts.blog_state;
        require!(
            ctx.accounts.authority.key() == state.authority,
            BlogError::Unauthorized
        );
        state.uri = new_uri;
        Ok(())
    }

    pub fn mint_standard(ctx: Context<MintStandard>, donation: u64) -> Result<()> {
        require!(!ctx.accounts.blog_state.paused, BlogError::Paused);

        if donation > 0 {
            system_program::transfer(
                CpiContext::new(
                    ctx.accounts.system_program.to_account_info(),
                    SystemTransfer {
                        from: ctx.accounts.payer.to_account_info(),
                        to: ctx.accounts.blog_state.to_account_info(),
                    },
                ),
                donation,
            )?;
            emit!(FundsReceived {
                sender: ctx.accounts.payer.key(),
                amount: donation,
            });
        }

        let authority_key = ctx.accounts.blog_state.authority;
        let bump_seed = [ctx.accounts.blog_state.bump];
        let signer_seeds = [
            BlogState::SEED_PREFIX,
            authority_key.as_ref(),
            &bump_seed[..],
        ];
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.standard_mint.to_account_info(),
                    to: ctx.accounts.user_standard_token.to_account_info(),
                    authority: ctx.accounts.blog_state.to_account_info(),
                },
                &[&signer_seeds],
            ),
            1,
        )?;

        let state = &mut ctx.accounts.blog_state;
        state.total_standard = state
            .total_standard
            .checked_add(1)
            .ok_or(BlogError::SupplyOverflow)?;

        Ok(())
    }

    pub fn mint_premium(ctx: Context<MintPremium>, payment: u64, token_uri: String) -> Result<()> {
        require!(!ctx.accounts.blog_state.paused, BlogError::Paused);
        require!(
            payment >= ctx.accounts.blog_state.premium_fee,
            BlogError::LessThanPremiumFee
        );
        require!(
            token_uri.len() <= BlogState::URI_MAX_LEN,
            BlogError::UriTooLong
        );

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                SystemTransfer {
                    from: ctx.accounts.payer.to_account_info(),
                    to: ctx.accounts.blog_state.to_account_info(),
                },
            ),
            payment,
        )?;

        let authority_key = ctx.accounts.blog_state.authority;
        let bump_seed = [ctx.accounts.blog_state.bump];
        let signer_seeds = [
            BlogState::SEED_PREFIX,
            authority_key.as_ref(),
            &bump_seed[..],
        ];
        if ctx.accounts.user_premium_token.is_frozen() {
            token::thaw_account(CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                ThawAccount {
                    mint: ctx.accounts.premium_mint.to_account_info(),
                    account: ctx.accounts.user_premium_token.to_account_info(),
                    authority: ctx.accounts.blog_state.to_account_info(),
                },
                &[&signer_seeds],
            ))?;
        }

        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.premium_mint.to_account_info(),
                    to: ctx.accounts.user_premium_token.to_account_info(),
                    authority: ctx.accounts.blog_state.to_account_info(),
                },
                &[&signer_seeds],
            ),
            1,
        )?;

        token::freeze_account(CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            FreezeAccount {
                mint: ctx.accounts.premium_mint.to_account_info(),
                account: ctx.accounts.user_premium_token.to_account_info(),
                authority: ctx.accounts.blog_state.to_account_info(),
            },
            &[&signer_seeds],
        ))?;

        let state = &mut ctx.accounts.blog_state;
        state.total_premium = state
            .total_premium
            .checked_add(1)
            .ok_or(BlogError::SupplyOverflow)?;

        emit!(PremiumReceived {
            sender: ctx.accounts.payer.key(),
            token_uri,
        });

        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>) -> Result<()> {
        let state = &ctx.accounts.blog_state;
        require!(
            ctx.accounts.authority.key() == state.authority,
            BlogError::Unauthorized
        );

        let rent_exempt = Rent::get()?.minimum_balance(BlogState::space());
        let blog_info = ctx.accounts.blog_state.to_account_info();
        let current_balance = blog_info.lamports();
        require!(current_balance > rent_exempt, BlogError::EmptyBalance);

        let amount = current_balance
            .checked_sub(rent_exempt)
            .ok_or(BlogError::EmptyBalance)?;
        require!(amount > 0, BlogError::EmptyBalance);

        let authority_key = state.authority;
        let bump_seed = [state.bump];
        let signer_seeds = [
            BlogState::SEED_PREFIX,
            authority_key.as_ref(),
            &bump_seed[..],
        ];
        system_program::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.system_program.to_account_info(),
                SystemTransfer {
                    from: ctx.accounts.blog_state.to_account_info(),
                    to: ctx.accounts.recipient.to_account_info(),
                },
                &[&signer_seeds],
            ),
            amount,
        )?;

        emit!(FundsWithdrawn {
            recipient: ctx.accounts.recipient.key(),
            amount,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = BlogState::space(),
        seeds = [BlogState::SEED_PREFIX, authority.key().as_ref()],
        bump
    )]
    pub blog_state: Account<'info, BlogState>,
    #[account(
        init,
        payer = payer,
        seeds = [BlogState::PREMIUM_MINT_SEED, blog_state.key().as_ref()],
        bump,
        mint::decimals = 0,
        mint::authority = blog_state,
        mint::freeze_authority = blog_state
    )]
    pub premium_mint: Account<'info, Mint>,
    #[account(
        init,
        payer = payer,
        seeds = [BlogState::STANDARD_MINT_SEED, blog_state.key().as_ref()],
        bump,
        mint::decimals = 0,
        mint::authority = blog_state
    )]
    pub standard_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct TogglePause<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [BlogState::SEED_PREFIX, blog_state.authority.as_ref()],
        bump = blog_state.bump
    )]
    pub blog_state: Account<'info, BlogState>,
}

#[derive(Accounts)]
pub struct OwnerMutation<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [BlogState::SEED_PREFIX, blog_state.authority.as_ref()],
        bump = blog_state.bump
    )]
    pub blog_state: Account<'info, BlogState>,
}

#[derive(Accounts)]
pub struct MintStandard<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        mut,
        seeds = [BlogState::SEED_PREFIX, blog_state.authority.as_ref()],
        bump = blog_state.bump
    )]
    pub blog_state: Account<'info, BlogState>,
    #[account(
        mut,
        seeds = [BlogState::STANDARD_MINT_SEED, blog_state.key().as_ref()],
        bump = blog_state.standard_mint_bump
    )]
    pub standard_mint: Account<'info, Mint>,
    #[account(
        init_if_needed,
        payer = payer,
        associated_token::mint = standard_mint,
        associated_token::authority = payer
    )]
    pub user_standard_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct MintPremium<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        mut,
        seeds = [BlogState::SEED_PREFIX, blog_state.authority.as_ref()],
        bump = blog_state.bump
    )]
    pub blog_state: Account<'info, BlogState>,
    #[account(
        mut,
        seeds = [BlogState::PREMIUM_MINT_SEED, blog_state.key().as_ref()],
        bump = blog_state.premium_mint_bump
    )]
    pub premium_mint: Account<'info, Mint>,
    #[account(
        init_if_needed,
        payer = payer,
        associated_token::mint = premium_mint,
        associated_token::authority = payer
    )]
    pub user_premium_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [BlogState::SEED_PREFIX, blog_state.authority.as_ref()],
        bump = blog_state.bump
    )]
    pub blog_state: Account<'info, BlogState>,
    /// CHECK: recipient is arbitrary system account
    #[account(mut)]
    pub recipient: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct BlogState {
    pub authority: Pubkey,
    pub premium_fee: u64,
    pub uri: String,
    pub paused: bool,
    pub bump: u8,
    pub standard_mint: Pubkey,
    pub standard_mint_bump: u8,
    pub premium_mint: Pubkey,
    pub premium_mint_bump: u8,
    pub total_standard: u64,
    pub total_premium: u64,
}

impl BlogState {
    pub const URI_MAX_LEN: usize = 1024;
    pub const SEED_PREFIX: &'static [u8] = b"blog";
    pub const STANDARD_MINT_SEED: &'static [u8] = b"standard-mint";
    pub const PREMIUM_MINT_SEED: &'static [u8] = b"premium-mint";

    pub fn space() -> usize {
        8                                       // discriminator
        + 32                                    // authority
        + 8                                     // premium fee
        + 4 + Self::URI_MAX_LEN                 // uri string
        + 1                                     // paused
        + 1                                     // bump
        + 32                                    // standard mint
        + 1                                     // standard bump
        + 32                                    // premium mint
        + 1                                     // premium bump
        + 8 + 8 // supplies
    }
}

#[event]
pub struct FundsReceived {
    pub sender: Pubkey,
    pub amount: u64,
}

#[event]
pub struct FundsWithdrawn {
    pub recipient: Pubkey,
    pub amount: u64,
}

#[event]
pub struct PremiumReceived {
    pub sender: Pubkey,
    pub token_uri: String,
}

#[error_code]
pub enum BlogError {
    #[msg("Caller is not authorized to perform this action.")]
    Unauthorized,
    #[msg("Premium minting fee must be greater than zero and different from current value.")]
    InvalidNewFee,
    #[msg("Contract is currently paused.")]
    Paused,
    #[msg("Premium minting fee payment is below the required amount.")]
    LessThanPremiumFee,
    #[msg("No withdrawable balance is available.")]
    EmptyBalance,
    #[msg("URI cannot be empty.")]
    EmptyUri,
    #[msg("URI exceeds maximum supported length.")]
    UriTooLong,
    #[msg("Token supply overflow.")]
    SupplyOverflow,
}
