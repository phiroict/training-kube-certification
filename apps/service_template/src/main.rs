#![allow(unused_mut)]


mod logging;
use log::{info};
use rocket::fairing::{Fairing, Info, Kind};

#[macro_use]
extern crate rocket;

use rocket::serde::{Serialize};
use serde::Deserialize;
use rocket::{Request, Response};
use chrono::{Utc};
use rocket::http::{Header, Status};


struct CustomFairing {}

#[async_trait]
impl Fairing for CustomFairing {
    fn info(&self) -> Info {
        Info {
            name: "File fairing",
            kind: (Kind::Response),
        }
    }

    async fn on_response<'r>(&self, req: &'r Request<'_>, res: &mut Response<'r>) {
        info!("I am in the fairing on_response");
        let path = req.uri();
        info!("Value of the path: {}", path.path().to_string());

        if path.path() == "/gateway" {
            info!("Entering the gateway fairing processing on on_response");
            let current_time = Utc::now();
            let date_format = current_time.format("%Y%m%d_%H%M%S");
            res.set_header(Header::new(
                "X-Gateway-Forward",
                format!(
                    "Called at {}",
                    date_format
                ),
            ));
        }
    }
}


pub fn init_logging() {
    logging::initialize_logging();
}

// Error processing
#[catch(500)]
fn internal_error() -> &'static str {
    "Could not process this call"
}

#[catch(404)]
fn not_found(req: &Request) -> String {
    format!("[gw] I couldn't find '{}'. Try something else?", req.uri())
}


#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "rocket::serde")]
struct IncomingData {
    name: String,
    id: u64,
}

//health check for k8s
#[get("/_status/healthz")]
fn healthcheck() -> Status {
    Status {
        code: 200
    }
}



// Main processor

#[rocket::main]
async fn main() {
    init_logging();
    let fairing = CustomFairing {};
    let process = rocket::build()
        .attach(fairing)
        .mount("/", routes![healthcheck])
        .register("/gateway", catchers![internal_error, not_found])
        .launch()
        .await;
    match process {
        Ok(_) => {
            info!("Process started")
        }
        Err(e) => {
            error!("Could not create the rocket instance {}", e.to_string());
        }
    }
    info!("Processing done, leaving application")
}