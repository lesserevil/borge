#!/usr/bin/env python3
"""
Convert image files containing sheet music to MusicXML format.

This is a simpler alternative to pdf2musicxml when you already have
images of sheet music pages.
"""

import argparse
import subprocess
import sys
from pathlib import Path


def run_homr(image_path: Path) -> Path | None:
    """
    Run HOMR optical music recognition on an image.

    Args:
        image_path: Path to the input image

    Returns:
        Path to the generated MusicXML file, or None if failed
    """
    try:
        result = subprocess.run(
            ["homr", str(image_path)],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            print(f"  HOMR failed: {result.stderr}")
            return None

        # HOMR creates .musicxml file with same base name in same directory
        musicxml_path = image_path.with_suffix(".musicxml")
        if musicxml_path.exists():
            return musicxml_path

        print(f"  Warning: HOMR completed but output not found")
        return None

    except FileNotFoundError:
        print("Error: HOMR not found. Install with: pip install homr")
        return None
    except Exception as e:
        print(f"Error running HOMR: {e}")
        return None


def merge_musicxml_files(musicxml_files: list[Path], output_path: Path) -> bool:
    """
    Merge multiple MusicXML files into one using Relieur.
    """
    if len(musicxml_files) == 0:
        return False

    if len(musicxml_files) == 1:
        import shutil

        shutil.copy(musicxml_files[0], output_path)
        return True

    try:
        cmd = ["relieur"] + [str(f) for f in musicxml_files] + ["-o", str(output_path)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0 and output_path.exists()
    except FileNotFoundError:
        print("Error: Relieur not found. Install with: pip install relieur")
        return False
    except Exception as e:
        print(f"Error merging files: {e}")
        return False


def convert_images_to_musicxml(
    image_paths: list[Path],
    output_path: Path,
) -> Path | None:
    """
    Convert multiple images to a single MusicXML file.

    Args:
        image_paths: List of image files (in page order)
        output_path: Output MusicXML file path

    Returns:
        Path to output file, or None if failed
    """
    print(f"Processing {len(image_paths)} images...")

    musicxml_files = []
    for i, image_path in enumerate(image_paths, 1):
        print(f"  [{i}/{len(image_paths)}] {image_path.name}")
        result = run_homr(image_path)
        if result:
            musicxml_files.append(result)

    if not musicxml_files:
        print("Error: No images were successfully processed")
        return None

    print(f"\nProcessed {len(musicxml_files)}/{len(image_paths)} images")

    if len(musicxml_files) > 1:
        print(f"Merging {len(musicxml_files)} MusicXML files...")
        if merge_musicxml_files(musicxml_files, output_path):
            print(f"Output saved to: {output_path}")
            return output_path
        else:
            print("Error: Failed to merge files")
            return None
    else:
        import shutil

        shutil.copy(musicxml_files[0], output_path)
        print(f"Output saved to: {output_path}")
        return output_path


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Convert sheet music images to MusicXML format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  img2musicxml page1.png page2.png page3.png -o score.musicxml
  img2musicxml *.png -o score.musicxml
  img2musicxml --dir ./pages -o score.musicxml
        """,
    )

    parser.add_argument(
        "images",
        type=Path,
        nargs="*",
        help="Input image files (PNG, JPG, etc.)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        required=True,
        help="Output MusicXML file",
    )
    parser.add_argument(
        "--dir",
        type=Path,
        default=None,
        help="Directory containing images (alternative to listing files)",
    )

    args = parser.parse_args()

    if args.dir:
        # Get images from directory
        image_paths = sorted(
            list(args.dir.glob("*.png"))
            + list(args.dir.glob("*.jpg"))
            + list(args.dir.glob("*.jpeg"))
        )
    else:
        image_paths = args.images

    if not image_paths:
        print("Error: No image files specified")
        sys.exit(1)

    # Verify all files exist
    for path in image_paths:
        if not path.exists():
            print(f"Error: File not found: {path}")
            sys.exit(1)

    result = convert_images_to_musicxml(image_paths, args.output)
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
