use anchor_lang::prelude::*;

declare_id!("2KH5fQNCT2BNLqcdVDzi4kCjWhBW9Js4VXXWEjjYt4xu");

#[program]
pub mod blog {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
