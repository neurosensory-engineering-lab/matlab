# DCS Project Overview

This workspace contains a DCS analysis project that is separate from the FUS analysis work. The DCS project is described in the attached publication [jethe_et_al.pdf](jethe_et_al.pdf), and the FUS-related scripts that also appear in this folder should be treated as a distinct analysis stream rather than as part of the DCS project itself.

The key point is this:

- The DCS project is the signal-processing and physiology workflow centered on diffuse correlation spectroscopy, blood-flow index estimation, baseline fitting, and time-series extraction from .dcs data.
- The FUS scripts in this workspace are a separate experimental analysis branch focused on cortical response mapping, spatial targeting, and ultrasound-related response comparisons.
- They may coexist in the same folder, but they are not the same project and should not be conflated.

## 1) What the DCS project is

The DCS project is a measurement and analysis pipeline for converting raw DCS autocorrelation data into physiologically meaningful flow metrics. The core goal is to estimate blood-flow-related dynamics from the temporal correlation curves and to quantify changes over time relative to a defined baseline.

The analysis generally involves:

- reading raw DCS files,
- averaging detector channels by source-detector distance,
- fitting the correlation function g2 to a semi-infinite model,
- estimating beta and/or BFI,
- identifying baseline frames,
- and computing relative changes in blood-flow index across time.

This is a distinct scientific effort from the FUS imaging workflow and is best understood as a DCS-only analysis project.

## 2) Core DCS scripts

### runDCSBFI_clean.m
Importance: Critical

This is the central DCS analysis script in the workspace. It is the cleanest and most direct entry point for processing raw .dcs files into a usable BFI time series.

It does the following:

- locates DCS files matching a file prefix,
- reads raw DCS data and reshapes it into the expected frame/time structure,
- identifies baseline frames from the mark signal,
- averages detector channels across separations,
- fits the DCS model to compute beta, rho, and BFI,
- returns a results structure containing frame index, time axis, g2 data, fit curves, and BFI traces,
- and optionally saves the output.

Why it matters:

- This is the primary DCS-processing pipeline.
- It is the script most directly tied to the publication and the underlying data-analysis workflow.
- It is the clear “main path” for DCS work in this folder.

### fastdcs1layer.m
Importance: High, but historical/reference-oriented

This is the older functional implementation of the same DCS fitting logic. It is conceptually similar to runDCSBFI_clean.m, but it is more manual and less polished.

It implements:

- semi-infinite fitting of the DCS model,
- baseline beta estimation,
- fixed-beta BFI fitting,
- and saving of fitted g2 curves and BFI outputs.

Why it matters:

- It is useful as a reference or historical implementation.
- It helps clarify the mathematical assumptions behind the DCS fitting routine.
- It is not the primary script to use if the goal is to run the clean processing pipeline.

### readDCSdata_SWC.m
Importance: Moderate

This file appears to be a lower-level import/parser utility for raw DCS data.

Why it matters:

- It supports the data ingestion step needed before fitting.
- It is relevant to the DCS pipeline, although it is not the main computational script.
- It is useful for understanding the raw file format and for debugging if the import assumptions change.

### seminfdcsfit dependency
Importance: Essential but external

The DCS fitting pipeline relies on seminfdcsfit, which is not counted as a script in the listed workspace files but is clearly a required numerical dependency.

Why it matters:

- This is the underlying model-fitting engine used to estimate BFI.
- The DCS project depends on this function to perform the actual correlation-to-flow inversion.
- It is not a separate project component; it is the core computational dependency of the DCS workflow.

## 3) DCS-related supporting utilities

Several other files in the workspace are image-handling or infrastructure utilities rather than part of the DCS project core. Examples include:

- convertSVStoTIFF.m
- displaySVS.m
- import_tiff_stack.m

These are relevant for image conversion and inspection, but they are not the core of the DCS blood-flow estimation workflow.

## 4) What is not part of the DCS project

The following group of files are clearly from a separate FUS analysis context and should not be mistaken for the DCS project itself:

- master_JH_FUS_dataanalysis.m
- focus_based_FUS_grandanalysis_QC.m
- control_rundown_PC_masking_analysis.m
- PC_Relay_Chronometer.m
- group_relay_kinetics_advanced_stats.m
- DT_FUS_FocusTest.m
- predictFUSDualToneMap.m
- predictFUSGainMap.m
- FUS_anisotropic_gain_predictor.m
- dual_tone_experiment_analysis.m
- overlap_dual_tone_experiments.m
- pericyte_overlay_script.m

These scripts deal with:

- cortical imaging traces,
- spatial mask analysis,
- pre/post FUS response comparisons,
- relay kinetics,
- target validation,
- and FUS-related visualization/statistics.

They are valuable and scientifically meaningful, but they are a separate branch from the DCS project described in the publication.

## 5) Importance ranking for the DCS project

### Essential DCS files

- runDCSBFI_clean.m
- fastdcs1layer.m
- readDCSdata_SWC.m
- seminfdcsfit (supporting dependency)

These are the actual core of the DCS analysis workflow.

### Supporting or peripheral files

- convertSVStoTIFF.m
- displaySVS.m
- import_tiff_stack.m

These may help with data inspection or preparation, but they are not the main DCS analysis engine.

### Separate FUS files

- master_JH_FUS_dataanalysis.m
- DT_FUS_FocusTest.m
- group_relay_kinetics_advanced_stats.m
- and related FUS response scripts

These belong to a separate FUS investigation and should be treated as distinct from the DCS project.

## 6) Recommended reading order

To understand the DCS project as written in the publication, the best order is:

1. Read [jethe_et_al.pdf](jethe_et_al.pdf) for the scientific framing.
2. Review runDCSBFI_clean.m as the main computational workflow.
3. Compare with fastdcs1layer.m as the historical implementation reference.
4. Use readDCSdata_SWC.m or similar import scripts only when needing to debug file parsing or format assumptions.
5. Treat the FUS scripts as a separate analysis effort rather than part of the DCS pipeline.

## 7) Bottom line

The DCS project is a standalone analysis effort centered on diffuse correlation spectroscopy and blood-flow estimation. It is described in [jethe_et_al.pdf](jethe_et_al.pdf) and is distinct from the FUS-focused scripts elsewhere in this folder. The DCS work should be interpreted as its own project; the FUS scripts are separate, even if they happen to be stored in the same workspace.
