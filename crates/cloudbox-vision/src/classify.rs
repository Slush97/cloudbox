use scry_vision::image::ImageBuffer;
use scry_vision::model::VisionModel;
use scry_vision::postprocess::classify::{top_k_softmax, Classification};
use scry_vision::transform::resize::{InterpolationMode, Resize};
use scry_vision::transform::ImageTransform;

use crate::imagenet_labels;
use crate::VisionError;

const INPUT_SIZE: u32 = 224;
const IMAGENET_MEAN: [f32; 3] = [0.485, 0.456, 0.406];
const IMAGENET_STD: [f32; 3] = [0.229, 0.224, 0.225];

/// MobileNet v2 image classifier for auto-tagging.
///
/// Wraps an ONNX model with ImageNet preprocessing. Thread-safe via internal
/// mutex in `OnnxModel`. Share across tasks with `Arc<ImageClassifier>`.
pub struct ImageClassifier {
    model: Box<dyn VisionModel>,
}

impl ImageClassifier {
    pub fn new(model: Box<dyn VisionModel>) -> Self {
        Self { model }
    }

    #[cfg(feature = "ml")]
    pub fn from_onnx(path: impl AsRef<std::path::Path>) -> Result<Self, VisionError> {
        let model = scry_vision::model::OnnxModel::from_file(path)
            .map_err(|e| VisionError::Inference(e.to_string()))?;
        Ok(Self::new(Box::new(model)))
    }

    /// Classify an image and return top-k predictions.
    ///
    /// `image_data`: raw RGB pixel data (HWC u8 layout).
    pub fn classify_image(
        &self,
        image_data: &[u8],
        width: u32,
        height: u32,
        top_k: usize,
    ) -> Result<Vec<Classification>, VisionError> {
        let img = ImageBuffer::from_raw(image_data.to_vec(), width, height, 3)
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        // Resize to 224x224
        let resize = Resize::new(INPUT_SIZE, INPUT_SIZE, InterpolationMode::Bilinear);
        let resized = resize
            .apply(&img)
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        // HWC u8 -> CHW f32 with ImageNet normalization
        let h = resized.height as usize;
        let w = resized.width as usize;
        let num_pixels = h * w;
        let mut tensor = vec![0.0f32; 3 * num_pixels];
        for y in 0..h {
            for x in 0..w {
                let src_idx = (y * w + x) * 3;
                let dst_pixel = y * w + x;
                for ch in 0..3 {
                    let val = resized.data[src_idx + ch] as f32 / 255.0;
                    tensor[ch * num_pixels + dst_pixel] =
                        (val - IMAGENET_MEAN[ch]) / IMAGENET_STD[ch];
                }
            }
        }

        // Forward pass: [1, 3, 224, 224] -> [1, 1000]
        let logits = self
            .model
            .forward(&tensor, &[1, 3, INPUT_SIZE as usize, INPUT_SIZE as usize])
            .map_err(|e| VisionError::Inference(e.to_string()))?;

        Ok(top_k_softmax(&logits, top_k))
    }

    /// Classify and return `(tag_name, confidence)` pairs, filtered by threshold.
    pub fn auto_tag(
        &self,
        image_data: &[u8],
        width: u32,
        height: u32,
        top_k: usize,
        min_confidence: f32,
    ) -> Result<Vec<(String, f32)>, VisionError> {
        let predictions = self.classify_image(image_data, width, height, top_k)?;
        Ok(predictions
            .into_iter()
            .filter(|p| p.score >= min_confidence)
            .filter_map(|p| {
                imagenet_labels::label_to_tag_name(p.class_id)
                    .map(|name| (name.to_string(), p.score))
            })
            .collect())
    }
}
