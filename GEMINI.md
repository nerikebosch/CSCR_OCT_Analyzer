# Gemini AI Context File: OCT Retinal Scan Analysis

## Project Overview
This repository contains a MATLAB-based image processing pipeline designed to analyze Optical Coherence Tomography (OCT) retinal scans. It integrates traditional computer vision techniques with the **Segment Anything Model (SAM)** to automatically align scans, segment retinal layers, detect macular holes, and extract speckle statistics (Contrast Ratio) from specific Regions of Interest (ROIs). It includes a persistent local database, statistical analytics engine, batch processing, and an interactive MATLAB dashboard.

## Core Architecture & Data Flow

1. **`main_OCT_retinal_scan_script.m` (Entry Point):** Handles directory selection, invokes `process_oct_folder.m`, updates statistics in the database, and launches the UI dashboard.
2. **`preprocess_OCT.m`:** Standardizes image dimensions (992x1536), estimates initial tilt via ILM rough detection, flattens the image, crops to a central 6mm scan, and extracts the baseline SAM embeddings.
3. **`segment_ILM.m`:** Uses SAM with specific foreground/background point prompts to segment the Inner Limiting Membrane (ILM).
4. **`detect_hole.m`:** Stretches the image vertically, applies multi-thresholding and morphological operations (U-masks, region properties) to detect macular holes. If a hole is found, it uses SAM on the stretched image and scales the mask back. 
5. **`segment_layers.m`:** Maps the Top and Bottom of the Retinal Pigment Epithelium (RPE) using SAM embeddings. Divides the RPE into 3 green tracks, and the inner retina (between ILM and RPE) into 4 blue tracks by finding local intensity peaks.
6. **`analyze_rois.m`:** Dynamically slices the image into analysis ROIs. 
   * *If a hole is present:* Generates 5 Left ROIs and 5 Right ROIs, leaving a safe margin around the hole.
   * *If no hole is present:* Generates 5 Full-width continuous ROIs.
   * Computes Contrast Ratio (CR) for each bounding mask via `speckle_stats.m`.
7. **`align_image.m`:** A utility for flattening tilted scans via polyfit and injecting synthetic noise into padded rotations to preserve background speckle statistics.
8. **`db_manager.m`:** Centralized local database interface (`oct_study_db.mat`). Maintains `Visits`, `Scans`, and `VisitStats` tables without requiring external SQL servers or toolboxes.
9. **`compute_statistics.m`:** Computes $L4/L5$ ratios, exact daily rates of change ($\Delta\text{ratio}/\Delta\text{day}$), visit aggregates ($\mu, \sigma$), Pearson/Spearman clinical correlations with Central Retinal Thickness, and generates publication-grade multi-panel longitudinal figures.
10. **`process_oct_folder.m`:** Modular runner for a single visit folder. Extracts date, eye side, runs segmentation on target slices, records results in database, and updates statistics.
11. **`batch_process_folders.m`:** Scans a parent directory, iterates through all subdirectories, skips already-processed folders, reuses the instantiated SAM `MODEL`, and updates the database.
12. **`oct_dashboard.m`:** Interactive MATLAB App (`uifigure`) featuring longitudinal time-series plots with clinical status bands, rate-of-change velocity bars, Central Thickness editing, visit creation, and Excel export.
13. **`migrate_excel_to_db.m`:** Migration script importing all historical visits, central thicknesses, notes, and scan metrics from `Statistics.xlsx`.

## Key Variables & Structures
* `MODEL`: The instantiated SAM model passed through functions to avoid reloading.
* `embeddings_aligned`: Pre-computed SAM embeddings of the cropped image to optimize prompt-based segmentation.
* `DB`: The persistent database struct in `oct_study_db.mat` containing `Visits` and `Scans` tables.
* `plotoption`: A boolean toggle used throughout functions to enable/disable diagnostic figure rendering (e.g., `h1`, `h2`, etc.).

## Guidelines for AI Assistance
When generating, modifying, or debugging code for this project, adhere to the following rules:

1. **MATLAB Version & Toolboxes:** Assume modern MATLAB syntax (R2025b). Rely on the Image Processing Toolbox and Computer Vision Toolbox. Avoid functions requiring `Database Toolbox` (use `db_manager.m`).
2. **SAM Optimization:** Never re-extract embeddings for the same image unless the image dimensions or base pixels have fundamentally changed. Always pass `MODEL` and `embeddings` as arguments.
3. **Coordinate Systems:** Pay strict attention to global vs. local coordinates. Many functions (like RPE segmentation) crop the image further (`crop_y_start`) and require careful offset tracking when mapping local SAM masks back to the global `sy x sx` image space.
4. **Error Handling:** Maintain the `try-catch` block in the main loop to prevent a single scan failure from crashing the batch process.
5. **Data Preservation:** When performing morphological transforms (like rotation in `align_image.m` or vertical stretching in `detect_hole.m`), ensure masks and coordinates are accurately inversely transformed back to the original `I_crop_orig` space for statistical analysis.
6. **Code Style:** Keep functions strictly modular. Use descriptive variable names (`Layer_ILM`, `Mask_Hole`).
