use anchor_lang::prelude::*;

declare_id!("EVBDA9Xjq37LdSwxj5s3txybtBAXNuveP8EGsisP2D25");

#[program]
pub mod lottery {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
