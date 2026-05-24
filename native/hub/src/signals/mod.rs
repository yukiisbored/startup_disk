use efixs::BootEntry as EfixsBootEntry;
use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, DartSignal)]
pub struct GetBootEntries;

#[derive(Serialize, RustSignal)]
pub struct GetBootEntriesResult {
    pub entries: Vec<BootEntry>,
}

#[derive(Serialize, SignalPiece)]
pub struct BootEntry {
    pub id: u16,
    pub description: String,
    pub current: bool,
    pub selected: bool,
    pub next: bool,
}

impl From<EfixsBootEntry> for BootEntry {
    fn from(entry: EfixsBootEntry) -> Self {
        Self {
            id: entry.id,
            description: entry.description,
            current: entry.current,
            selected: entry.default,
            next: entry.next,
        }
    }
}
