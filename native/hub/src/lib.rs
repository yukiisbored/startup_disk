mod actors;
mod signals;

use rinf::{dart_shutdown, write_interface};
use tokio::spawn;

write_interface!();

#[tokio::main(flavor = "current_thread")]
async fn main() {
    spawn(actors::efi::start());

    dart_shutdown().await;
}
