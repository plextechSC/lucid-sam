#!/usr/bin/env python3
"""
Script to crop distortion borders from camera images.

Camera 02 (PRIMAX-IMX728): 7680x2856 - larger black borders
Camera 05 & 07 (SKE-IMX623): 3840x2472 - similar smaller borders

Other cameras are copied directly without cropping.

Output is saved to a 'cropped' folder mirroring the original structure.
"""

import os
import shutil
import argparse
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor, as_completed


# Crop configurations for each camera type
# For fixed resolution cameras: (left, top, right, bottom) pixel coordinates
# For variable resolution cameras: percentage-based with "type": "percent"
CROP_CONFIGS = {
    # Camera 02 (PRIMAX-IMX728): Variable resolutions (6400x2382, 7680x2856, etc.)
    # Has larger black borders, especially at bottom - uses percentage-based cropping
    "cam02": {
        "type": "percent",
        "left": 7.5,      # ~7.5% from left
        "top": 16.0,      # ~16% from top  
        "right": 93.0,    # ~93% from left (7% from right)
        "bottom": 75.0,   # ~83.5% from top (crop more of bottom distortion)
    },
    # Camera 05 (SKE-IMX623): 3840x2472
    # Smaller, roughly equal borders
    "cam05": {
        "type": "fixed",
        "left": 175,
        "top": 200,
        "right": 3560,
        "bottom": 2260,
    },
    # Camera 07 (SKE-IMX623): 3840x2472
    # Same as Camera 05
    "cam07": {
        "type": "fixed",
        "left": 175,
        "top": 200,
        "right": 3560,
        "bottom": 2260,
    },
}

# Cameras that need cropping (others will be copied directly)
CAMERAS_TO_CROP = ["cam02", "cam05", "cam07"]


def get_crop_box(camera_name: str, img_width: int = None, img_height: int = None) -> tuple:
    """
    Get crop box for a camera, handling both fixed and percentage-based configs.
    
    Args:
        camera_name: Name of the camera (e.g., "cam02")
        img_width: Image width (required for percentage-based configs)
        img_height: Image height (required for percentage-based configs)
        
    Returns:
        Tuple of (left, top, right, bottom) pixel coordinates
    """
    config = CROP_CONFIGS.get(camera_name)
    if not config:
        raise ValueError(f"Unknown camera: {camera_name}")
    
    if config.get("type") == "percent":
        if img_width is None or img_height is None:
            raise ValueError(f"Image dimensions required for percentage-based crop config: {camera_name}")
        left = int(img_width * config["left"] / 100)
        top = int(img_height * config["top"] / 100)
        right = int(img_width * config["right"] / 100)
        bottom = int(img_height * config["bottom"] / 100)
        return (left, top, right, bottom)
    else:
        # Fixed pixel coordinates
        return (config["left"], config["top"], config["right"], config["bottom"])


def crop_image(input_path: Path, output_path: Path, camera_name: str) -> tuple:
    """
    Crop a single image and save to output path.
    
    Args:
        input_path: Path to input image
        output_path: Path to save cropped image
        camera_name: Camera name for crop configuration
        
    Returns:
        Tuple of (input_path, success, message, action) where action is "cropped" or "copied"
    """
    try:
        # Create output directory if needed
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Open, crop, and save
        with Image.open(input_path) as img:
            crop_box = get_crop_box(camera_name, img.width, img.height)
            cropped = img.crop(crop_box)
            cropped.save(output_path, quality=95)
        
        return (input_path, True, f"Cropped to {cropped.size}", "cropped")
    except Exception as e:
        return (input_path, False, str(e), "cropped")


def copy_image(input_path: Path, output_path: Path) -> tuple:
    """
    Copy a single image to output path without modification.
    
    Args:
        input_path: Path to input image
        output_path: Path to save copied image
        
    Returns:
        Tuple of (input_path, success, message, action) where action is "copied"
    """
    try:
        # Create output directory if needed
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Copy the file directly
        shutil.copy2(input_path, output_path)
        
        return (input_path, True, "Copied", "copied")
    except Exception as e:
        return (input_path, False, str(e), "copied")


def process_scenario(data_dir: Path, output_dir: Path, scenario_id: str, 
                     max_workers: int = 4) -> dict:
    """
    Process all cameras in a scenario. Cameras in CAMERAS_TO_CROP are cropped,
    all others are copied directly.
    
    Args:
        data_dir: Base data directory
        output_dir: Base output directory
        scenario_id: Scenario folder name
        max_workers: Number of parallel workers
        
    Returns:
        Dict with processing statistics
    """
    scenario_path = data_dir / scenario_id
    
    if not scenario_path.exists():
        print(f"Scenario not found: {scenario_path}")
        return {"cropped": 0, "copied": 0, "failed": 0}
    
    stats = {"cropped": 0, "copied": 0, "failed": 0}
    crop_tasks = []
    copy_tasks = []
    
    # Find all camera directories in the scenario
    camera_dirs = sorted([d for d in scenario_path.iterdir() if d.is_dir()])
    
    if not camera_dirs:
        print(f"  No camera folders found in {scenario_path}")
        return stats
    
    # Collect all images to process
    for camera_path in camera_dirs:
        camera = camera_path.name
        
        # Find all PNG images
        for img_file in camera_path.glob("*.png"):
            output_path = output_dir / scenario_id / camera / img_file.name
            
            if camera in CAMERAS_TO_CROP:
                crop_tasks.append((img_file, output_path, camera))
            else:
                copy_tasks.append((img_file, output_path))
    
    total_tasks = len(crop_tasks) + len(copy_tasks)
    if total_tasks == 0:
        print(f"  No images found for scenario {scenario_id}")
        return stats
    
    print(f"  Processing {total_tasks} images ({len(crop_tasks)} to crop, {len(copy_tasks)} to copy)...")
    
    # Process images in parallel
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {}
        
        # Submit crop tasks
        for inp, out, cam in crop_tasks:
            futures[executor.submit(crop_image, inp, out, cam)] = inp
        
        # Submit copy tasks
        for inp, out in copy_tasks:
            futures[executor.submit(copy_image, inp, out)] = inp
        
        for future in as_completed(futures):
            input_path, success, message, action = future.result()
            if success:
                if action == "cropped":
                    stats["cropped"] += 1
                else:
                    stats["copied"] += 1
            else:
                stats["failed"] += 1
                print(f"    Failed: {input_path.name} - {message}")
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Crop distortion borders from camera images (cam02, cam05, cam07) and copy others"
    )
    parser.add_argument(
        "--data-dir", 
        type=Path, 
        default=Path("data"),
        help="Input data directory (default: data)"
    )
    parser.add_argument(
        "--output-dir", 
        type=Path, 
        default=Path("cropped"),
        help="Output directory (default: cropped)"
    )
    parser.add_argument(
        "--scenarios", 
        nargs="+",
        help="Specific scenarios to process (default: all)"
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        help="Number of parallel workers (default: 4)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be processed without actually processing"
    )
    
    args = parser.parse_args()
    
    # Validate data directory
    if not args.data_dir.exists():
        print(f"Error: Data directory not found: {args.data_dir}")
        return 1
    
    # Get scenarios to process
    if args.scenarios:
        scenarios = args.scenarios
    else:
        # Find all scenario directories
        scenarios = [
            d.name for d in args.data_dir.iterdir() 
            if d.is_dir() and not d.name.startswith(".")
        ]
    
    if not scenarios:
        print("No scenarios found to process")
        return 1
    
    print(f"Crop configurations (cameras to crop):")
    for cam in CAMERAS_TO_CROP:
        config = CROP_CONFIGS[cam]
        if config.get("type") == "percent":
            w_pct = config["right"] - config["left"]
            h_pct = config["bottom"] - config["top"]
            print(f"  {cam}: {w_pct:.1f}% x {h_pct:.1f}% (percentage-based, variable resolution)")
        else:
            w = config["right"] - config["left"]
            h = config["bottom"] - config["top"]
            print(f"  {cam}: crop to {w}x{h} pixels (fixed)")
    print(f"  Other cameras: copied directly (no cropping)")
    
    print(f"\nProcessing {len(scenarios)} scenario(s): {', '.join(scenarios)}")
    print(f"Output directory: {args.output_dir}")
    
    if args.dry_run:
        print("\n[DRY RUN - no files will be processed]")
        for scenario in scenarios:
            scenario_path = args.data_dir / scenario
            if scenario_path.exists():
                camera_dirs = sorted([d for d in scenario_path.iterdir() if d.is_dir()])
                for camera_path in camera_dirs:
                    camera = camera_path.name
                    count = len(list(camera_path.glob("*.png")))
                    action = "crop" if camera in CAMERAS_TO_CROP else "copy"
                    print(f"  {scenario}/{camera}: {count} images ({action})")
        return 0
    
    print()
    
    # Process each scenario
    total_stats = {"cropped": 0, "copied": 0, "failed": 0}
    
    for scenario in sorted(scenarios):
        print(f"Scenario: {scenario}")
        stats = process_scenario(
            args.data_dir, 
            args.output_dir, 
            scenario,
            args.workers
        )
        for key in total_stats:
            total_stats[key] += stats[key]
    
    # Summary
    print(f"\n{'='*50}")
    print(f"Summary:")
    print(f"  Cropped: {total_stats['cropped']}")
    print(f"  Copied: {total_stats['copied']}")
    print(f"  Total: {total_stats['cropped'] + total_stats['copied']}")
    print(f"  Failed: {total_stats['failed']}")
    print(f"  Output: {args.output_dir.absolute()}")
    
    return 0 if total_stats["failed"] == 0 else 1


if __name__ == "__main__":
    exit(main())
