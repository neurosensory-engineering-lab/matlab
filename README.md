# MATLAB analysis pipeline for focused ultrasound neuromodulation

This repository contains the MATLAB analysis code used to study focused ultrasound (FUS) neuromodulation in the auditory cortex using widefield calcium imaging. The work is rooted in the experimental program described in Jacob Hehir’s dissertation draft, and the analyses in this repository reflect a later stage of the project in which the same experimental framework was developed further for more detailed quantitative evaluation.

## Repository context

The original thesis work focused on a new experimental platform for testing FUS in vivo: a combination of widefield calcium imaging, auditory stimulation, and targeted ultrasound delivery in mice. The dissertation framed the project around the idea that FUS could modulate auditory-evoked cortical responses in a safe, reversible, and spatially precise way.

This repository captures the subsequent analysis effort for that same experimental series. In contrast to the thesis draft, which presents early descriptive and preliminary conclusions, the code here is geared toward a more rigorous analysis of:

- response amplitude and timing changes,
- spatial specificity around the intended FUS target,
- low-power versus high-power effects,
- control drift or rundown correction,
- and quality-controlled comparisons across trials and experimental groups.

## Scientific motivation

The broader project asks whether focused ultrasound can be used as a noninvasive tool to modulate sensory processing in cortex. The auditory system is a useful testbed because it offers well-defined tonotopic organization, making it possible to ask whether FUS changes activity in a spatially structured and interpretable way.

The experimental story in this repository is therefore about more than a single effect size. It is about building a quantitative framework for evaluating whether FUS produces meaningful neuromodulatory effects in vivo, and whether those effects are robust enough to support further mechanistic or translational work.

## Main analysis themes

The repository supports several related analysis directions:

- extraction of functional responses from TIFF image stacks,
- ROI-based analysis using PC1 masks or spatial rings,
- pre-FUS versus post-FUS gain comparisons,
- spatial targeting and dual-tone validation analyses,
- relay kinetics and temporal evolution analyses,
- and strict QC filtering to remove noisy or unstable traces.

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
- This repository is best understood as a research analysis toolkit for a specific experimental series rather than a single standalone script.

## Intended use

This codebase is intended for researchers working on FUS neuromodulation experiments who need a reproducible MATLAB pipeline for:

- extracting functional responses from imaging data,
- testing spatial specificity,
- comparing low- versus high-power conditions,
- and reporting robust, QC-filtered results that go beyond the earlier descriptive thesis analyses.
