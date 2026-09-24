%% EXPORT DUAL-TONE WORKSPACE DATA
% Run this script after dual_tone_experiment_analysis.m has completed.
% It exports existing workspace data without rerunning image analysis.

outputRoot = fullfile(pwd, 'dual_tone_workspace_export');
csvOutputDir = fullfile(outputRoot, 'csv');
maskOutputDir = fullfile(outputRoot, 'pc_masks');

if ~exist(csvOutputDir, 'dir')
    [created, message] = mkdir(csvOutputDir);
    if ~created
        error('Could not create CSV output folder: %s', message);
    end
end
if ~exist(maskOutputDir, 'dir')
    [created, message] = mkdir(maskOutputDir);
    if ~created
        error('Could not create mask output folder: %s', message);
    end
end

requiredVars = {'G10_all', 'G30_all', 'uniqueExps'};
for v = 1:numel(requiredVars)
    if ~exist(requiredVars{v}, 'var')
        error('Workspace variable "%s" is missing. Run dual_tone_experiment_analysis.m first.', ...
            requiredVars{v});
    end
end

[numExps, numBins] = size(G10_all);
if ~isequal(size(G30_all), [numExps, numBins])
    error('G10_all and G30_all must have the same dimensions.');
end
if numel(uniqueExps) ~= numExps
    error('uniqueExps must contain one experiment ID per row of G10_all and G30_all.');
end

if ~exist('valid_mask', 'var')
    valid_mask = ~isnan(G10_all) & ~isnan(G30_all);
end
if ~isequal(size(valid_mask), [numExps, numBins])
    error('valid_mask must have the same dimensions as G10_all.');
end

cleanG10 = G10_all;
cleanG30 = G30_all;
cleanG10(~valid_mask) = NaN;
cleanG30(~valid_mask) = NaN;

if ~exist('mean10', 'var')
    mean10 = nanmean(cleanG10, 1);
end
if ~exist('mean30', 'var')
    mean30 = nanmean(cleanG30, 1);
end
if ~exist('sem10', 'var')
    sem10 = nanstd(cleanG10, [], 1) ./ sqrt(sum(~isnan(cleanG10), 1));
end
if ~exist('sem30', 'var')
    sem30 = nanstd(cleanG30, [], 1) ./ sqrt(sum(~isnan(cleanG30), 1));
end

experimentNames = cellstr(string(uniqueExps(:)));

rawExperiment = cell(numExps * numBins * 2, 1);
rawCondition = cell(numExps * numBins * 2, 1);
rawTimeBin = zeros(numExps * numBins * 2, 1);
rawGain = nan(numExps * numBins * 2, 1);
rawPlotIncluded = false(numExps * numBins * 2, 1);
rawCleanGain = nan(numExps * numBins * 2, 1);

row = 0;
for b = 1:numBins
    for idx = 1:numExps
        row = row + 1;
        rawExperiment{row} = experimentNames{idx};
        rawCondition{row} = '10 kHz';
        rawTimeBin(row) = b;
        rawGain(row) = G10_all(idx, b);
        rawCleanGain(row) = cleanG10(idx, b);
        rawPlotIncluded(row) = valid_mask(idx, b);

        row = row + 1;
        rawExperiment{row} = experimentNames{idx};
        rawCondition{row} = '30 kHz';
        rawTimeBin(row) = b;
        rawGain(row) = G30_all(idx, b);
        rawCleanGain(row) = cleanG30(idx, b);
        rawPlotIncluded(row) = valid_mask(idx, b);
    end
end

rawPlotData = table(rawExperiment, rawCondition, rawTimeBin, rawGain, ...
    rawCleanGain, rawPlotIncluded, ...
    'VariableNames', {'Experiment', 'Condition', 'TimeBin', 'RawGain', ...
    'CleanGainUsedForPlot', 'PlotIncluded'});
writetable(rawPlotData, fullfile(csvOutputDir, 'raw_plot_datapoints.csv'));

cleanPlotData = rawPlotData(rawPlotData.PlotIncluded, :);
writetable(cleanPlotData, fullfile(csvOutputDir, 'clean_plot_datapoints.csv'));

averagedPlotData = table((1:numBins)', mean10(:), sem10(:), mean30(:), sem30(:), ...
    sum(~isnan(cleanG10), 1)', sum(~isnan(cleanG30), 1)', ...
    'VariableNames', {'TimeBin', 'Mean10kHz', 'SEM10kHz', 'Mean30kHz', ...
    'SEM30kHz', 'N10kHz', 'N30kHz'});
writetable(averagedPlotData, fullfile(csvOutputDir, 'averaged_plot_data.csv'));

pValues = nan(numBins, 1);
deltaGains = nan(numBins, 1);
nPaired = zeros(numBins, 1);
if exist('dual_tone_interaction_stats', 'var')
    for b = 1:numBins
        statName = sprintf('Bin%d_10kHz_vs_30kHz', b);
        if isfield(dual_tone_interaction_stats, statName)
            stat = dual_tone_interaction_stats.(statName);
            pValues(b) = stat.p_value;
            deltaGains(b) = stat.delta_gain;
            nPaired(b) = stat.n_samples;
        end
    end
else
    for b = 1:numBins
        pairedValues = cleanG30(:, b) - cleanG10(:, b);
        pairedValues = pairedValues(~isnan(pairedValues));
        nPaired(b) = numel(pairedValues);
        if nPaired(b) >= 2
            deltaGains(b) = mean(pairedValues);
            if std(pairedValues) > 0
                tStat = deltaGains(b) / (std(pairedValues) / sqrt(nPaired(b)));
                pValues(b) = 2 * (1 - tcdf(abs(tStat), nPaired(b) - 1));
            else
                pValues(b) = 1;
            end
        end
    end
end

statisticsData = table((1:numBins)', deltaGains, pValues, nPaired, ...
    'VariableNames', {'TimeBin', 'DeltaGain_30minus10', 'PairedPValue', 'NPaired'});
writetable(statisticsData, fullfile(csvOutputDir, 'statistics.csv'));

writematrix(G10_all, fullfile(csvOutputDir, 'G10_all_raw_matrix.csv'));
writematrix(G30_all, fullfile(csvOutputDir, 'G30_all_raw_matrix.csv'));
writematrix(valid_mask, fullfile(csvOutputDir, 'valid_mask.csv'));

maskCount = 0;
for idx = 1:numExps
    baseID = char(experimentNames{idx});
    safeBaseID = regexprep(baseID, '[^A-Za-z0-9_-]', '_');
    var10 = sprintf('PC1_%s_10kHz_norm_upscaled', baseID);
    var30 = sprintf('PC1_%s_30kHz_norm_upscaled', baseID);

    if ~exist(var10, 'var')
        var10 = sprintf('PC1_%s_10KHz_norm_upscaled', baseID);
    end
    if ~exist(var30, 'var')
        var30 = sprintf('PC1_%s_30KHz_norm_upscaled', baseID);
    end

    if exist(var10, 'var')
        pc1Map10 = eval(var10);
        imwrite(uint8(pc1Map10 > 0.9) * 255, ...
            fullfile(maskOutputDir, [safeBaseID '_PC1_10kHz_mask.tif']), 'tif');
        maskCount = maskCount + 1;
    else
        fprintf('Missing 10 kHz PC1 map for %s; no mask exported.\n', baseID);
    end

    if exist(var30, 'var')
        pc1Map30 = eval(var30);
        imwrite(uint8(pc1Map30 > 0.9) * 255, ...
            fullfile(maskOutputDir, [safeBaseID '_PC1_30kHz_mask.tif']), 'tif');
        maskCount = maskCount + 1;
    else
        fprintf('Missing 30 kHz PC1 map for %s; no mask exported.\n', baseID);
    end
end

fprintf('\nExport complete.\n');
fprintf('CSV files: %s\n', csvOutputDir);
fprintf('TIFF masks: %s\n', maskOutputDir);
fprintf('TIFF masks written: %d\n', maskCount);
