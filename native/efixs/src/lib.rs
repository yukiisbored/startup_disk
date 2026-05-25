use byteorder::{LittleEndian, ReadBytesExt};
use efivar::efi::Variable;
use thiserror::Error as ThisError;

#[derive(ThisError, Debug)]
pub enum Error {
    #[error("EFI variable error: {0}")]
    EfiVar(#[from] efivar::Error),

    #[error("IO error: {0}")]
    ReadU16(#[from] std::io::Error),

    #[error("Unsupported platform")]
    UnsupportedPlatform,

    #[error("efibootmgr returned a non-zero exit status")]
    EfibootmgrNonZero,
}

/// Represents a boot entry in the EFI system
pub struct BootEntry {
    /// ID of the boot entry
    pub id: u16,
    /// Description of the boot entry
    pub description: String,
    /// Whether this entry is currently running
    pub current: bool,
    /// Whether this entry is the default one
    pub default: bool,
    /// Whether this entry is set to be the next one to boot
    pub next: bool,
}

/// Retrieves the list of boot entries from the EFI system
pub fn boot_entries() -> Result<Vec<BootEntry>, Error> {
    let manager = efivar::system();

    let entries = manager.get_boot_entries()?;

    let current = manager
        .read(&Variable::new("BootCurrent"))?
        .0
        .as_slice()
        .read_u16::<LittleEndian>()?;

    let default = manager.get_boot_order()?.first().copied();

    let next: Option<u16> = manager
        .read(&Variable::new("BootNext"))
        .ok()
        .and_then(|var| var.0.as_slice().read_u16::<LittleEndian>().ok());

    Ok(entries
        .into_iter()
        .filter_map(|(res, _var)| {
            let Ok(boot_var) = res else {
                return None;
            };

            Some(BootEntry {
                id: boot_var.id,
                description: boot_var.entry.description,
                current: current == boot_var.id,
                default: default == Some(boot_var.id),
                next: next == Some(boot_var.id),
            })
        })
        .collect())
}

fn new_boot_order(id: u16) -> Result<Vec<u16>, Error> {
    let manager = efivar::system();

    let mut order = manager.get_boot_order()?;
    order.retain(|&x| x != id);
    order.insert(0, id);

    Ok(order)
}

#[cfg(windows)]
fn set_default_via_efivar(id: u16) -> Result<(), Error> {
    let order = new_boot_order(id)?;

    let mut manager = efivar::system();
    manager.set_boot_order(order)?;

    Ok(())
}

#[cfg(unix)]
fn set_default_via_efibootmgr(id: u16) -> Result<(), Error> {
    use std::process::Command;

    let order = new_boot_order(id)?;
    let order_arg = order
        .iter()
        .map(|id| format!("{:04X}", id))
        .collect::<Vec<_>>()
        .join(",");

    let status = Command::new("pkexec")
        .args([
            "pkexec",
            "sh",
            "-c",
            &format!("efibootmgr -o {}", order_arg),
        ])
        .status()?;

    if !status.success() {
        return Err(Error::EfibootmgrNonZero);
    }

    Ok(())
}

/// Sets the specified boot entry as the default by moving it to the front of the boot order
pub fn set_default(id: u16) -> Result<(), Error> {
    cfg_select! {
        windows => set_default_via_efivar(id),
        unix => set_default_via_efibootmgr(id),
        _ => Err(Error::UnsupportedPlatform),
    }
}

#[cfg(windows)]
fn set_next_via_efivar(id: Option<u16>) -> Result<(), Error> {
    use efivar::efi::VariableFlags;

    let mut manager = efivar::system();

    if let Some(id) = id {
        manager.write(
            &Variable::new("BootNext"),
            VariableFlags::default(),
            &id.to_le_bytes(),
        )?;
    } else {
        manager.delete(&Variable::new("BootNext"))?;
    }

    Ok(())
}

#[cfg(unix)]
fn set_next_via_efibootmgr(id: Option<u16>) -> Result<(), Error> {
    use std::process::Command;

    let status = if let Some(id) = id {
        Command::new("pkexec")
            .args(["pkexec", "sh", "-c", &format!("efibootmgr -n {:04X}", id)])
            .status()?
    } else {
        Command::new("pkexec")
            .args(["pkexec", "sh", "-c", "efibootmgr -N"])
            .status()?
    };

    if !status.success() {
        return Err(Error::EfibootmgrNonZero);
    }

    Ok(())
}

/// Sets the specified boot entry as the next one to boot by writing to the BootNext variable
pub fn set_next(id: Option<u16>) -> Result<(), Error> {
    cfg_select! {
        windows => set_next_via_efivar(id),
        unix => set_next_via_efibootmgr(id),
        _ => Err(Error::UnsupportedPlatform),
    }
}
