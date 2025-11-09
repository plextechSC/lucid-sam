import torch
from sam2.automatic_mask_generator import SAM2AutomaticMaskGenerator
from sam2.build_sam import build_sam2
from sam2.utils.amg import rle_to_mask
import cv2
import numpy as np
from pycocotools import mask as mask_utils
import os
from models import SAM2Model


def show_anns(anns, image, output_path="mask_visualization.png", borders=True, display=True):
    """
    Create and optionally display masks on the image using OpenCV.
    
    Args:
        anns: List of mask dictionaries from SAM2AutomaticMaskGenerator
        image: The original image (numpy array in RGB format)
        output_path: Path where to save the visualization
        borders: Whether to draw borders around masks
        display: Whether to display the visualization window (default: True)
    """
    if len(anns) == 0:
        print("No masks to visualize - saving image with no masks annotation")
        # Still create and save an image even with no masks
        image_bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        overlay_with_text = image_bgr.copy()
        
        # Add text indicating no masks were found
        text = 'Found 0 masks'
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = 1.0
        thickness = 2
        (text_width, text_height), baseline = cv2.getTextSize(text, font, font_scale, thickness)
        
        # Draw a semi-transparent rectangle for text background
        overlay = overlay_with_text.copy()
        cv2.rectangle(overlay, (10, 10), (20 + text_width, 40 + text_height), (0, 0, 0), -1)
        overlay_with_text = cv2.addWeighted(overlay, 0.7, overlay_with_text, 0.3, 0)
        cv2.putText(overlay_with_text, text, (15, 35), font, font_scale, (255, 255, 255), thickness)
        
        # Save the visualization
        os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else '.', exist_ok=True)
        cv2.imwrite(output_path, overlay_with_text)
        print(f"Visualization saved to {output_path}")
        
        # Display only if requested
        if display:
            display_h, display_w = overlay_with_text.shape[:2]
            max_display_size = 1200
            if max(display_h, display_w) > max_display_size:
                scale = max_display_size / max(display_h, display_w)
                display_w = int(display_w * scale)
                display_h = int(display_h * scale)
                display_image = cv2.resize(overlay_with_text, (display_w, display_h))
            else:
                display_image = overlay_with_text
            
            cv2.imshow('SAM2 Mask Visualization', display_image)
            print(f"Displaying visualization. Press any key to close.")
            cv2.waitKey(0)
            cv2.destroyAllWindows()
        
        return
    
    # Convert image from RGB to BGR for OpenCV
    image_bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    h, w = image_bgr.shape[:2]
    
    # Create an overlay image
    overlay = image_bgr.copy()
    
    # Generate distinct colors for each mask (BGR format for OpenCV)
    # Use a color palette similar to matplotlib's tab20
    def generate_colors(n):
        """Generate n distinct colors in BGR format"""
        colors = []
        # Predefined color palette (converted from RGB to BGR)
        palette = [
            (31, 119, 180),   # Blue
            (255, 127, 14),    # Orange
            (44, 160, 44),     # Green
            (214, 39, 40),     # Red
            (148, 103, 189),   # Purple
            (140, 86, 75),     # Brown
            (227, 119, 194),   # Pink
            (127, 127, 127),   # Gray
            (188, 189, 34),    # Olive
            (23, 190, 207),    # Cyan
            (174, 199, 232),   # Light Blue
            (255, 187, 120),   # Light Orange
            (152, 223, 138),   # Light Green
            (255, 152, 150),   # Light Red
            (197, 176, 213),   # Light Purple
            (196, 156, 148),   # Light Brown
            (247, 182, 210),   # Light Pink
            (199, 199, 199),   # Light Gray
            (219, 219, 141),   # Light Olive
            (158, 218, 229),   # Light Cyan
        ]
        for i in range(n):
            color_idx = i % len(palette)
            # Convert RGB to BGR for OpenCV
            r, g, b = palette[color_idx]
            colors.append((b, g, r))
        return colors
    
    # Sort masks by area (largest first)
    sorted_anns = sorted(anns, key=lambda x: x.get('area', 0), reverse=True)
    colors = generate_colors(len(sorted_anns))
    
    contour_thickness = max(1, int(min(5, 0.01 * min(h, w))))
    
    for i, ann in enumerate(sorted_anns):
        # Decode mask based on output format
        if isinstance(ann['segmentation'], dict):
            # coco_rle or uncompressed_rle format - decode it
            rle = ann['segmentation']
            if 'size' in rle and 'counts' in rle:
                # COCO RLE format - decode directly
                mask = mask_utils.decode(rle)
            else:
                # Uncompressed RLE format (internal format)
                # This shouldn't happen with coco_rle output_mode, but handle it just in case
                mask = rle_to_mask(rle)
        else:
            # binary_mask format - use directly
            mask = ann['segmentation'].astype(np.uint8)
        
        # Get color for this mask
        color = colors[i % len(colors)]
        
        # Create a colored mask overlay
        mask_bool = mask.astype(bool)
        colored_mask = np.zeros((h, w, 3), dtype=np.uint8)
        colored_mask[mask_bool] = color
        
        # Blend the colored mask with the overlay using alpha blending
        alpha = 0.5
        overlay = cv2.addWeighted(overlay, 1.0, colored_mask, alpha, 0)
        
        # Draw borders if requested
        if borders:
            contours, _ = cv2.findContours(
                mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_NONE
            )
            cv2.drawContours(
                overlay, contours, -1, (13, 13, 13), thickness=contour_thickness
            )
    
    # Add text with mask count
    text = f'Found {len(anns)} masks'
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 1.0
    thickness = 2
    (text_width, text_height), baseline = cv2.getTextSize(text, font, font_scale, thickness)
    
    # Draw a semi-transparent rectangle for text background
    overlay_with_text = overlay.copy()
    cv2.rectangle(overlay_with_text, (10, 10), (20 + text_width, 40 + text_height), (0, 0, 0), -1)
    overlay_with_text = cv2.addWeighted(overlay_with_text, 0.7, overlay, 0.3, 0)
    cv2.putText(overlay_with_text, text, (15, 35), font, font_scale, (255, 255, 255), thickness)
    
    # Save the visualization
    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else '.', exist_ok=True)
    cv2.imwrite(output_path, overlay_with_text)
    print(f"Visualization saved to {output_path}")

    # Display the result only if requested
    if display:
        # Resize for display if too large
        display_h, display_w = overlay_with_text.shape[:2]
        max_display_size = 1200
        if max(display_h, display_w) > max_display_size:
            scale = max_display_size / max(display_h, display_w)
            display_w = int(display_w * scale)
            display_h = int(display_h * scale)
            display_image = cv2.resize(overlay_with_text, (display_w, display_h))
        else:
            display_image = overlay_with_text
        
        cv2.imshow('SAM2 Mask Visualization', display_image)
        print(f"Displaying visualization with {len(anns)} masks. Press any key to close.")
        cv2.waitKey(0)
        cv2.destroyAllWindows()


def process_image_with_sam(
    image_path,
    selected_model,
    visualize=False,
    output_masks=False,
    visualization_output_path="mask_visualization.png",
    max_dimension=2048,
    output_masks_dir="masks"
):
    """
    Process an image with SAM2 model to generate masks.
    
    Args:
        image_path: Path to the input image
        selected_model: SAM2Model enum value (e.g., SAM2Model.LARGE)
        visualize: Whether to create and display a visualization (default: False)
        output_masks: Whether to save individual masks to a folder (default: False)
        visualization_output_path: Path where to save the visualization (default: "mask_visualization.png")
        max_dimension: Maximum dimension for image processing (default: 2048)
        output_masks_dir: Directory where to save individual masks if output_masks is True (default: "masks")
    
    Returns:
        List of mask dictionaries from SAM2AutomaticMaskGenerator
    """
    # Check for available device: prefer CUDA (NVIDIA GPU), then MPS (Apple Silicon), then CPU
    if torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"Using device: {device} (NVIDIA GPU detected)")
    elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        device = torch.device("mps")
        print(f"Using device: {device} (Apple Silicon GPU detected)")
    else:
        device = torch.device("cpu")
        print(f"Using device: {device} (no GPU acceleration available)")
    
    sam2_checkpoint = selected_model.checkpoint_path
    model_cfg = selected_model.config_path
    
    # Build the SAM2 model
    sam_model = build_sam2(model_cfg, sam2_checkpoint, device=device)
    
    # Load and process your image
    image = cv2.imread(image_path)
    if image is None:
        raise FileNotFoundError(
            f"Failed to read image at '{image_path}'. Ensure the file exists and the path is correct."
        )
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    
    # Resize image if it's too large to avoid memory issues
    h, w = image_rgb.shape[:2]
    if max(h, w) > max_dimension:
        scale = max_dimension / max(h, w)
        new_w = int(w * scale)
        new_h = int(h * scale)
        image_rgb = cv2.resize(image_rgb, (new_w, new_h), interpolation=cv2.INTER_AREA)
        print(f"Resized image from {w}x{h} to {new_w}x{new_h}")
    
    # Use coco_rle output mode for memory efficiency with large images
    mask_generator = SAM2AutomaticMaskGenerator(sam_model, output_mode="coco_rle")
    
    print("Generating masks...")
    masks = mask_generator.generate(image_rgb)
    print(f"Found {len(masks)} masks.")
    
    # Save individual masks if requested
    if output_masks:
        os.makedirs(output_masks_dir, exist_ok=True)
        
        num_masks = len(masks)
        num_digits = max(4, len(str(max(1, num_masks))))
        
        for idx, ann in enumerate(masks, start=1):
            # Decode mask based on output format
            if isinstance(ann['segmentation'], dict):
                rle = ann['segmentation']
                if 'size' in rle and 'counts' in rle:
                    mask = mask_utils.decode(rle)
                else:
                    mask = rle_to_mask(rle)
            else:
                mask = ann['segmentation'].astype(np.uint8)
            
            # Ensure mask is 2D uint8 {0,255}
            mask_uint8 = (mask.astype(np.uint8) * 255) if mask.max() <= 1 else (mask > 0).astype(np.uint8) * 255
            
            filename = f"mask_{idx:0{num_digits}d}.png"
            out_path = os.path.join(output_masks_dir, filename)
            cv2.imwrite(out_path, mask_uint8)
        
        print(f"Saved {len(masks)} masks to {output_masks_dir}/")
    
    # Always create and save visualization if output path is provided
    # Only display it if visualize=True
    if visualization_output_path:
        show_anns(masks, image_rgb, output_path=visualization_output_path, display=visualize)
    
    return masks


# if __name__ == "__main__":
#     # Example usage
#     image_path = "./input.png"
#     selected_model = SAM2Model.LARGE
    
#     masks = process_image_with_sam(
#         image_path=image_path,
#         selected_model=selected_model,
#         visualize=False,
#         output_masks=False,
#         visualization_output_path="mask_visualization.png"
#     )