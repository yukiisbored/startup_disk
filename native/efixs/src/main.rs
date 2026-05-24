use anyhow::Result;
use efixs::boot_entries;

fn main() -> Result<()> {
    let entries = boot_entries()?;

    for entry in entries {
        println!("ID: {}", entry.id);
        println!("Description: {}", entry.description);
        println!("Active: {}", entry.current);
        println!("Default: {}", entry.default);
        println!("Next: {}", entry.next);
        println!();
    }

    Ok(())
}
