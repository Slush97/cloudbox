/// Smoke test: verify SCRFD + ArcFace ONNX models load and produce correct output.
///
/// Requires: `MODELS_PATH` env var pointing to directory with scrfd.onnx + arcface.onnx.
/// Run: `MODELS_PATH=./models cargo test -p cloudbox-vision --features ml --test smoke_onnx`

#[test]
#[cfg(feature = "ml")]
fn load_and_detect_blank_image() {
    let models_dir = match std::env::var("MODELS_PATH") {
        Ok(p) => p,
        Err(_) => {
            eprintln!("MODELS_PATH not set, skipping ONNX smoke test");
            return;
        }
    };

    let scrfd = std::path::Path::new(&models_dir).join("scrfd.onnx");
    let arcface = std::path::Path::new(&models_dir).join("arcface.onnx");

    if !scrfd.exists() || !arcface.exists() {
        eprintln!("Model files not found in {models_dir}, skipping");
        return;
    }

    let pipeline =
        cloudbox_vision::faces::FacePipeline::from_onnx(&scrfd, &arcface, 640).unwrap();

    // Blank gray image — should detect 0 faces
    let image = vec![128u8; 640 * 640 * 3];
    let dets = pipeline.detect(&image, 640, 640, 0.5).unwrap();
    println!("Blank image: {} detections (expected 0)", dets.len());
    assert_eq!(dets.len(), 0, "blank image should have no face detections");
}

#[test]
#[cfg(feature = "ml")]
fn detect_and_embed_synthetic_face() {
    let models_dir = match std::env::var("MODELS_PATH") {
        Ok(p) => p,
        Err(_) => {
            eprintln!("MODELS_PATH not set, skipping ONNX smoke test");
            return;
        }
    };

    let scrfd = std::path::Path::new(&models_dir).join("scrfd.onnx");
    let arcface = std::path::Path::new(&models_dir).join("arcface.onnx");

    if !scrfd.exists() || !arcface.exists() {
        eprintln!("Model files not found in {models_dir}, skipping");
        return;
    }

    let pipeline =
        cloudbox_vision::faces::FacePipeline::from_onnx(&scrfd, &arcface, 640).unwrap();

    // detect_and_embed should not crash on a blank image (even if 0 faces found)
    let image = vec![128u8; 640 * 480 * 3];
    let faces = pipeline
        .detect_and_embed(&image, 640, 480, 0.3)
        .unwrap();

    println!("480p image: {} face embeddings", faces.len());

    // Any detected faces should have valid embeddings
    for (i, face) in faces.iter().enumerate() {
        assert_eq!(face.embedding.len(), 512, "face {i} embedding should be 512-dim");
        let norm: f32 = face.embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!(
            (norm - 1.0).abs() < 0.01,
            "face {i} embedding norm={norm}, expected ~1.0"
        );
        // Bbox should be normalized 0..1
        for (j, &v) in face.bbox.iter().enumerate() {
            assert!(v >= 0.0 && v <= 1.0, "face {i} bbox[{j}]={v} out of range");
        }
    }
}
