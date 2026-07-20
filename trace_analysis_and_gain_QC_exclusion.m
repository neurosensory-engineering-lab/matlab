%% TONE-MODULATION: STABILITY & RESPONDER FILTERS (V3.1)
% Master Filter applied to Ring 1:
% 1. Baseline Stability: SD of frames 1-55 must be below THRESH_SD.
% 2. Physiological Response: Tone-evoked Peak Z-Score must be above FINAL_Z.

%% 1. CONFIGURATION
THRESH_SD = 10;   % <--- TWEAK THIS: Max allowed baseline volatility (std dev)
FINAL_Z   = 2;    % <--- TWEAK THIS: Min Z-score for tone-response
expID = 'H4';       

if ~exist('target_results', 'var')
    load('FUS_WideField_TargetResults_FullTraces.mat');
end

% Styling and indices
spatial_colors = [0.85, 0.10, 0.10; 1.00, 0.50, 0.00; 0.90, 0.85, 0.10; 0.10, 0.70, 0.20; 0.00, 0.45, 0.75];
gray_shades = [0, 0, 0; 0.2, 0.2, 0.2; 0.4, 0.4, 0.4; 0.6, 0.6, 0.6; 0.75, 0.75, 0.75];
baseline_idx = 1:55; 
tone_onset = 55;

figure('Color', 'w', 'Name', ['Master QC Filter: ' expID], 'Position', [50 50 1550 900]);
hold on;

%% 2. DUAL-GATE MASTER FILTER (RING 1)
% Helper function to apply both Stability and Responder gates
applyMasterQC = @(traces) cellfun(@(x) x, num2cell( ...
    (std(traces(baseline_idx, :), [], 1) <= THRESH_SD) & ... % Gate 1: Stability
    ((max(traces(tone_onset:end, :), [], 1) - mean(traces(baseline_idx, :), 1)) ./ ...
     (std(traces(baseline_idx, :), [], 1) + eps) >= FINAL_Z) ... % Gate 2: Response
));

% Pre-FUS Master
m_pre_keep = applyMasterQC(target_results.(expID).spatial(1).pre_raw_traces);

% Post-FUS Bins Master
num_bins = length(target_results.(expID).spatial(1).temporal);
bin_keeps = cell(1, num_bins);
for b = 1:num_bins
    bin_keeps{b} = applyMasterQC(target_results.(expID).spatial(1).temporal(b).all_traces);
end

%% 3. PLOTTING (Grand Averages + Bins)
h_grand = gobjects(1,5);
for p = 1:5
    % --- PRE-FUS ---
    pre_raw = target_results.(expID).spatial(p).pre_raw_traces;
    if any(m_pre_keep)
        plot(mean(pre_raw(:, m_pre_keep), 2), '-', 'Color', gray_shades(p,:), 'LineWidth', 3.0); 
    end
    
    % --- POST-FUS ---
    all_valid = [];
    for b = 1:num_bins
        if any(bin_keeps{b})
            valid = target_results.(expID).spatial(p).temporal(b).all_traces(:, bin_keeps{b});
            all_valid = [all_valid, valid];
            % Thin bin lines
            plot(mean(valid, 2), ':', 'Color', spatial_colors(p,:), 'LineWidth', 1.0, 'HandleVisibility', 'off');
        end
    end
    
    % Thick Grand Post-FUS
    if ~isempty(all_valid)
        h_grand(p) = plot(mean(all_valid, 2), '-', 'Color', spatial_colors(p,:), 'LineWidth', 5.0); 
    end
end

%% 4. FORMATTING & QC STATS
grid on; set(gca, 'FontSize', 14);
line([55 55], ylim, 'Color', 'b', 'LineStyle', '--');

% Summary Stats with both rejection reasons
total_post = sum(cellfun(@length, bin_keeps));
passed_post = sum(cellfun(@sum, bin_keeps));

stats_str = { ...
    '\bfMaster QC Summary\rm', ...
    sprintf('Stability (SD) < %.3f', THRESH_SD), ...
    sprintf('Response (Z)  > %.1f', FINAL_Z), ...
    '', ...
    sprintf('Trials Kept: %d/%d', passed_post, total_post), ...
    sprintf('Retention:  %.1f%%', (passed_post/total_post)*100), ...
    '', ...
    '\bfVisual Mapping\rm', ...
    'Thick Grays: Pre-FUS Grand', ...
    'Thick Color: Post-FUS Grand', ...
    'Thin Dots:   Individual Bins' ...
};

annotation('textbox', [0.83, 0.25, 0.16, 0.4], 'String', stats_str, ...
    'BackgroundColor', [0.96 0.96 0.96], 'FontName', 'monospaced', 'FitBoxToText', 'on');

legend(h_grand(ishandle(h_grand)), ring_names, 'Location', 'northeastoutside');
xlim([40 110]); hold off;