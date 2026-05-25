use rinf::{DartSignal, RustSignal};
use tokio::select;

use crate::signals::{BootEntry, GetBootEntries, GetBootEntriesResult, Reboot, SetDefault};

fn send_boot_entries() {
    let entries = efixs::boot_entries()
        .unwrap_or_default()
        .into_iter()
        .map(BootEntry::from)
        .collect();

    GetBootEntriesResult { entries }.send_signal_to_dart();
}

pub async fn start() {
    let get_boot_entries = GetBootEntries::get_dart_signal_receiver();
    let set_default = SetDefault::get_dart_signal_receiver();
    let reboot = Reboot::get_dart_signal_receiver();

    loop {
        select! {
            Some(set_default) = set_default.recv() => {
                let id = set_default.message.0;

                if let Err(e) = efixs::set_default(id) {
                    eprintln!("Failed to set default boot entry: {}", e);
                }

                send_boot_entries();
            }
            Some(reboot) = reboot.recv() => {
                let id = reboot.message.0;

                if let Err(e) = efixs::set_next(Some(id)) {
                    eprintln!("Failed to set next boot entry: {}", e);
                    continue;
                }

                if let Err(e) = system_shutdown::reboot() {
                    eprintln!("Failed to reboot: {}", e);
                    continue;
                }

                send_boot_entries();
            }
            Some(_) = get_boot_entries.recv() => send_boot_entries(),
        }
    }
}
