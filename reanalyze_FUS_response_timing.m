%% Re-analyze FUS response timing from saved trial traces
% Requires all_results from PC_based_QC_control_stats_plotting_and_export.m.
% The saved traces are already dF/F. This script recomputes baseline QC and
% does not reuse post m_keep masks, which were made with the older Z >= 5 gate.

if ~exist('all_results', 'var') || ~isstruct(all_results)
    error('Load all_results into the workspace before running this script.');
end

fs = 18.57;
baselineFrames = 50:55;
toneOnsetFrame = 56;
responseFrames = 56:100;
baselineSdLimit = 0.5;
zThreshold = 2;
minConsecutiveFrames = 2;
driftWindow = round(10 * fs);

expIDs = fieldnames(all_results);
records = struct('Experiment', {}, 'Group', {}, 'SpatialIndex', {}, ...
    'Phase', {}, 'Bin', {}, 'TrialsAvailable', {}, 'TrialsBaselineQC', {}, ...
    'OnsetMs', {}, 'PeakLatencyMs', {}, 'PeakDFF', {}, 'PeakZ', {}, ...
    'DurationMs', {});

for e = 1:numel(expIDs)
    expID = expIDs{e};
    experiment = all_results.(expID);
    if ~isfield(experiment, 'spatial')
        warning('Skipping %s: no spatial results found.', expID);
        continue;
    end

    group = upper(expID(1));
    for s = 1:numel(experiment.spatial)
        spatialData = experiment.spatial(s);

        if isfield(spatialData, 'pre_raw_traces') && ...
                ~isempty(spatialData.pre_raw_traces)
            records(end+1) = measure_trace_set(spatialData.pre_raw_traces, ...
                expID, group, s, 'Pre', 0, baselineFrames, responseFrames, ...
                toneOnsetFrame, fs, driftWindow, baselineSdLimit, ...
                zThreshold, minConsecutiveFrames); %#ok<SAGROW>
        end

        if ~isfield(spatialData, 'temporal') || isempty(spatialData.temporal)
            continue;
        end
        for b = 1:numel(spatialData.temporal)
            temporalData = spatialData.temporal(b);
            if isfield(temporalData, 'post_raw_traces')
                traces = temporalData.post_raw_traces;
            elseif isfield(temporalData, 'all_traces')
                traces = temporalData.all_traces;
            else
                continue;
            end
            if isempty(traces), continue; end

            records(end+1) = measure_trace_set(traces, expID, group, s, ...
                'Post', b, baselineFrames, responseFrames, toneOnsetFrame, ...
                fs, driftWindow, baselineSdLimit, zThreshold, ...
                minConsecutiveFrames); %#ok<SAGROW>
        end
    end
end

if isempty(records)
    error('No pre_raw_traces or post traces were found in all_results.');
end

peakTimingByExperiment = struct2table(records);
peakTimingGroupSummary = summarize_timing(peakTimingByExperiment);

writetable(peakTimingByExperiment, 'FUS_peak_timing_by_experiment.csv');
writetable(peakTimingGroupSummary, 'FUS_peak_timing_group_summary.csv');

disp(peakTimingByExperiment);
disp(peakTimingGroupSummary);
fprintf(['Saved FUS_peak_timing_by_experiment.csv and ' ...
    'FUS_peak_timing_group_summary.csv.\n']);

function result = measure_trace_set(traces, expID, group, spatialIndex, ...
        phase, bin, baselineFrames, responseFrames, toneOnsetFrame, fs, ...
        driftWindow, baselineSdLimit, zThreshold, minConsecutiveFrames)
    traces = double(traces);
    nFrames = size(traces, 1);
    nTrials = size(traces, 2);
    result = struct('Experiment', expID, 'Group', group, ...
        'SpatialIndex', spatialIndex, 'Phase', phase, 'Bin', bin, ...
        'TrialsAvailable', nTrials, 'TrialsBaselineQC', 0, ...
        'OnsetMs', NaN, 'PeakLatencyMs', NaN, 'PeakDFF', NaN, ...
        'PeakZ', NaN, 'DurationMs', NaN);

    if max([baselineFrames, responseFrames]) > nFrames
        warning('Skipping %s %s ROI %d bin %d: trace has only %d frames.', ...
            expID, phase, spatialIndex, bin, nFrames);
        return;
    end

    centeredTraces = nan(nFrames, nTrials);
    baselineSd = nan(1, nTrials);
    for t = 1:nTrials
        trace = traces(:, t);
        if any(~isfinite(trace)), continue; end
        trend = conv(trace, ones(driftWindow, 1) / driftWindow, 'same');
        trace = trace - trend;
        trace = trace - mean(trace(baselineFrames));
        baselineSd(t) = std(trace(baselineFrames));
        centeredTraces(:, t) = trace;
    end

    keep = isfinite(baselineSd) & baselineSd <= baselineSdLimit;
    result.TrialsBaselineQC = sum(keep);
    if ~any(keep), return; end

    meanTrace = mean(centeredTraces(:, keep), 2);
    pooledBaselineSd = sqrt(mean(baselineSd(keep).^2));
    if ~isfinite(pooledBaselineSd) || pooledBaselineSd <= 0, return; end

    response = meanTrace(responseFrames);
    responseZ = response / pooledBaselineSd;
    [result.PeakDFF, peakIndex] = max(response);
    peakFrame = responseFrames(peakIndex);
    result.PeakLatencyMs = (peakFrame - toneOnsetFrame) * 1000 / fs;
    result.PeakZ = max(responseZ);

    aboveThreshold = responseZ > zThreshold;
    runStarts = find(diff([false; aboveThreshold(:)]) == 1);
    runEnds = find(diff([aboveThreshold(:); false]) == -1);
    runIndex = find(runEnds - runStarts + 1 >= minConsecutiveFrames, 1);
    if isempty(runIndex), return; end

    onsetFrame = responseFrames(runStarts(runIndex));
    runLength = runEnds(runIndex) - runStarts(runIndex) + 1;
    result.OnsetMs = (onsetFrame - toneOnsetFrame) * 1000 / fs;
    result.DurationMs = runLength * 1000 / fs;
end

function summary = summarize_timing(metrics)
    [groupIndex, groups, spatialIndices, phases, bins] = findgroups( ...
        metrics.Group, metrics.SpatialIndex, metrics.Phase, metrics.Bin);
    nGroups = numel(groups);
    summaryRows = repmat(struct('Group', '', 'SpatialIndex', 0, ...
        'Phase', '', 'Bin', 0, 'NExperiments', 0, 'NOnset', 0, ...
        'NPeakLatency', 0, 'NPeakDFF', 0, 'NDuration', 0, ...
        'OnsetMeanMs', NaN, 'OnsetSDMs', NaN, ...
        'PeakLatencyMeanMs', NaN, 'PeakLatencySDMs', NaN, ...
        'PeakDFFMean', NaN, 'PeakDFFSD', NaN, ...
        'DurationMeanMs', NaN, 'DurationSDMs', NaN), nGroups, 1);

    for g = 1:nGroups
        rows = groupIndex == g;
        summaryRows(g).Group = groups{g};
        summaryRows(g).SpatialIndex = spatialIndices(g);
        summaryRows(g).Phase = phases{g};
        summaryRows(g).Bin = bins(g);
        summaryRows(g).NExperiments = sum(rows);
        summaryRows(g).NOnset = sum(rows & isfinite(metrics.OnsetMs));
        summaryRows(g).NPeakLatency = sum(rows & isfinite(metrics.PeakLatencyMs));
        summaryRows(g).NPeakDFF = sum(rows & isfinite(metrics.PeakDFF));
        summaryRows(g).NDuration = sum(rows & isfinite(metrics.DurationMs));
        [summaryRows(g).OnsetMeanMs, summaryRows(g).OnsetSDMs] = ...
            mean_and_sd(metrics.OnsetMs(rows));
        [summaryRows(g).PeakLatencyMeanMs, summaryRows(g).PeakLatencySDMs] = ...
            mean_and_sd(metrics.PeakLatencyMs(rows));
        [summaryRows(g).PeakDFFMean, summaryRows(g).PeakDFFSD] = ...
            mean_and_sd(metrics.PeakDFF(rows));
        [summaryRows(g).DurationMeanMs, summaryRows(g).DurationSDMs] = ...
            mean_and_sd(metrics.DurationMs(rows));
    end
    summary = struct2table(summaryRows);
end

function [valueMean, valueSd] = mean_and_sd(values)
    values = values(isfinite(values));
    if isempty(values)
        valueMean = NaN;
        valueSd = NaN;
    else
        valueMean = mean(values);
        if numel(values) > 1
            valueSd = std(values);
        else
            valueSd = NaN;
        end
    end
end