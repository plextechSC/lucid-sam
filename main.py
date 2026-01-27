import os
from pathlib import Path
from sam import process_image_with_sam
from models import SAMModel

# Input and output directories
INPUT_DIR = "cropped"
OUTPUT_DIR = "output"

# Model to use
MODEL = SAMModel.VIT_H

# Max dimension for downsampling (None = full resolution, or set e.g. 2048 for local testing)
MAX_DIMENSION = None


def process_all_images():
    """
    Process all numbered images in input_images/ with nested folder structure.
    
    Input structure:
        input_images/
            {scene_id}/           # e.g., 7PpL05, ffea0d
                {camera}/         # e.g., camera_0, camera_1
                    000000.png, 000001.png, ...
    
    Output structure:
        output/
            {scene_id}/
                {camera}/
                    {frame}/      # e.g., 000000, 000001
                        000.png, 001.png, ... (masks)
    """
    input_path = Path(INPUT_DIR)
    output_path = Path(OUTPUT_DIR)
    
    if not input_path.exists():
        print(f"Error: Input directory '{INPUT_DIR}' does not exist.")
        return
    
    # Get all top-level subdirectories (scene IDs like 7PpL05, ffea0d)
    scene_dirs = sorted([d for d in input_path.iterdir() if d.is_dir()])
    
    if not scene_dirs:
        print(f"No scene subdirectories found in '{INPUT_DIR}'.")
        return
    
    print(f"Found {len(scene_dirs)} scene(s) to process: {[d.name for d in scene_dirs]}")
    print(f"Using model: {MODEL.name}")
    print("=" * 60)
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Track statistics
    total_processed = 0
    total_failed = 0
    total_masks = 0
    
    for scene_dir in scene_dirs:
        scene_id = scene_dir.name
        print(f"\n{'='*60}")
        print(f"Processing scene: {scene_id}")
        print(f"{'='*60}")
        
        # Get all camera subdirectories
        camera_dirs = sorted([d for d in scene_dir.iterdir() if d.is_dir()])
        
        if not camera_dirs:
            print(f"  No camera subdirectories found in '{scene_dir}'.")
            continue
        
        print(f"  Found {len(camera_dirs)} camera(s): {[d.name for d in camera_dirs]}")
        
        for camera_dir in camera_dirs:
            camera_name = camera_dir.name
            print(f"\n  Camera: {camera_name}")
            print(f"  {'-'*50}")
            
            # Get all PNG files in this camera directory
            image_files = sorted(camera_dir.glob("*.png"))
            
            if not image_files:
                print(f"    No PNG files found in '{camera_dir}'.")
                continue
            
            print(f"    Found {len(image_files)} image(s)")
            
            # Process each image
            camera_processed = 0
            camera_failed = 0
            camera_masks = 0
            
            for image_file in image_files:
                # Get the frame number (filename without extension)
                frame_number = image_file.stem  # e.g., "000000"
                
                print(f"    Processing: {image_file.name}")
                
                # Create output directory: output/{scene_id}/{camera}/{frame}/
                masks_dir = output_path / scene_id / camera_name / frame_number
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
                    camera_masks += num_masks
                    print(f"      ✓ Generated {num_masks} masks -> {masks_dir}/")
                    camera_processed += 1
                    
                except Exception as e:
                    print(f"      ✗ Error: {str(e)}")
                    camera_failed += 1
                    continue
            
            # Camera summary
            print(f"\n    Camera '{camera_name}' summary:")
            print(f"      Processed: {camera_processed}, Failed: {camera_failed}, Masks: {camera_masks}")
            
            total_processed += camera_processed
            total_failed += camera_failed
            total_masks += camera_masks
    
    # Final summary
    print("\n" + "=" * 60)
    print("All processing complete!")
    print(f"  Total images processed: {total_processed}")
    print(f"  Total failed: {total_failed}")
    print(f"  Total masks generated: {total_masks}")
    if total_processed > 0:
        print(f"  Average masks per image: {total_masks / total_processed:.1f}")


if __name__ == "__main__":
    process_all_images()
