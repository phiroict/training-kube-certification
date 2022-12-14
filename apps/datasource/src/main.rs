#![allow(unused_mut)]
use shared::shared::{IncomingData, DataSet};

mod logging;
use log::{error, info};
use rocket::fairing::{Fairing, Info, Kind};

#[macro_use]
extern crate rocket;

use rocket::{Request, Response};
use chrono::{Utc};
use rocket::http::{Header, Status};
use std::env;
use rocket::serde::json::Json;


struct GatewayFairing {}

#[async_trait]
impl Fairing for GatewayFairing {
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

        if path.path() == "/data" {
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

#[catch(422)]
fn not_processable(req: &Request) -> String {
    format!("[gw] I couldn't process data from call from '{}'. Try something else?", req.uri())
}


//health check for k8s
#[get("/_status/healthz")]
fn healthcheck() -> Status {
    Status {
        code: 200
    }
}


//Processor

#[post("/data", format="json", data="<_data>")]
fn data_request(_data: Json<IncomingData>) -> Json<DataSet> {
    let identity_url = env::var("DATASOURCE_URL");
    let mut target_url;
    match identity_url {
        Ok(val) => {
            info!("Forwarding  {}",  val);
            target_url = format!("http://{}", val);
        }
        Err(_err) => {
            info!("Forwarding to default url {}", "datasource:8001");
            target_url = "http://datasource:8001".to_string();
            ()
        }
    }
    info!("Redirecting to url {}", format!("{}",target_url));
    let data_set = DataSet {
        date: "20220806".to_string(),
        seq: _data.id + 9999,
        name: _data.name.to_string(),
        error: "".to_string(),
    };
    Json(data_set)
}


// Main processor

#[rocket::main]
async fn main() {
    init_logging();
    let fairing = GatewayFairing {};
    let process = rocket::build()
        .attach(fairing)
        .mount("/", routes![data_request,healthcheck])
        .register("/data", catchers![internal_error, not_found, not_processable])
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