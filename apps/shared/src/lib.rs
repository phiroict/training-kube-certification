
pub mod shared {
    use serde::{Serialize, Deserialize};

    #[derive(Serialize, Deserialize, Debug)]
    pub struct DataSet {
        pub date: String,
        pub seq: u64,
        pub name: String,
        pub error: String,
    }
}
