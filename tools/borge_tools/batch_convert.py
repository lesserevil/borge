#!/usr/bin/env python3
"""
Batch convert multiple PDF files to MusicXML format.

This script processes multiple PDF files, converting each to MusicXML,
and organizes the output in a directory structure suitable for the
Borge sheet music viewer.
"""

import argparse
import sys
from pathlib import Path

from .pdf2musicxml import convert_pdf_to_musicxml


def batch_convert(
    input_dir: Path,
    output_dir: Path,
    dpi: int = 300,
    recursive: bool = False,
) -> tuple[int, int]:
    """
    Convert all PDF files in a directory to MusicXML.

    Args:
        input_dir: Directory containing PDF files
        output_dir: Directory for output MusicXML files
        dpi: Resolution for PDF rendering
        recursive: Search subdirectories recursively

    Returns:
        Tuple of (successful_count, total_count)
    """
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)

    if not input_dir.exists():
        print(f"Error: Input directory not found: {input_dir}")
        return (0, 0)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Find all PDF files
    pattern = "**/*.pdf" if recursive else "*.pdf"
    pdf_files = sorted(input_dir.glob(pattern))

    if not pdf_files:
        print(f"No PDF files found in {input_dir}")
        return (0, 0)

    print(f"Found {len(pdf_files)} PDF files to convert\n")

    successful = 0
    for i, pdf_path in enumerate(pdf_files, 1):
        print(f"\n{'=' * 60}")
        print(f"[{i}/{len(pdf_files)}] {pdf_path.name}")
        print(f"{'=' * 60}")

        # Create corresponding output path
        if recursive:
            # Preserve subdirectory structure
            relative_path = pdf_path.relative_to(input_dir)
            output_path = output_dir / relative_path.with_suffix(".musicxml")
            output_path.parent.mkdir(parents=True, exist_ok=True)
        else:
            output_path = output_dir / pdf_path.with_suffix(".musicxml").name

        result = convert_pdf_to_musicxml(pdf_path, output_path, dpi)
        if result:
            successful += 1

    return (successful, len(pdf_files))


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Batch convert PDF sheet music files to MusicXML format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  batch-convert ./pdfs ./musicxml
  batch-convert ./pdfs ./musicxml --recursive
  batch-convert ./pdfs ./musicxml --dpi 400
        """,
    )

    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory containing PDF files",
    )
    parser.add_argument(
        "output_dir",
        type=Path,
        help="Directory for output MusicXML files",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="DPI for PDF rendering (default: 300)",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="Search subdirectories recursively",
    )

    args = parser.parse_args()

    successful, total = batch_convert(
        args.input_dir,
        args.output_dir,
        args.dpi,
        args.recursive,
    )

    print(f"\n{'=' * 60}")
    print(f"Conversion complete: {successful}/{total} files successful")
    print(f"{'=' * 60}")

    sys.exit(0 if successful == total else 1)


if __name__ == "__main__":
    main()
