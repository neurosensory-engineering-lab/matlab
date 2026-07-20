# MATLAB analysis pipeline for focused ultrasound neuromodulation

This repository contains MATLAB scripts for analyzing widefield imaging data from focused ultrasound (FUS) neuromodulation experiments. The overall goal is to quantify whether FUS produces measurable, spatially specific, and reproducible changes in cortical activity, and to characterize how those effects vary with stimulation parameters, target location, and time after stimulation.

## Project focus

The analysis workflow is organized around the following questions:

- Does FUS increase or suppress neural activity relative to pre-stimulation baseline?
- Are the effects spatially localized around the intended sonication target?
- Are the responses robust after quality control and correction for session drift or rundown?
- Do low-power and high-power conditions produce distinct patterns of modulation?

## Main analysis themes

The repository supports several related analysis directions:

- Functional response extraction from TIFF image stacks
- ROI-based analysis using PC1 or spatial masks
- Pre-FUS versus post-FUS gain comparisons
- Spatial ring analysis around the FUS target
- Dual-tone / targeting validation experiments
- Relay kinetics and temporal evolution analyses
- QC filtering to remove noisy or unstable traces

## Key scripts

- [master_JH_FUS_dataanalysis.m](master_JH_FUS_dataanalysis.m): main integrated analysis pipeline for processing experiment folders and extracting response metrics.
- [focus_based_FUS_grandanalysis_QC.m](focus_based_FUS_grandanalysis_QC.m): target-centric analysis with full trace storage and QC-based filtering.
- [control_rundown_PC_masking_analysis.m](control_rundown_PC_masking_analysis.m): estimates control rundown and applies correction for session drift.
- [DT_FUS_FocusTest.m](DT_FUS_FocusTest.m): dual-tone spatial targeting verification and visualization against physical FUS targets.
- [PC_Relay_Chronometer.m](PC_Relay_Chronometer.m): relay timing and temporal analysis workflow.
- [group_relay_kinetics_advanced_stats.m](group_relay_kinetics_advanced_stats.m): group-level relay kinetics and statistical visualization.
- [reanalysis.m](reanalysis.m): fast re-analysis and export of summary statistics from saved results.
- [pericyte_overlay_script.m](pericyte_overlay_script.m): example script for overlaying functional response maps onto grayscale anatomy.

## Typical workflow

1. Load experiment metadata from the experiment summary spreadsheet.
2. Identify the relevant pre-FUS and post-FUS TIFF sets.
3. Extract traces from image stacks using spatial masks or ROI definitions.
4. Apply baseline correction and QC thresholds.
5. Compute response gain or relay metrics over time bins.
6. Compare effect sizes across conditions, distances, and groups.
7. Generate figures and export summary statistics.

## Notes

- Much of the code assumes a specific folder structure and experiment naming convention tied to the lab dataset.
- Several scripts depend on precomputed mask variables such as PC1 maps or saved results structures.
- The repository is best understood as an analysis toolkit for a broader experimental series rather than a single standalone script.

## Intended use

This codebase is intended for researchers working on FUS neuromodulation experiments who need a reproducible MATLAB pipeline for:

- extracting functional responses from imaging data,
- testing spatial specificity,
- comparing low- versus high-power conditions,
- and reporting robust, QC-filtered results.
