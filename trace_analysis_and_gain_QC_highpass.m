%% SPATIAL RING ANALYSIS: RESTORATION LEVELED (V11.0)
% -------------------------------------------------------------------------
% This version restores the exact math/QC from the early successful versions
% while maintaining the Tiled Layout for legibility.
% -------------------------------------------------------------------------

%% 1. CONFIGURATION & DATA LOADING
fs = 18.57;            
drift_sec = 10;         
THRESH_SD = 0.5;        
FINAL_Z   = 5.0;        % RE-ENFORCED STRICT GATE
expID = 'H1';          

if ~exist('target_results', 'var')
    load('FUS_WideField_TargetResults_FullTraces.mat');
end

drift_window = round(drift_sec * fs);
baseline_idx = 50:55; 
tone_onset = 55;
labels = {'0-250 \mum', '250-500 \mum', '500-750 \mum', '750-1000 \mum', '1000-1250 \mum'};

%% 2. RESTORED QC ENGINE (ORIGINAL MATH)
% Exact detrending logic from V1.0
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');

num_bins = length(target_results.(expID).spatial(1).temporal);
bin_keeps = cell(1, num_bins);

% Pre-FUS Reference Mask (Strict SD check)
pre_r1 = target_results.(expID).spatial(1).pre_raw_traces;
m_pre_keep = false(1, size(pre_r1, 2));
for t = 1:size(pre_r1, 2)
    tr = detrendTrace(pre_r1(:,t)); 
    tr = tr - mean(tr(baseline_idx)); % Pinned to zero at baseline
    if std(tr(baseline_idx)) <= THRESH_SD, m_pre_keep(t) = true; end
end

% Post-FUS Mask (Strict Z > 5.0 Gate)
for b = 1:num_bins
    mask = false(1, size(target_results.(expID).spatial(1).temporal(b).all_traces, 2));
    for t = 1:length(mask)
        raw_tr = target_results.(expID).spatial(1).temporal(b).all_traces(:,t);
        tr = detrendTrace(raw_tr);
        tr = tr - mean(tr(baseline_idx)); % Subtraction must happen AFTER detrending
        
        % Original Z-Score calculation
        sd_base = std(tr(baseline_idx));
        peak_resp = max(tr(tone_onset+1:end));
        z_score = (peak_resp - mean(tr(baseline_idx))) / (sd_base + eps);
        
        if sd_base <= THRESH_SD && z_score >= FINAL_Z
            mask(t) = true; 
        end
    end
    bin_keeps{b} = mask;
end

%% 3. RESTORED TILED PLOTTING
figS = figure(502); clf; 
set(figS, 'Color', 'w', 'Position', [50 50 1400 950]);
tlo = tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'loose');
title(tlo, ['Strict Restoration Analysis: ' expID ' (Z > ' num2str(FINAL_Z) ')'], 'FontSize', 22);

% High-contrast Blue Gradient
time_cmap = [0.8, 0.9, 1.0; 0.5, 0.7, 1.0; 0.2, 0.4, 0.8; 0.0, 0.2, 0.5]; 

for p = 1:5
    ax = nexttile; hold(ax, 'on'); grid(ax, 'on');
    
    % --- Step 1: Baseline Reference ---
    raw_pre = target_results.(expID).spatial(p).pre_raw_traces(:, m_pre_keep);
    if ~isempty(raw_pre)
        c_pre = detrendTrace(mean(raw_pre,2));
        plot(ax, c_pre - mean(c_pre(baseline_idx)), 'k-', 'LineWidth', 3);
    end
    
    % --- Step 2: Bins ---
    valid_idx = find(cellfun(@(x) any(x), bin_keeps));
    num_v = length(valid_idx);
    
    for i = 1:num_v
        b = valid_idx(i);
        v_raw = target_results.(expID).spatial(p).temporal(b).all_traces(:, bin_keeps{b});
        if ~isempty(v_raw)
            bin_c = detrendTrace(mean(v_raw,2)); 
            bin_c = bin_c - mean(bin_c(baseline_idx)); % Hard baseline pin
            
            c_idx = ceil((i/num_v) * size(time_cmap,1));
            plot(ax, bin_c, 'Color', time_cmap(c_idx,:), 'LineWidth', 2.5);
        end
    end
    
    % --- Fixed Formatting ---
    title(ax, labels{p}, 'FontSize', 16, 'FontWeight', 'bold');
    xlim(ax, [30 105]); ylim(ax, [-0.05 0.35]); % Tighter X-axis for better peak visibility
    set(ax, 'FontSize', 14, 'LineWidth', 1.5, 'TickDir', 'out');
    line(ax, [55 55], ylim(ax), 'Color', [0.5 0.5 0.5], 'LineStyle', '--');
end

% Manual Legend Tile
axL = nexttile; axis(axL, 'off');
text(axL, 0.1, 0.8, '\bfLegend:\rm', 'FontSize', 16);
plot(axL, [0.1 0.3], [0.65 0.65], 'k-', 'LineWidth', 3); text(axL, 0.35, 0.65, 'Pre-FUS Baseline', 'FontSize', 14);
plot(axL, [0.1 0.3], [0.5 0.5], 'Color', time_cmap(1,:), 'LineWidth', 2.5); text(axL, 0.35, 0.5, 'Early Post-FUS', 'FontSize', 14);
plot(axL, [0.1 0.3], [0.35 0.35], 'Color', time_cmap(end,:), 'LineWidth', 2.5); text(axL, 0.35, 0.35, 'Late Post-FUS', 'FontSize', 14);

fprintf('Restoration Analysis V11.0 Complete.\n');