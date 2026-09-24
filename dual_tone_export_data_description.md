# Dual-Tone Export Data Description

## Purpose

`export_dual_tone_workspace_data.m` exports data that already exists in the MATLAB workspace after running `dual_tone_experiment_analysis.m`. It does not rerun TIFF image processing or recalculate the original experiment traces unless a required summary variable is missing and must be reconstructed from existing arrays.

Run it from the same MATLAB workspace:

```matlab
export_dual_tone_workspace_data
```

The original analysis script must have completed first, and the MATLAB workspace must still contain the variables it generated.

## Output Folder

The script creates:

```text
dual_tone_workspace_export/
├── csv/
└── pc_masks/
```

Existing files with the same names are overwritten by `writetable`, `writematrix`, and `imwrite`.

## CSV Outputs

### `raw_plot_datapoints.csv`

Long-format table with two rows per experiment and time bin: one for the `10 kHz` condition and one for the `30 kHz` condition.

Columns:

- `Experiment`: experiment identifier, such as `DT1`.
- `Condition`: either `10 kHz` or `30 kHz`.
- `TimeBin`: post-FUS time bin number. Each bin generally represents 10 trials.
- `RawGain`: normalized gain datapoint from `G10_all` or `G30_all`.
- `CleanGainUsedForPlot`: the same datapoint after the paired-condition validity mask is applied. Values excluded from plotting are `NaN`.
- `PlotIncluded`: `true` only when both 10 kHz and 30 kHz values exist for that experiment and bin.

`RawGain` is not the original pixel intensity or raw TIFF signal. It is the normalized response gain calculated by the original analysis:

```text
post response peak / pre-condition response peak
```

The original analysis uses ROI 1, the 10 kHz focus centroid location, for the final gain values.

The revised analysis also computes all of the following probe/ROI combinations:

- 10 kHz and 30 kHz probes in the 10 kHz PC1 mask.
- 10 kHz and 30 kHz probes in the full 30 kHz PC1 mask.
- 10 kHz and 30 kHz probes in the disjoint 30 kHz-only mask (`mask_30 & ~mask_10`).

The full 30 kHz mask is the primary readout for the question of whether modulation at
the 10 kHz representation affects the 30 kHz PC1 top-percentile representation. The
disjoint mask is a sensitivity analysis that removes the overlapping 10 kHz pixels.

### `probe_roi_datapoints.csv`

Long-format gain table containing all six probe/ROI combinations above. `PlotIncluded`
indicates that the paired probe values for that ROI and time bin were both available.

### Additional raw matrices

The following matrices retain the exact experiment-by-bin values used to create the
long table:

- `G10_at_30_raw_matrix.csv` and `G30_at_30_raw_matrix.csv`: probes in the full 30 kHz mask.
- `G10_at_30_specific_raw_matrix.csv` and `G30_at_30_specific_raw_matrix.csv`: probes in the disjoint 30 kHz-only mask.
- `valid_mask_full30.csv` and `valid_mask_specific30.csv`: paired availability masks for those two ROI analyses.

### `mask_geometry.csv`

Per-experiment mask pixel counts, overlap, Dice coefficient, whole-mask centroid
separation in pixels, connected-component counts, and pre/post trial counts.

### `analysis_parameters.csv`

The PC1 threshold, baseline and response frame windows, bin width, and pixel-size
metadata used by the analysis.

### `clean_plot_datapoints.csv`

Subset of `raw_plot_datapoints.csv` containing only rows where `PlotIncluded` is `true`. These are the paired-condition datapoints used in the main plot and paired statistical comparison.

### `averaged_plot_data.csv`

One row per time bin.

Columns:

- `TimeBin`: time bin number.
- `Mean10kHz`: mean of the included 10 kHz gains.
- `SEM10kHz`: standard error of the mean for the included 10 kHz gains.
- `Mean30kHz`: mean of the included 30 kHz gains.
- `SEM30kHz`: standard error of the mean for the included 30 kHz gains.
- `N10kHz`: number of non-`NaN` 10 kHz values included.
- `N30kHz`: number of non-`NaN` 30 kHz values included.

The means and SEMs are calculated from the cleaned paired-condition arrays, not from every independently available value.

### `statistics.csv`

One row per time bin.

Columns:

- `TimeBin`: time bin number.
- `DeltaGain_30minus10`: mean paired difference, calculated as `30 kHz gain - 10 kHz gain`.
- `PairedPValue`: two-sided paired t-test p-value for the 30 kHz versus 10 kHz difference.
- `NPaired`: number of matched experiment pairs used in that time bin.

The original analysis only calculates a p-value when at least two matched pairs are available. Bins without enough pairs have `NaN` p-values and gain differences.

### `G10_all_raw_matrix.csv`

Numeric matrix containing the original `G10_all` array. Rows are experiments in the order given by `uniqueExps`; columns are time bins.

### `G30_all_raw_matrix.csv`

Numeric matrix containing the original `G30_all` array. Rows are experiments in the order given by `uniqueExps`; columns are time bins.

### `valid_mask.csv`

Logical matrix with the same shape as `G10_all` and `G30_all`. A value of `1` means both conditions were available and the experiment/bin pair was retained for paired plotting and statistics. A value of `0` means the pair was excluded.

## TIFF Mask Outputs

The `pc_masks` folder contains the full masks and, when both source maps are
available, the derived disjoint 30 kHz mask per experiment:

```text
<Experiment>_PC1_10kHz_mask.tif
<Experiment>_PC1_30kHz_mask.tif
<Experiment>_PC1_30kHz_specific_mask.tif
```

Each mask is generated from the corresponding workspace PC1 map using:

```matlab
PC1_map > 0.9
```

The TIFF pixels are encoded as:

- `0`: outside the mask
- `255`: inside the mask

These are the binary PC1 ROI masks used by the original image-analysis pipeline. The source PC1 maps must still exist in the workspace under names like:

```text
PC1_DT1_10kHz_norm_upscaled
PC1_DT1_30kHz_norm_upscaled
```

The script also recognizes the capitalization variant `KHz`.

## What Is Not Exported

The exporter does not contain a complete archive of every TIFF-derived trace, every trial, or every intermediate image. It exports the normalized gain values that became plotting datapoints, the derived plot statistics, and the PC1 threshold masks.

The original analysis also performs quality control on pre- and post-trial traces. Those full trace arrays are not retained comprehensively for all experiments by the original script, so they cannot be reconstructed by this exporter after the fact.

## Interpretation Notes

- `10 kHz` and `30 kHz` are the two acoustic-frequency conditions represented in this analysis.
- The final gain values are normalized relative to the corresponding pre-condition response.
- `NaN` means data were unavailable, failed quality control, or were excluded by the paired-condition mask.
- Time bins are numbered beginning at 1. The original script creates bins using post-trial ranges of approximately 10 trials each.
- The TIFF masks are spatial ROI definitions; they are not statistical maps and do not contain gain values.
