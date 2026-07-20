%% FUS STATISTICAL EVOLUTION: L vs H vs CONTROL (V15.0)
% -------------------------------------------------------------------------
% Focus: Detailed Bin-by-Bin Gain + ANOVA Statistics
% Groups: L (Blue), H (Red), C (Green)
% -------------------------------------------------------------------------

%% 1. DATA EXTRACTION & GROUPING
if ~exist('target_results', 'var'), load('FUS_WideField_TargetResults_FullTraces.mat'); end
expIDs = fieldnames(target_results);
labels = {'0-250', '250-500', '500-750', '750-1000', '1000-1250'};
resp_win = 56:100; baseline_idx = 50:55;

% Grouping Logic
isL = startsWith(expIDs, 'L', 'IgnoreCase', true);
isH = startsWith(expIDs, 'H', 'IgnoreCase', true);
isC = startsWith(expIDs, 'C', 'IgnoreCase', true);

% Math Setup
fs = 18.57; drift_sec = 10; drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');

num_exps = numel(expIDs);
num_bins_to_plot = 5; % We will plot Bins 1-5 + Session Avg
all_gains = nan(5, num_bins_to_plot, num_exps);

for e = 1:num_exps
    id = expIDs{e};
    for p = 1:5
        pre_c = detrendTrace(mean(target_results.(id).spatial(p).pre_raw_traces, 2));
        denom = max(pre_c(resp_win) - mean(pre_c(baseline_idx)));
        
        % Extract up to the first 5 bins
        avail_bins = numel(target_results.(id).spatial(p).temporal);
        for b = 1:min(avail_bins, num_bins_to_plot)
            post_raw = target_results.(id).spatial(p).temporal(b).all_traces;
            if isempty(post_raw), continue; end
            post_c = detrendTrace(mean(post_raw, 2));
            numr = max(post_c(resp_win) - mean(post_c(baseline_idx)));
            all_gains(p, b, e) = numr / (denom + eps);
        end
    end
end

%% 2. MULTI-BIN STATISTICAL PLOTTING
figS = figure(604); clf; set(figS, 'Color', 'w', 'Position', [20 20 1800 950]);
tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'loose'); % 6 subplots
title(tlo, 'Spatial Gain Evolution & Statistical Significance (L vs H vs Control)', 'FontSize', 22);

for t = 1:6 % 5 Bins + 1 Session Avg
    ax = nexttile; hold on; grid on;
    
    if t <= 5
        data_slice = squeeze(all_gains(:, t, :));
        t_title = sprintf('Bin %d (Trials %d-%d)', t, (t-1)*10+1, t*10);
    else
        data_slice = squeeze(nanmean(all_gains, 2));
        t_title = 'Session Average (All Bins)';
    end
    
    % Plotting loop for the 3 groups
    for p = 1:5
        vL = data_slice(p, isL); vH = data_slice(p, isH); vC = data_slice(p, isC);
        
        % Scatter with Jitter (L=Blue, H=Red, C=Green)
        scatter(p-0.2, vL, 25, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility', 'off');
        scatter(p,     vH, 25, [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility', 'off');
        scatter(p+0.2, vC, 25, [0.2 0.7 0.2], 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility', 'off');
        
        % Means + SEM bars
        errorbar(p-0.2, nanmean(vL), std(vL,'omitnan')/sqrt(sum(~isnan(vL))), 'b', 'LineWidth', 2, 'Marker', 's');
        errorbar(p,     nanmean(vH), std(vH,'omitnan')/sqrt(sum(~isnan(vH))), 'r', 'LineWidth', 2, 'Marker', 'o');
        errorbar(p+0.2, nanmean(vC), std(vC,'omitnan')/sqrt(sum(~isnan(vC))), 'g', 'LineWidth', 2, 'Marker', '^');
        
        % --- STATISTICS: One-Way ANOVA ---
        group_data = [vL(:); vH(:); vC(:)];
        group_ids = [ones(size(vL(:))); 2*ones(size(vH(:))); 3*ones(size(vC(:)))];
        
        valid_idx = ~isnan(group_data);
        if sum(valid_idx) > 5 % Only run if enough data points
            [p_val, tbl] = anonymous_anova(group_data(valid_idx), group_ids(valid_idx));
            if p_val < 0.05
                % Simple asterisk if any group is different
                text(p, max([vL, vH, vC, 3.2]), '*', 'FontSize', 20, 'HorizontalAlignment', 'center', 'Color', 'k');
            end
        end
    end
    
    title(t_title, 'FontSize', 15);
    set(ax, 'XTick', 1:5, 'XTickLabel', labels, 'FontSize', 12);
    ylim([0 4]); line([0 6], [1 1], 'Color', 'k', 'LineStyle', '--');
    if t == 1 || t == 4, ylabel('Gain Ratio'); end
end

% Manual Legend on the last plot
legend({'Low Power (L)', 'High Power (H)', 'Control (C)'}, 'Position', [0.85 0.1 0.1 0.1]);

function [p, tbl] = anonymous_anova(x, g)
    % Internal helper to run anova1 without opening windows
    [p, tbl] = anova1(x, g, 'off');
end