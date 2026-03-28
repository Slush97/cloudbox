/// Inspect SCRFD ONNX model output shape and format.

#[test]
#[cfg(feature = "ml")]
fn inspect_scrfd_onnx_shape() {
    let models_dir = match std::env::var("MODELS_PATH") {
        Ok(p) => p,
        Err(_) => { eprintln!("MODELS_PATH not set"); return; }
    };

    let scrfd_path = std::path::Path::new(&models_dir).join("scrfd.onnx");
    let mut session = ort::session::Session::builder()
        .unwrap()
        .commit_from_file(&scrfd_path)
        .unwrap();

    println!("=== SCRFD ONNX Model ===");
    println!("Inputs: {}", session.inputs().len());
    for inp in session.inputs().iter() {
        println!("  {}", inp.name());
    }
    println!("Outputs: {}", session.outputs().len());
    for out in session.outputs().iter() {
        println!("  {}", out.name());
    }

    // Run with a real image
    let image_path = std::env::var("TEST_IMAGE").ok();
    let input_data: Vec<f32>;

    if let Some(ref path) = image_path {
        if std::path::Path::new(path).exists() {
            let raw_bytes = std::fs::read(path).unwrap();
            let img = image::load_from_memory(&raw_bytes).unwrap().to_rgb8();
            let (w, h) = img.dimensions();
            let rgb = img.into_raw();
            println!("\nImage: {w}x{h}");

            let buf = scry_vision::ImageBuffer::from_raw(rgb, w, h, 3).unwrap();
            let letterbox = scry_vision::transform::Letterbox::new(640, 640);
            let (padded, _) = letterbox.apply_with_info(&buf).unwrap();

            let std_val = 128.0 / 255.0;
            let tensor = scry_vision::transform::ToTensor::normalized(
                [0.5, 0.5, 0.5], [std_val, std_val, std_val]
            ).apply::<scry_llm::backend::cpu::CpuBackend>(&padded);
            input_data = tensor.to_vec();
        } else {
            input_data = vec![0.0f32; 3 * 640 * 640];
        }
    } else {
        input_data = vec![0.0f32; 3 * 640 * 640];
    }

    let shape = vec![1i64, 3, 640, 640];
    let tensor_ref = ort::value::TensorRef::from_array_view(
        (shape.as_slice(), input_data.as_slice())
    ).unwrap();
    let outputs = session.run(ort::inputs![tensor_ref]).unwrap();

    println!("\nNumber of output tensors: {}", outputs.len());
    for (i, (_name, output)) in outputs.iter().enumerate() {
        let (view, data) = output.try_extract_tensor::<f32>().unwrap();
        println!("  output[{i}] '{}': shape={:?}, len={}", _name, view, data.len());

        let min = data.iter().cloned().fold(f32::INFINITY, f32::min);
        let max = data.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        println!("    range=[{min:.4}, {max:.4}]");

        if data.len() >= 20 {
            let first: Vec<String> = data[..20].iter().map(|v| format!("{v:.4}")).collect();
            println!("    first 20: [{}]", first.join(", "));
        }

        // Factor analysis
        let len = data.len();
        let factors: Vec<usize> = (1..=50).filter(|f| len % f == 0).collect();
        println!("    len={len}, small factors: {factors:?}");
    }
}
