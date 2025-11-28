import os
from pathlib import Path
from sam import process_image_with_sam
from models import SAM2Model

# Input and output directories
INPUT_DIR = "input_images"
OUTPUT_DIR = "output"

# Model to use
MODEL = SAM2Model.LARGE

# Max dimension for downsampling (None = full resolution, or set e.g. 2048 for local testing)
MAX_DIMENSION = None


def process_all_images():
    """
    Process all numbered images in input_images/ and output masks to output/[image_number]/.
    
    Input format: 000000.png, 000001.png, etc. (6-digit numbered)
    Output format: output/000000/000.png, output/000000/001.png, etc. (3-digit mask names)
    """
    input_path = Path(INPUT_DIR)
    output_path = Path(OUTPUT_DIR)
    
    if not input_path.exists():
        print(f"Error: Input directory '{INPUT_DIR}' does not exist.")
        return
    
    # Get all PNG files and sort them
    image_files = sorted(input_path.glob("*.png"))
    
    if not image_files:
        print(f"No PNG files found in '{INPUT_DIR}' directory.")
        return
    
    print(f"Found {len(image_files)} image(s) to process.")
    print(f"Using model: {MODEL.name}")
    print("-" * 60)
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Track statistics
    processed_count = 0
    failed_count = 0
    total_masks = 0
    
    for image_file in image_files:
        # Get the image number (filename without extension)
        image_number = image_file.stem  # e.g., "000000"
        
        print(f"\nProcessing: {image_file.name}")
        
        # Create output directory for this image: output/[image_number]/
        masks_dir = output_path / image_number
        masks_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            # Process the image
            masks = process_image_with_sam(
                image_path=str(image_file),
                selected_model=MODEL,
                visualize=False,
                output_masks=True,
                visualization_output_path=None,
                output_masks_dir=str(masks_dir),
                mask_name_digits=3,  # Use 3-digit mask names (000.png, 001.png)
                mask_start_index=0,  # Start from 0
                max_dimension=MAX_DIMENSION
            )
            
            num_masks = len(masks)
            total_masks += num_masks
            print(f"  ✓ Generated {num_masks} masks -> {masks_dir}/")
            processed_count += 1
            
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            failed_count += 1
            continue
    
    # Summary
    print("\n" + "=" * 60)
    print("Processing complete!")
    print(f"  Successfully processed: {processed_count} images")
    print(f"  Failed: {failed_count} images")
    print(f"  Total masks generated: {total_masks}")
    if processed_count > 0:
        print(f"  Average masks per image: {total_masks / processed_count:.1f}")


if __name__ == "__main__":
    process_all_images()
