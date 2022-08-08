use chrono::Local;
use env_logger::Builder;
use log::{trace, LevelFilter};
use std::io::Write;
use uuid::Uuid;

pub fn initialize_logging() {
    let request_id = Uuid::new_v4();
    Builder::new()
        .format(move |buf, record| {
            writeln!(
                buf,
                "{} [{}] '{}' - {}",
                Local::now().format("%Y-%m-%dT%H:%M:%S"),
                record.level(),
                &request_id,
                record.args()
            )
        })
        .filter(None, LevelFilter::Info)
        .init();
    trace!("Logging system set up.")
}
