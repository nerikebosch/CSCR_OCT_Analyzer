# CSCR OCT Analyzer & Longitudinal Clinical Study Pipeline

A MATLAB-based image processing, machine learning, and longitudinal clinical analytics pipeline designed to analyze Optical Coherence Tomography (OCT) retinal scans. The system integrates traditional computer vision techniques with the **Segment Anything Model (SAM)** to automatically align scans, segment retinal layers, detect macular holes, extract speckle statistics from Regions of Interest (ROIs), and track disease evolution across clinical visits through a persistent local database and an interactive dashboard.

---

## Key Features

* **Automated Pre-processing & Tilt Correction:** Resizes (992x1536), estimates scan tilt via rough ILM detection, flattens the scan, crops to a central 6mm zone, and extracts baseline SAM embeddings.
* **SAM-Powered Layer Segmentation:**
  * **ILM Segmentation:** Prompts SAM to segment and trace the Inner Limiting Membrane.
  * **Macular Hole Detection:** Vertically stretches the image, applies morphological thresholding and region properties to identify holes, segments with SAM, and inversely maps back to the aligned space.
  * **RPE & Inner Retinal Tracks:** Segments top and bottom boundaries of the Retinal Pigment Epithelium (RPE) into 3 sub-layers and divides the inner retina into 4 distinct tracks using local intensity peak tracking.
* **Dynamic ROI Speckle Analysis:**
  * *Hole present:* Dynamically generates 5 Left ROIs and 5 Right ROIs with safety margins.
  * *No hole:* Generates 5 Full-width continuous ROIs.
  * Extracts Contrast Ratio ($\text{CR} = \sigma / \mu$), Densitometry, and distribution fits (Burr-2, Gamma, K-distribution, Weibull, etc.) via `speckle_stats.m`.
* **Zero-Setup Local Database (`db_manager.m`):**
  * Fully native, persistent table database (`oct_study_db.mat`) with no SQL servers or extra toolboxes required.
  * Maintains relational tables for `Visits`, `Scans`, and `VisitStats`.
* **Longitudinal Statistical Analytics Engine (`compute_statistics.m`):**
  * Computes the $L4/L5$ speckle contrast ratio.
  * Computes exact daily rate of change ($\Delta\text{ratio}/\Delta\text{day}$) between consecutive clinical visits.
  * Computes visit aggregates (means and standard deviations across slices).
  * Evaluates Pearson and Spearman clinical correlations between Central Retinal Thickness ($\mu m$) and speckle contrast ratios.
  * Automatically renders publication-grade two-panel figures with clinical status bands (*Active Flare-up*, *Pre-recurrence*, *Remission*).
* **Interactive MATLAB UI Dashboard (`oct_dashboard.m`):**
  * Desktop application built with MATLAB `uifigure`.
  * Visualizes temporal time-series, dual-axis thickness overlays, and rate-of-change velocity bars.
  * Interactive visit selector, central thickness editor, clinical status badges, and visit creation (e.g. Visit 23+).
* **Flexible Single & Batch Execution:**
  * Process single folders or batch-process entire directory trees.
  * Features skip/resume capability and reuses the instantiated SAM `MODEL` in memory to maximize processing speed.
* **One-Click Excel Export & Migration:**
  * Importer to migrate historical visits from `Statistics.xlsx`.
  * Multi-sheet Excel exporter for sharing audit data with clinical collaborators and thesis supervisors.

---

## Project Structure

```text
├── main_OCT_retinal_scan_script.m   # Entry-point runner for single folder processing and dashboard launch
├── oct_dashboard.m                  # Interactive MATLAB UI Desktop Dashboard (uifigure)
├── db_manager.m                     # Persistent local database manager (oct_study_db.mat)
├── compute_statistics.m             # Analytics engine (L4/L5 ratios, rates of change, correlations, figures)
├── process_oct_folder.m             # Modular folder runner with metadata parsing and DB recording
├── batch_process_folders.m          # Batch runner across all subdirectories with skip/resume logic
├── migrate_excel_to_db.m            # Historical data importer from Statistics.xlsx into the database
├── preprocess_OCT.m                 # Standardizes scan size, flattens tilt, crops 6mm, extracts SAM embeddings
├── segment_ILM.m                    # Segments the Inner Limiting Membrane (ILM) using SAM prompts
├── detect_hole.m                    # Stretches scan vertically, detects macular holes, and segments boundary
├── segment_layers.m                 # Maps RPE top/bottom and 4 inner retinal blue tracks
├── analyze_rois.m                   # Slices image into 15 ROIs (Left, Right, Full) and calls speckle_stats
├── speckle_stats.m                  # Calculates contrast ratios, densitometry, and 11 distribution fits
├── align_image.m                    # Flattens tilted scans with synthetic noise padding
├── burrfit2.m / burr2pdf.m          # Burr-2 distribution parameter estimation and PDF evaluation
├── kfit.m / kpdf.m                  # K-distribution parameter estimation and PDF evaluation
├── fake_data.m                      # Synthetic benchmark script for testing clinical status bands
├── GEMINI.md                        # Architectural context, data flow, and development guidelines
└── .gitignore                       # Medical data protection rules (blocks scans, DBs, and spreadsheets)
```

---

## Prerequisites

* **MATLAB** (Tested on R2025b)
* **Required Toolboxes:**
  * Image Processing Toolbox
  * Computer Vision Toolbox
  * Statistics and Machine Learning Toolbox
  * Deep Learning Toolbox
  * MATLAB Support Package for Segment Anything Model (SAM)

*(Note: The Database Toolbox is NOT required; `db_manager.m` uses high-performance native MATLAB table persistence).*

---

## Getting Started

### 1. Launch the Interactive Dashboard
To inspect existing visits, view longitudinal graphs, edit central retinal thicknesses, or export Excel reports:
```matlab
oct_dashboard
```

### 2. Process a Single OCT Scan Folder
To analyze an individual visit folder using the graphical file selector:
```matlab
main_OCT_retinal_scan_script
```
Or run it programmatically:
```matlab
folderPath = 'C:\Path\To\Scan_Folder';
process_oct_folder(folderPath);
```

### 3. Batch Process Multiple Folders
To scan a root directory and process all unrecorded visit folders automatically:
```matlab
batch_process_folders('C:\Path\To\Parent_Data_Folder');
```
*Folders already recorded in the database are automatically skipped to save time.*

### 4. Generate Clinical Summary & Correlation Reports
To print the full statistical table and correlation coefficients in the MATLAB Command Window:
```matlab
compute_statistics('report');
```
To generate and save the publication-grade multi-panel figure:
```matlab
compute_statistics('plot', 'longitudinal_study.png');
```

### 5. Export Data to Excel
To generate a consolidated multi-sheet Excel file for your supervisor:
```matlab
db_manager('export_excel', 'OCT_Study_Export.xlsx');
```

---

## Medical Data Privacy

To comply with patient data privacy regulations, **no raw scans (`.bmp`, `.png`, `.tif`), local database files (`oct_study_db.mat`), or patient spreadsheets (`*.xlsx`) are committed to version control.** The repository includes a [`.gitignore`](.gitignore) file that strictly shields clinical data while tracking all code, functions, and documentation.
