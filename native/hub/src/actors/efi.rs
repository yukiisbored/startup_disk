use rinf::{DartSignal, RustSignal};

use crate::signals::{BootEntry, GetBootEntries, GetBootEntriesResult};

pub async fn start() {
    let receiver = GetBootEntries::get_dart_signal_receiver();

    while receiver.recv().await.is_some() {
        let entries = efixs::boot_entries()
            .unwrap_or_default()
            .into_iter()
            .map(BootEntry::from)
            .collect();

        GetBootEntriesResult { entries }.send_signal_to_dart();
    }
}
