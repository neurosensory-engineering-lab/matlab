%% INTERACTIVE FUS TRACE VIEWER (v2.4 - WITH EXCLUSION STATS)
% Use this to tweak QC thresholds and visualize inclusion/exclusion rates.

%% 1. LOAD DATA
if ~exist('target_results', 'var')
    fprintf('Loading data... please wait.\n');
    load('FUS_WideField_TargetResults_FullTraces.mat');
end

%% 2. SET YOUR PARAMETERS
SNR_THRESH = 8.0;       % Your "On-the-fly" QC tweak
EXP_TO_VIEW = 'H2';     % Options: 'C1'-'C3', 'L1'-'L9', 'H1'-'H4'
RING_TO_VIEW = 1;       % 1 (Center) to 5 (Outermost)

%% 3. PLOTTING SETUP
fig = figure(101); 
set(fig, 'Color', 'w', 'Position', [100, 100, 1000, 650]);
clf;

expData = target_results.(EXP_TO_VIEW).spatial(RING_TO_VIEW).temporal;
numBins = length(expData);
colors = jet(numBins); 

hold on;
plotHandles = [];
legendEntries = {};

% Counters for global exclusion stats
total_trials_in_exp = 0;
total_passed_qc = 0;

%% 4. PROCESS BINS
for b = 1:numBins
    traces = expData(b).all_traces;     
    snrs = expData(b).snr_metadata;     
    
    n_total = length(snrs);
    keep_idx = snrs >= SNR_THRESH;
    n_pass = sum(keep_idx);
    n_fail = n_total - n_pass;
    
    % Update global counters
    total_trials_in_exp = total_trials_in_exp + n_total;
    total_passed_qc = total_passed_qc + n_pass;
    
    if n_pass > 0
        clean_avg = mean(traces(:, keep_idx), 2);
        
        p = plot(clean_avg, 'Color', colors(b,:), 'LineWidth', 2);
        plotHandles(end+1) = p;
        
        % Legend shows: Passed / Total (Excluded)
        legendEntries{end+1} = sprintf('Bin %d: %d/%d pass (%d excl)', ...
            b, n_pass, n_total, n_fail);
    end
end

%% 5. VISUAL ANNOTATIONS & STATS BOX
grid on; box off;
yl = ylim;

% Stimulus Indicator
line([55 55], yl, 'Color', [0.5 0.5 0.5], 'LineStyle', '--', 'LineWidth', 1.5);
text(56, yl(1) + 0.05*(yl(2)-yl(1)), 'Sonication', 'FontAngle', 'italic');

% --- NEW: STATS BOX (Top Left) ---
total_excl = total_trials_in_exp - total_passed_qc;
perc_kept = (total_passed_qc / total_trials_in_exp) * 100;

statsStr = { ...
    ['\bfData Inclusion Summary\rm'], ...
    ['Total Trials: ' num2str(total_trials_in_exp)], ...
    ['Passed QC: ' num2str(total_passed_qc)], ...
    ['Excluded: ' num2str(total_excl)], ...
    ['Retention: ' num2str(perc_kept, '%.1f') '%'] ...
};

% Create a text box in the upper left of the axes
annotation('textbox', [0.15, 0.75, 0.2, 0.15], 'String', statsStr, ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 10, 'FitBoxToText', 'on');

% Labels
xlabel('Frame Number (10Hz)');
ylabel('Corrected dF/F');
title(sprintf('Target: %s | Ring: %d | SNR Thresh: %.1f', EXP_TO_VIEW, RING_TO_VIEW, SNR_THRESH));

if ~isempty(plotHandles)
    legend(plotHandles, legendEntries, 'Location', 'eastoutside', 'FontName', 'monospaced');
else
    title('NO DATA PASSES CURRENT SNR THRESHOLD', 'Color', 'r');
end

hold off;