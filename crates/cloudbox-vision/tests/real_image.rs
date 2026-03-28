/// End-to-end test with a real photo.
///
/// Run: `MODELS_PATH=./models TEST_IMAGE=/tmp/test_group.jpg cargo test -p cloudbox-vision --features ml --test real_image -- --nocapture`

#[test]
#[cfg(feature = "ml")]
fn detect_faces_in_real_photo() {
    let models_dir = match std::env::var("MODELS_PATH") {
        Ok(p) => p,
        Err(_) => {
            eprintln!("MODELS_PATH not set, skipping");
            return;
        }
    };
    let image_path = match std::env::var("TEST_IMAGE") {
        Ok(p) => p,
        Err(_) => {
            eprintln!("TEST_IMAGE not set, skipping");
            return;
        }
    };

    let scrfd = std::path::Path::new(&models_dir).join("scrfd.onnx");
    let arcface = std::path::Path::new(&models_dir).join("arcface.onnx");
    let pipeline =
        cloudbox_vision::faces::FacePipeline::from_onnx(&scrfd, &arcface, 640).unwrap();

    // Read and decode image
    let raw_bytes = std::fs::read(&image_path).unwrap();
    let img = image::load_from_memory(&raw_bytes).unwrap().to_rgb8();
    let (width, height) = img.dimensions();
    let rgb_data = img.into_raw();

    println!("Image: {image_path} ({width}x{height})");

    // Detect faces
    let detections = pipeline.detect(&rgb_data, width, height, 0.3).unwrap();
    println!("Detections: {} faces found", detections.len());
    for (i, d) in detections.iter().enumerate() {
        let px = (d.bbox[0] * width as f32) as u32;
        let py = (d.bbox[1] * height as f32) as u32;
        let pw = (d.bbox[2] * width as f32) as u32;
        let ph = (d.bbox[3] * height as f32) as u32;
        println!(
            "  face {i}: conf={:.2}, bbox=[{px},{py} {pw}x{ph}]",
            d.confidence
        );
    }

    // Detect + embed
    let faces = pipeline
        .detect_and_embed(&rgb_data, width, height, 0.3)
        .unwrap();
    println!("\nEmbeddings: {} faces", faces.len());

    for (i, face) in faces.iter().enumerate() {
        let norm: f32 = face.embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        println!("  face {i}: embedding dim={}, norm={norm:.4}", face.embedding.len());
        assert_eq!(face.embedding.len(), 512);
        assert!((norm - 1.0).abs() < 0.01);
    }

    // Compare all pairs
    if faces.len() >= 2 {
        println!("\nPairwise cosine similarity:");
        for i in 0..faces.len() {
            for j in (i + 1)..faces.len() {
                let sim = scry_vision::postprocess::embedding::cosine_similarity(
                    &faces[i].embedding,
                    &faces[j].embedding,
                );
                println!("  face {i} vs face {j}: {sim:.4}");
            }
        }
    }
}
