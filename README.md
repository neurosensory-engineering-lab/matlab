# MATLAB research analysis scripts

This repository is a collection of MATLAB code developed across several experimental and analysis projects. Focused ultrasound (FUS) neuromodulation is one substantial branch, but it is not the sole purpose of the codebase. The scripts cover distinct data types and research questions, alongside image-conversion and analysis utilities; they do not form one universal pipeline.

## Project areas

### Widefield imaging and FUS

This branch analyzes auditory- or sensory-evoked cortical responses from Zyla camera TIFF stacks, including dF/F processing, ROI and PC-based spatial masks, trial quality control, response gain, targeting, and group-level statistics. Some analyses test responses before and after focused ultrasound, while others examine dual-tone spatial organization, relay timing, control rundown, and spatial variability.

Useful starting points include [FUS_Project_Overview.md](FUS_Project_Overview.md), [master_JH_FUS_dataanalysis.m](master_JH_FUS_dataanalysis.m), [focus_based_FUS_grandanalysis_QC.m](focus_based_FUS_grandanalysis_QC.m), and [PC_Relay_Chronometer.m](PC_Relay_Chronometer.m).

### Diffuse correlation spectroscopy and blood-flow analysis

The DCS branch reads raw `.dcs` measurements, fits autocorrelation data, estimates blood-flow index (BFI), and analyzes changes relative to baseline. It is a separate measurement and processing workflow from the widefield imaging scripts.

See [DCS_Project_Overview.md](DCS_Project_Overview.md), [runDCSBFI_clean.m](runDCSBFI_clean.m), [readDCSdata_SWC.m](readDCSdata_SWC.m), and [fastdcs1layer.m](fastdcs1layer.m). The processing workflow relies on the external `seminfdcsfit` fitting function.

### Peri-stroke auditory processing

The [runPeriStrokeAudProc170713sub1.m](runPeriStrokeAudProc170713sub1.m) and [runPeriStrokeAudProc170713sub2_test.m](runPeriStrokeAudProc170713sub2_test.m) scripts analyze auditory-processing recordings in a peri-stroke context, including DCS-derived blood-flow measures and related physiological signals. These are experiment-specific scripts rather than general-purpose entry points.

## Supporting and standalone tools

Other files handle tasks that support one or more projects or stand on their own:

- TIFF-stack import and inspection: [import_tiff_stack.m](import_tiff_stack.m)
- SVS whole-slide image display and export: [displaySVS.m](displaySVS.m), [convertSVStoTIFF.m](convertSVStoTIFF.m), and [exportLevel0FromSVS.m](exportLevel0FromSVS.m)
- Functional-map and anatomy visualization: [pericyte_overlay_script.m](pericyte_overlay_script.m)
- Image geometry conversion: [panoramaToCubemap.m](panoramaToCubemap.m)
- Data export: [export_to_csv.m](export_to_csv.m)

Many remaining scripts are focused analyses, plotting scripts, or historical/test variants. Their names and assumptions often reflect a specific experiment.

## Working with the code

- Choose the project overview and scripts that match the data type and experiment; do not assume files from different branches share inputs or outputs.
- Check each script's parameters and comments before running it. Many scripts expect lab-specific folder structures, filenames, saved workspaces, masks, or external MATLAB functions.
- Treat the overview documents as guides to the corresponding analysis branches, not as a promise that every script is a maintained, end-to-end pipeline.
