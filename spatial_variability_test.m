%% spatial_variability_test.m
% Generic spatial variability test for FUS gain data.
% This script is intentionally blind to a specific trend shape.
% It asks a simpler question: do spatial bands vary more than expected by chance?
%
% Scientific rationale:
% - This avoids overfitting to an annular hypothesis.
% - It tests for general spatial heterogeneity using a permutation-based
%   null model that shuffles band labels within each experiment.
% - The statistic is the spatial variability of gain across bands, measured
%   as the variance of band-wise gains within each experiment.
%
% Required workspace variables:
%   corrected_gains  [spatial_band x time_bin x experiment]
%   isL, isH         logical vectors or masks matching experiments

if ~exist('corrected_gains','var')
    error('Variable ''corrected_gains'' not found in workspace. Load data first.');
end
if ~exist('isL','var') || ~exist('isH','var')
    error('Variables ''isL'' and/or ''isH'' are missing. Load the workspace that contains these experiment masks.');
end

num_bands = size(corrected_gains, 1);
num_time_bins = size(corrected_gains, 2);
num_experiments = size(corrected_gains, 3);

if length(isL) ~= num_experiments || length(isH) ~= num_experiments
    error('Length of isL/isH must match the experiment dimension of corrected_gains.');
end

if all(~isL) && all(~isH)
    warning('Both isL and isH are all false; testing all experiments together.');
end

% Average over the earliest 5 time bins or all available bins if fewer.
use_bins = 1:min(5, num_time_bins);
session_gain = squeeze(nanmean(corrected_gains(:, use_bins, :), 2));

fprintf('\n=== Generic Spatial Variability Test ===\n');
fprintf('Spatial bands: %d\n', num_bands);
fprintf('Experiments: %d (L=%d, H=%d)\n\n', num_experiments, nnz(isL), nnz(isH));

% Run the permutation test for each group.
group_names = {'All', 'L', 'H'};
group_masks = {true(1, num_experiments), isL(:)', isH(:)'};
results_rows = {};

for gi = 1:numel(group_names)
    mask = group_masks{gi};
    if sum(mask) < 2
        continue;
    end

    group_gain = session_gain(:, mask);
    [obs_score, p_val, null_scores] = permutation_spatial_variability_test(group_gain, 5000);

    results_rows(end+1,:) = {group_names{gi}, sum(mask), obs_score, mean(null_scores), std(null_scores), p_val};

    fprintf('Group: %s\n', group_names{gi});
    fprintf(' - Observed spatial variability score: %.4f\n', obs_score);
    fprintf(' - Null mean: %.4f, null SD: %.4f\n', mean(null_scores), std(null_scores));
    fprintf(' - Permutation p-value: %.4f\n\n', p_val);
end

stats_tbl = cell2table(results_rows, 'VariableNames', {'Group', 'NExperiments', 'ObservedScore', 'NullMean', 'NullSD', 'pValue'});
writetable(stats_tbl, 'spatial_variability_test_results.csv');
fprintf('Saved summary CSV: spatial_variability_test_results.csv\n');

function [obs_score, p_val, null_scores] = permutation_spatial_variability_test(gain_mat, n_perm)
    % gain_mat: [bands x experiments]
    % Score = variance of gains across spatial bands for each experiment,
    % then average across experiments. This is shape-agnostic.

    n_exp = size(gain_mat, 2);
    scores = nan(1, n_exp);

    for e = 1:n_exp
        x = gain_mat(:, e);
        valid = isfinite(x);
        if sum(valid) < 3
            continue;
        end
        scores(e) = var(x(valid), 1);
    end

    obs_score = nanmean(scores);
    null_scores = nan(1, n_perm);

    for p = 1:n_perm
        perm_scores = nan(1, n_exp);
        for e = 1:n_exp
            x = gain_mat(:, e);
            valid = isfinite(x);
            if sum(valid) < 3
                continue;
            end
            x_valid = x(valid);
            x_perm = x_valid(randperm(numel(x_valid)));
            perm_scores(e) = var(x_perm, 1);
        end
        null_scores(p) = nanmean(perm_scores);
    end

    p_val = (1 + sum(null_scores >= obs_score)) / (n_perm + 1);
end
