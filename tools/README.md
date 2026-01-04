# Borge Tools

PDF to MusicXML conversion tools for the Borge sheet music viewer.

## Overview

This toolset provides a pipeline to convert PDF sheet music files into MusicXML format:

1. **PyMuPDF** - Extract high-resolution images from PDF pages
2. **HOMR** - Optical Music Recognition to convert images to MusicXML
3. **Relieur** - Merge multiple MusicXML files into a single file

## Installation

### Prerequisites

- Python 3.10 or later
- [uv](https://github.com/astral-sh/uv) (recommended) or pip

### Quick Install (CPU only)

```bash
cd tools

# Using uv (recommended)
uv venv
source .venv/bin/activate
uv pip install -e ".[cpu]"

# Or using pip
python -m venv .venv
source .venv/bin/activate
pip install -e ".[cpu]"
```

### GPU Install (requires CUDA 12.1)

```bash
cd tools
uv venv
source .venv/bin/activate
uv pip install -e ".[gpu]"
```

### Install HOMR separately (if needed)

HOMR has large model dependencies. If the above fails, install it separately:

```bash
# CPU version
pip install homr

# GPU version (requires CUDA)
pip install "homr[gpu]"
```

## Usage

### Convert a single PDF

```bash
pdf2musicxml score.pdf
# Output: score.musicxml

pdf2musicxml score.pdf -o output.musicxml
# Output: output.musicxml

pdf2musicxml score.pdf --dpi 400 --keep-intermediate
# Higher quality, keeps intermediate files
```

### Batch convert multiple PDFs

```bash
batch-convert ./input_pdfs ./output_musicxml

batch-convert ./input_pdfs ./output_musicxml --recursive
# Process subdirectories

batch-convert ./input_pdfs ./output_musicxml --dpi 400
# Higher quality rendering
```

### Use as a library

```python
from borge_tools.pdf2musicxml import convert_pdf_to_musicxml

# Convert a single PDF
result = convert_pdf_to_musicxml("score.pdf", "output.musicxml")

# With options
result = convert_pdf_to_musicxml(
    "score.pdf",
    "output.musicxml",
    dpi=400,
    keep_intermediate=True,
)
```

## Pipeline Details

### Step 1: PDF to Images (PyMuPDF)

Each page of the PDF is rendered as a high-resolution PNG image. Default DPI is 300, which provides a good balance between quality and processing speed. Higher DPI (e.g., 400) may improve recognition accuracy for complex scores.

### Step 2: Optical Music Recognition (HOMR)

[HOMR](https://github.com/liebharc/homr) is an Optical Music Recognition system that converts images of sheet music into MusicXML format. It uses:

- Segmentation models to identify staff lines, clefs, notes, etc.
- Transformer models to recognize musical symbols
- Post-processing to generate valid MusicXML

**Limitations:**
- Works best with clean, high-contrast images
- Focuses on pitch and rhythm (may miss dynamics, articulations)
- Supports treble and bass clef
- May have errors with complex scores

### Step 3: MusicXML Merging (Relieur)

[Relieur](https://github.com/papoteur-mga/relieur) merges multiple MusicXML files into a single file. It:

- Combines measures from each page sequentially
- Removes duplicate key signatures and clefs at page breaks
- Maintains part structure across pages

## Tips for Best Results

1. **Source Quality**: Start with high-quality PDF scans
2. **DPI Setting**: Use 300-400 DPI for best results
3. **Review Output**: Always review the MusicXML output in a notation program like MuseScore
4. **Manual Corrections**: Some manual cleanup may be needed, especially for:
   - Complex rhythms
   - Multiple voices
   - Ornaments and articulations
   - Lyrics

## Troubleshooting

### HOMR not found

```bash
pip install homr  # or homr[gpu] for GPU support
```

### PyMuPDF import error

```bash
pip install pymupdf
```

### Relieur not found

```bash
pip install relieur
```

### CUDA errors (GPU version)

Make sure you have CUDA 12.1 installed and compatible GPU drivers.

### Out of memory (GPU)

Try processing one page at a time, or use CPU version.

## Dependencies

- [PyMuPDF](https://pymupdf.readthedocs.io/) - PDF rendering and manipulation
- [HOMR](https://github.com/liebharc/homr) - Optical Music Recognition
- [Relieur](https://github.com/papoteur-mga/relieur) - MusicXML file merging

## License

MIT License - see the main project LICENSE file.
