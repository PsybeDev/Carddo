#![cfg(feature = "ts")]

use std::fs;
use std::path::Path;

#[test]
fn export_all_types() {
    let content = ditto_core::schema::generate_typescript();

    let out_path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../frontend/src/lib/types/ditto.generated.ts");

    if let Some(parent) = out_path.parent() {
        fs::create_dir_all(parent).expect("failed to create types dir");
    }

    fs::write(&out_path, content).expect("failed to write ditto.generated.ts");
}
