# FUS (Focused Ultrasound) Project Overview

This workspace contains a separate focused ultrasound (FUS) analysis effort that is distinct from the DCS project. The DCS work is centered on diffuse correlation spectroscopy and blood-flow estimation, while the FUS project is a cortical imaging workflow aimed at measuring how auditory or sensory cortex responds before and after ultrasound stimulation.

The important distinction is that the FUS project is not a DCS pipeline. It is a whole-image analysis workflow that begins with Zyla camera TIFF stacks, builds temporal traces, applies spatial masks based on activity or PC structure, filters trials by QC, and then tests whether FUS changes cortical responses in a target-specific or group-specific way.

## 1) Scientific goal of the FUS project

The FUS project asks whether focused ultrasound alters cortical activity in a measurable and spatially interpretable way. The main experimental questions include:

- Does FUS change the amplitude of evoked cortical responses?
- Are those changes constrained to a target region or distributed across cortex?
- Do effects differ by power level, spatial ring, or PC-defined mask?
- Does the response evolve over time after stimulation?
- Can drift, rundown, or inter-trial instability be corrected or excluded reliably?

This is an experimental neuroscience analysis pipeline, not a blood-flow measurement pipeline.

## 2) The Zyla camera imaging pipeline

The core FUS workflow is built around TIFF stacks acquired from a Zyla camera. The repeated pattern across the scripts is the same:

1. load a TIFF stack for each trial or group of trials,
2. smooth the frames spatially,
3. compute a baseline image from early frames,
4. calculate dF/F relative to that baseline,
5. extract a region- or mask-based time trace,
6. compare pre-FUS and post-FUS traces across bins or conditions,
7. apply QC to reject noisy or unstable trials,
8. visualize or export summary metrics.

The analysis code repeatedly uses this sequence, although different scripts vary in whether they are doing broad batch processing, PCA, ROI-based analysis, target-centered analysis, or group-level statistics.

## 3) Main stages of the imaging pipeline

### Stage A: raw TIFF ingestion and frame preprocessing

This is the base of the pipeline. Scripts such as:

- group_process_zylavideos.m
- group_process_zylavideos1.m
- batch_average_zylatif_plot_traces.m

load multi-page TIFF stacks, smooth the frames, create baseline images, and compute dF/F stacks.

These scripts are the earliest and simplest forms of the Zyla workflow. They establish the key computational idea: use a per-trial baseline image to compute relative fluorescence changes over time and then summarize those changes by trace or average image.

### Stage B: averaging and ROI-based trace extraction

The next layer takes those per-frame movies and extracts representative traces using regions of interest or mask-based averaging. This is where the project become more biologically interpretable.

Scripts involved in this stage include:

- batch_average_zylatif_plot_traces.m
- master_JH_FUS_dataanalysis.m
- focus_based_FUS_grandanalysis_QC.m
- PC_based_QC_control_stats_plotting_and_export.m

These scripts compute traces from masked regions, often based on PC1 percentile bands or distance rings from a target center. The goal is not just to display time series but to quantify how a cortical area responds across the experiment.

### Stage C: PC-based spatial organization and mask building

A major branch of the FUS project uses functional activity maps to define cortical masks. The project repeatedly refers to PC1 maps and percentile bins as spatial descriptors.

Important scripts in this branch:

- master_JH_FUS_dataanalysis.m
- control_rundown_PC_masking_analysis.m
- PC_based_QC_control_stats_plotting_and_export.m
- functional_to_spatial_lookup.m
- ring_vs_PC_percentile_mapping_comparison.m
- FUS_anisotropic_gain_predictor.m
- plot_PC1_percentile_dashboard_from_workspace.m

These scripts define masks such as:

- top 10% PC1 region,
- percentile bands of activation,
- radial distance bins from a target,
- and spatial layers used to compare gain across cortical location.

This is a significant analytical branch because it connects functional imaging to spatial anatomical interpretation rather than only single ROI averages.

### Stage D: group-level and target-centric comparisons

Once per-trial traces are extracted and QC-filtered, the project shifts to comparisons across experiments or across time bins.

Core scripts in this stage:

- focus_based_FUS_grandanalysis_QC.m
- control_rundown_PC_masking_analysis.m
- PC_Relay_Chronometer.m
- group_relay_kinetics_advanced_stats.m
- group_relay_kinetics_advanced_stats_pub_ready.m
- master_JH_FUS_dataanalysis.m

These ask things like:

- how does response change in the post-FUS bins compared to pre-FUS baseline?
- which spatial region shows the strongest gain or largest deviation?
- do control runs show drift that needs correction?
- do low-power and high-power groups differ in their kinetics?

This is the formal analysis layer that turns raw traces into the actual biological conclusions.

## 4) Iterations in the Zyla pipeline

There were clearly multiple iterations of the imaging pipeline, and the scripts reflect that evolution.

### Iteration 1: simple batch processing

Files:

- group_process_zylavideos.m
- batch_average_zylatif_plot_traces.m

These are early, straightforward versions. They process TIFF stacks in a direct way: load movie, smooth, compute dF/F, and average or extract traces. They are the clearest examples of the original camera-processing logic.

### Iteration 2: grouped processing and PCA-oriented analysis

Files:

- group_process_and_PCA_zylavideos.m
- PCA_analysis_for_FUS.m
- PCA_analysis_for_FUS_with_GMM.m
- PCA_analysis_for_FUS_db.m

These scripts add a more advanced modeling layer. They reshape the movie data, perform PCA, and examine the first few principal components (especially PC1, PC2, PC3). The purpose is to reduce the high-dimensional motion/response data into spatial modes that can be interpreted as dominant cortical patterns.

This represents a more exploratory and model-driven branch of the workflow.

### Iteration 3: target-centric and mask-based analysis

Files:

- master_JH_FUS_dataanalysis.m
- focus_based_FUS_grandanalysis_QC.m
- control_rundown_PC_masking_analysis.m
- PC_based_QC_control_stats_plotting_and_export.m
- PC_Relay_Chronometer.m

These scripts are more structured and likely reflect the maturation of the project. They move away from generic movie processing and toward:

- experimental metadata handling,
- masks defined by cortical structure,
- trial QC,
- target-centered averaging,
- and gain comparisons across bins.

This is the most “project-level” analysis branch.

### Iteration 4: validation, targeting, and publication plotting

Files:

- DT_FUS_FocusTest.m
- DT_dualtone_reanalysis.m
- dual_tone_experiment_analysis.m
- overlap_dual_tone_experiments.m
- predictFUSDualToneMap.m
- predictFUSGainMap.m
- FUS_stats_dashboard.m
- group_relay_kinetics_advanced_stats_pub_ready.m

These are more targeted or presentation-focused scripts. They ask whether the stimulation target is correct, whether dual-tone maps align with expectations, and how to visualize findings in a polished or publication-ready way.

This branch is not necessarily the raw pipeline; it is a validation and communication layer built on top of the earlier data-processing work.

## 5) Scripts directly involved in the FUS data-analysis pipeline

The following scripts represent the main pipeline in practice:

### Core preprocessing and extraction

- group_process_zylavideos.m
- group_process_zylavideos1.m
- batch_average_zylatif_plot_traces.m
- master_JH_FUS_dataanalysis.m
- focus_based_FUS_grandanalysis_QC.m
- PC_based_QC_control_stats_plotting_and_export.m

### Spatial masking and cortical mapping

- control_rundown_PC_masking_analysis.m
- functional_to_spatial_lookup.m
- ring_vs_PC_percentile_mapping_comparison.m
- plot_PC1_percentile_dashboard_from_workspace.m
- FUS_anisotropic_gain_predictor.m
- PCA_analysis_for_FUS.m
- PCA_analysis_for_FUS_with_GMM.m

### Temporal response and statistics

- PC_Relay_Chronometer.m
- group_relay_kinetics_advanced_stats.m
- group_relay_kinetics_advanced_stats_pub_ready.m
- reanalysis.m
- export_to_csv.m

### Targeting and validation

- DT_FUS_FocusTest.m
- DT_dualtone_reanalysis.m
- dual_tone_experiment_analysis.m
- overlap_dual_tone_experiments.m
- FUS_Focus_Validation.m
- pericyte_overlay_script.m

## 6) Exploratory or targeted branches

Not every script is part of the central pipeline. Several are clearly specialized or exploratory:

- PCA analysis scripts: these are more exploratory and model-driven than the main ROI workflow.
- dual-tone analysis scripts: they are targeted to a specific experimental design and not the generic pipeline.
- plotting dashboards and validation reports: they support interpretation and presentation rather than raw analysis.
- calibration scripts such as circle_calibration_test.m and control_run_down_test.m: these are sanity checks and diagnostic tools.
- spatial variability or ring-comparison scripts: they test a specific hypothesis about cortical spatial organization rather than serving as the default processing route.

In other words, the project has a backbone pipeline, but it also includes a set of specialized branches for:

- PCA decomposition,
- target validation,
- dual-tone stimulus analysis,
- publication-level figure generation,
- and diagnostics for drift or data quality.

## 7) Practical interpretation of the codebase

If someone is trying to understand the FUS project from the code, the most informative reading order is:

1. group_process_zylavideos.m
2. batch_average_zylatif_plot_traces.m
3. master_JH_FUS_dataanalysis.m
4. focus_based_FUS_grandanalysis_QC.m
5. control_rundown_PC_masking_analysis.m
6. PC_Relay_Chronometer.m
7. group_relay_kinetics_advanced_stats.m
8. DT_FUS_FocusTest.m and related validation scripts

This sequence follows the natural progression from raw TIFF based processing to quantitative comparison and targeted validation.

## 8) Bottom line

The FUS project is a multi-iteration imaging analysis workflow built around Zyla TIFF acquisition, dF/F extraction, spatial masking, and experimental comparison. The scripts form a layered pipeline:

- raw movie preprocessing,
- ROI or mask trace extraction,
- PC-based spatial mapping,
- QC and drift correction,
- temporal bin analysis,
- and targeted validation / plotting.

The codebase shows clear evidence of multiple branches: a core batch-processing line, a PCA/mapping line, and a target-validation/statistics line. The earlier scripts are more exploratory and foundational, while the later scripts are more formalized and likely closer to the actual finalized analysis workflow.
