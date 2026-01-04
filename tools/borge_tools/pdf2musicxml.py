#!/usr/bin/env python3
"""
Convert a PDF file containing sheet music to MusicXML format.

Pipeline:
1. Extract images from PDF pages using PyMuPDF
2. Run HOMR optical music recognition on each page image
3. Merge resulting MusicXML files using Relieur
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None


def extract_pdf_pages(pdf_path: Path, output_dir: Path, dpi: int = 300) -> list[Path]:
    """
    Extract each page of a PDF as a high-resolution PNG image.

    Args:
        pdf_path: Path to the input PDF file
        output_dir: Directory to save extracted images
        dpi: Resolution for rendered images (default 300)

    Returns:
        List of paths to extracted image files
    """
    if fitz is None:
        raise ImportError("PyMuPDF is required. Install with: pip install pymupdf")

    doc = fitz.open(pdf_path)
    image_paths = []

    # Calculate zoom factor for desired DPI (PyMuPDF default is 72 DPI)
    zoom = dpi / 72
    matrix = fitz.Matrix(zoom, zoom)

    for page_num in range(len(doc)):
        page = doc[page_num]
        pix = page.get_pixmap(matrix=matrix)

        image_path = output_dir / f"page_{page_num + 1:03d}.png"
        pix.save(str(image_path))
        image_paths.append(image_path)
        print(f"  Extracted page {page_num + 1}/{len(doc)}: {image_path.name}")

    doc.close()
    return image_paths


def run_homr(image_path: Path, output_dir: Path) -> Path | None:
    """
    Run HOMR optical music recognition on an image.

    Args:
        image_path: Path to the input image
        output_dir: Directory for output MusicXML file

    Returns:
        Path to the generated MusicXML file, or None if failed
    """
    try:
        # HOMR outputs to the same directory as the input by default
        # We'll run it and then move/find the output
        result = subprocess.run(
            ["homr", str(image_path)],
            capture_output=True,
            text=True,
            cwd=str(output_dir),
        )

        if result.returncode != 0:
            print(f"  HOMR failed for {image_path.name}: {result.stderr}")
            return None

        # HOMR creates .musicxml file with same base name
        musicxml_path = image_path.with_suffix(".musicxml")
        if musicxml_path.exists():
            return musicxml_path

        # Check in output directory
        alt_path = output_dir / f"{image_path.stem}.musicxml"
        if alt_path.exists():
            return alt_path

        print(f"  Warning: HOMR completed but output not found for {image_path.name}")
        return None

    except FileNotFoundError:
        print("  Error: HOMR not found. Install with: pip install homr")
        return None
    except Exception as e:
        print(f"  Error running HOMR on {image_path.name}: {e}")
        return None


def merge_musicxml_files(musicxml_files: list[Path], output_path: Path) -> bool:
    """
    Merge multiple MusicXML files into one using Relieur.

    Args:
        musicxml_files: List of MusicXML files to merge (in order)
        output_path: Path for the merged output file

    Returns:
        True if successful, False otherwise
    """
    if len(musicxml_files) == 0:
        print("  No MusicXML files to merge")
        return False

    if len(musicxml_files) == 1:
        # Just copy the single file
        import shutil

        shutil.copy(musicxml_files[0], output_path)
        return True

    try:
        # Relieur takes files as positional arguments and -o for output
        cmd = ["relieur"] + [str(f) for f in musicxml_files] + ["-o", str(output_path)]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"  Relieur failed: {result.stderr}")
            return False

        return output_path.exists()

    except FileNotFoundError:
        print("  Error: Relieur not found. Install with: pip install relieur")
        return False
    except Exception as e:
        print(f"  Error merging MusicXML files: {e}")
        return False


def convert_pdf_to_musicxml(
    pdf_path: Path,
    output_path: Path | None = None,
    dpi: int = 300,
    keep_intermediate: bool = False,
) -> Path | None:
    """
    Convert a PDF containing sheet music to MusicXML.

    Args:
        pdf_path: Path to the input PDF file
        output_path: Path for output MusicXML (default: same as PDF with .musicxml extension)
        dpi: Resolution for PDF rendering (default 300)
        keep_intermediate: Keep intermediate files (page images and individual MusicXML)

    Returns:
        Path to the output MusicXML file, or None if conversion failed
    """
    pdf_path = Path(pdf_path)

    if not pdf_path.exists():
        print(f"Error: PDF file not found: {pdf_path}")
        return None

    if output_path is None:
        output_path = pdf_path.with_suffix(".musicxml")
    else:
        output_path = Path(output_path)

    print(f"Converting: {pdf_path.name}")
    print(f"Output: {output_path}")

    # Create temporary directory for intermediate files
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        if keep_intermediate:
            # Use a directory next to the PDF
            temp_path = pdf_path.parent / f"{pdf_path.stem}_intermediate"
            temp_path.mkdir(exist_ok=True)

        # Step 1: Extract PDF pages as images
        print("\nStep 1: Extracting PDF pages...")
        try:
            image_paths = extract_pdf_pages(pdf_path, temp_path, dpi)
        except Exception as e:
            print(f"Error extracting PDF pages: {e}")
            return None

        if not image_paths:
            print("Error: No pages extracted from PDF")
            return None

        # Step 2: Run HOMR on each page
        print("\nStep 2: Running optical music recognition...")
        musicxml_files = []
        for image_path in image_paths:
            print(f"  Processing {image_path.name}...")
            musicxml_path = run_homr(image_path, temp_path)
            if musicxml_path:
                musicxml_files.append(musicxml_path)

        if not musicxml_files:
            print("Error: HOMR failed to process any pages")
            return None

        print(f"\n  Successfully processed {len(musicxml_files)}/{len(image_paths)} pages")

        # Step 3: Merge MusicXML files
        print("\nStep 3: Merging MusicXML files...")
        if merge_musicxml_files(musicxml_files, output_path):
            print(f"\nSuccess! Output saved to: {output_path}")
            return output_path
        else:
            print("\nError: Failed to merge MusicXML files")
            return None


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Convert PDF sheet music to MusicXML format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  pdf2musicxml score.pdf
  pdf2musicxml score.pdf -o output.musicxml
  pdf2musicxml score.pdf --dpi 400 --keep-intermediate
        """,
    )

    parser.add_argument(
        "pdf",
        type=Path,
        help="Input PDF file containing sheet music",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output MusicXML file (default: same name as PDF with .musicxml extension)",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="DPI for PDF rendering (default: 300)",
    )
    parser.add_argument(
        "--keep-intermediate",
        action="store_true",
        help="Keep intermediate files (page images and per-page MusicXML)",
    )

    args = parser.parse_args()

    result = convert_pdf_to_musicxml(
        args.pdf,
        args.output,
        args.dpi,
        args.keep_intermediate,
    )

    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
