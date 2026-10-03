# CSCR OCT Analyzer

## Overview
This repository contains a MATLAB-based image processing pipeline for analyzing Optical Coherence Tomography (OCT) retinal scans. The project leverages the **Segment Anything Model (SAM)** alongside traditional computer vision techniques to automatically align images, segment critical retinal layers, detect macular holes, and extract statistical data from specific Regions of Interest (ROIs).

## Key Features
*   **Automated Pre-processing:** Resizes, filters, and flattens OCT scans to correct for tilt and curvature, padding missing areas with synthetic noise to preserve image statistics.
*   **SAM Integration:** Uses the Segment Anything Model (SAM) for robust extraction of retinal boundaries and features via targeted embeddings.
*   **Macular Hole Detection:** Automatically detects the presence, size, and boundaries of macular holes using morphological stretching and intensity thresholding.
*   **Layer Segmentation:** Precisely identifies and maps multiple layers, including:
    *   Inner Limiting Membrane (ILM)
    *   Inner Retinal Layers (divided into sub-tracks)
    *   Retinal Pigment Epithelium (RPE) - Top and Bottom boundaries
*   **ROI Statistical Analysis:** Dynamically splits the scan into targeted ROIs based on the presence or absence of a macular hole, calculating speckle statistics (Contrast Ratio / CR) for each regional layer.
*   **Automated Export:** Compiles all statistical findings into an organized Excel spreadsheet (`OCT_ROI_Stats.xlsx`) for downstream analysis.

## Project Structure
*   `main_OCT_retinal_scan_script.m` - The primary execution script that handles folder selection, iterates through the `.bmp` images, and orchestrates the analysis pipeline.
*   `preprocess_OCT.m` - Standardizes image size, calculates scan tilt, flattens the image, applies vertical cropping, and extracts initial SAM embeddings.
*   `segment_ILM.m` - Uses SAM to isolate and smooth the Inner Limiting Membrane (ILM) boundary.
*   `detect_hole.m` - Stretches the image and applies morphological rules to identify macular holes, returning hole masks and spatial coordinates.
*   `segment_layers.m` - Maps the RPE boundaries and the inner retinal layers, handling cases where a hole interrupts the anatomy.
*   `analyze_rois.m` - Divides the segmented image into discrete ROIs (either full-width, or split into left/right zones if a hole is present) and computes Contrast Ratio (CR) statistics.
*   `align_image.m` - Utility function to flatten tilted scans and inject synthetic noise into the newly padded background areas.

## Prerequisites
*   **MATLAB** (Tested on R2025b)
*   Image Processing Toolbox
*   Computer Vision Toolbox
*   MATLAB Support Package for Segment Anything Model (SAM)

## Usage
1. Open MATLAB and navigate to the project directory.
2. Run `main_OCT_retinal_scan_script.m`.
3. A dialog box will appear. Select a folder containing your `.bmp` OCT scans.
4. The script will process the first, second, and last images in the folder (as currently configured).
5. Review the plotted figure windows to verify the segmentation lines and hole detection.
6. Once complete, retrieve your data from the generated `OCT_ROI_Stats.xlsx` file.
