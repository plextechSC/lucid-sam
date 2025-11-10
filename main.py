import os
from pathlib import Path
from sam import process_image_with_sam
from models import SAM2Model

# Input directory
INPUT_DIR = "input_images"

# All available models to test
MODELS = [SAM2Model.TINY, SAM2Model.LARGE]

def parse_image_filename(filename):
    """
    Parse image filename to extract session ID, camera ID, and unique photo ID.
    
    Format: [session id]-cam-[camera id #]-[camera make]-[camera model]-[timestamp data]-[unique photo id].png
    
    Args:
        filename: Image filename (e.g., "qbR80f-cam-02-PRIMAX-IMX728-20250526_200138-000003.png")
    
    Returns:
        dict with keys: session_id, camera_id, unique_photo_id, or None if parsing fails
    """
    # Remove extension
    name_without_ext = os.path.splitext(filename)[0]
    
    # Pattern: session_id-cam-camera_id-camera_make-camera_model-timestamp-unique_photo_id
    # The unique photo id is the last part after the last hyphen
    parts = name_without_ext.split('-')
    
    if len(parts) < 7:
        print(f"Warning: Could not parse filename {filename}. Expected at least 7 parts separated by '-', got {len(parts)}")
        return None
    
    # session_id is the first part
    session_id = parts[0]
    
    # camera_id should be after "cam-"
    if parts[1] != 'cam':
        print(f"Warning: Expected 'cam' at position 1 in {filename}, got '{parts[1]}'")
        return None
    
    camera_id = parts[2]
    
    # unique_photo_id is the last part
    unique_photo_id = parts[-1]
    
    return {
        'session_id': session_id,
        'camera_id': camera_id,
        'unique_photo_id': unique_photo_id,
        'full_filename': filename
    }


def process_all_images():
    """
    Process all images in the input_images folder with all SAM2 models.
    """
    input_path = Path(INPUT_DIR)
    
    if not input_path.exists():
        print(f"Error: Input directory '{INPUT_DIR}' does not exist.")
        return
    
    # Get all PNG files
    image_files = list(input_path.glob("*.png"))
    
    if not image_files:
        print(f"No PNG files found in '{INPUT_DIR}' directory.")
        return
    
    print(f"Found {len(image_files)} image(s) to process.")
    print(f"Testing with {len(MODELS)} model(s): {[model.name for model in MODELS]}")
    print("-" * 80)
    
    # Track statistics
    processed_count = 0
    failed_count = 0
    
    # Track mask counts per model for calculating averages
    # Structure: {session_id: {model_name: [mask_count1, mask_count2, ...]}}
    session_mask_counts = {}
    
    # Parse all images first to get session info
    parsed_images = []
    for image_file in sorted(image_files):
        filename = image_file.name
        image_path = str(image_file)
        
        parsed = parse_image_filename(filename)
        if parsed is None:
            print(f"Skipping {filename} due to parsing error.")
            failed_count += 1
            continue
        
        parsed['image_path'] = image_path
        parsed_images.append(parsed)
        
        # Initialize session tracking if not exists
        session_id = parsed['session_id']
        if session_id not in session_mask_counts:
            session_mask_counts[session_id] = {m.name.lower(): [] for m in MODELS}
    
    # Process each model, then all images with that model
    for model in MODELS:
        model_name = model.name.lower()
        print(f"\n{'='*80}")
        print(f"Processing with {model.name} model...")
        print(f"{'='*80}")
        
        # Process all images with this model
        for parsed in parsed_images:
            filename = parsed['full_filename']
            image_path = parsed['image_path']
            session_id = parsed['session_id']
            camera_id = parsed['camera_id']
            unique_photo_id = parsed['unique_photo_id']
            
            print(f"\nProcessing: {filename}")
            print(f"  Session ID: {session_id}")
            print(f"  Camera ID: {camera_id}")
            print(f"  Photo ID: {unique_photo_id}")
            
            # Create output directory structure: output-[session_id]/[model]/[camera_id]/
            # Format: output-[session_id]/[model]/[camera_id]/[unique_photo_id]_visualization.png
            output_dir = Path(f"output-{session_id}") / model_name / camera_id
            output_dir.mkdir(parents=True, exist_ok=True)
            
            # Output filename: [unique_photo_id]_visualization.png
            output_filename = f"{unique_photo_id}_visualization.png"
            visualization_output_path = str(output_dir / output_filename)
            
            print(f"    Output: {visualization_output_path}")
            
            try:
                # Process the image
                masks = process_image_with_sam(
                    image_path=image_path,
                    selected_model=model,
                    visualize=False,  # Don't display, just save
                    output_masks=False,  # Don't save individual masks
                    visualization_output_path=visualization_output_path,
                    max_dimension=2048
                )
                
                num_masks = len(masks)
                print(f"    ✓ Generated {num_masks} masks")
                
                # Track mask count for this session and model
                session_mask_counts[session_id][model_name].append(num_masks)
                
                processed_count += 1
                
            except Exception as e:
                print(f"    ✗ Error processing with {model.name}: {str(e)}")
                failed_count += 1
                continue
    
    # Calculate and write averages for each session
    print("\n" + "=" * 80)
    print("Calculating averages...")
    
    for session_id, model_counts in session_mask_counts.items():
        session_output_dir = Path(f"output-{session_id}")
        avg_file_path = session_output_dir / "avg.txt"
        
        # Calculate average for each model
        averages = {}
        for model_name, mask_counts in model_counts.items():
            if len(mask_counts) > 0:
                avg = sum(mask_counts) / len(mask_counts)
                averages[model_name] = avg
            else:
                averages[model_name] = 0.0
        
        # Calculate total unique images (should be same for all models if no failures)
        total_images = max(len(counts) for counts in model_counts.values()) if model_counts else 0
        
        # Calculate overall average across all models
        all_mask_counts = [count for counts in model_counts.values() for count in counts]
        overall_avg = sum(all_mask_counts) / len(all_mask_counts) if all_mask_counts else 0.0
        
        # Write averages to file
        with open(avg_file_path, 'w') as f:
            f.write(f"Average number of masks per image for session: {session_id}\n")
            f.write(f"Total images processed: {total_images}\n")
            f.write(f"Overall average (across all models): {overall_avg:.2f} masks\n")
            f.write("-" * 60 + "\n")
            f.write("Per-model averages:\n")
            for model_name in sorted(averages.keys()):
                avg = averages[model_name]
                count = len(model_counts[model_name])
                f.write(f"  {model_name.upper()}: {avg:.2f} masks (from {count} images)\n")
        
        print(f"  Session {session_id}: Averages written to {avg_file_path}")
        print(f"    Overall average: {overall_avg:.2f} masks (across all models and {total_images} images)")
        for model_name in sorted(averages.keys()):
            avg = averages[model_name]
            count = len(model_counts[model_name])
            print(f"    {model_name.upper()}: {avg:.2f} masks (from {count} images)")
    
    print("\n" + "=" * 80)
    print("Processing complete!")
    print(f"  Successfully processed: {processed_count} image-model combinations")
    print(f"  Failed: {failed_count} image-model combinations")


if __name__ == "__main__":
    process_all_images()

