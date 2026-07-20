%% FAST RE-ANALYSIS & EXPORT (NO TIFF EXTRACTION)
% -------------------------------------------------------------------------
% Instantly re-calculates stats, plots the dashboard, and exports the CSV
% while EXCLUDING specific experiments. Runs in seconds.
% -------------------------------------------------------------------------

% 1. CONFIGURATION: Type the ID(s) of the experiment(s) you want to drop
bad_experiments = {'L1'}; % e.g., {'H3', 'L2'}

fprintf('\nLoading saved trace data...\n');
load('FUS_PC1_AllTraces_QC.mat', 'all_results');

% Get all experiments that were originally processed
all_exp_ids = fieldnames(all_results);

% Filter out the bad ones
valid_ids = setdiff(all_exp_ids, bad_experiments);
num_valid = length(valid_ids);
fprintf('Excluded %d experiment(s). Proceeding with %d valid experiments.\n', ...
    length(all_exp_ids) - num_valid, num_valid);

%% 2. RECONSTRUCT THE GAIN MATRIX
raw_gains = nan(5, 10, num_valid);
isC = false(num_valid, 1);
isL = false(num_valid, 1);
isH = false(num_valid, 1);

for r = 1:num_valid
    eID = valid_ids{r};
    
    % Re-identify group
    if startsWith(eID, 'C', 'IgnoreCase', true), isC(r) = true; end
    if startsWith(eID, 'L', 'IgnoreCase', true), isL(r) = true; end
    if startsWith(eID, 'H', 'IgnoreCase', true), isH(r) = true; end
    
    % Pull the raw gains directly from the saved struct
    for p = 1:5
        for b = 1:10
            try
                raw_gains(p, b, r) = all_results.(eID).spatial(p).temporal(b).raw_gain;
            catch
                % Leave as NaN if the bin didn't exist for some reason
            end
        end
    end
end

%% 3. CALCULATE BRACKET-SPECIFIC CONTROL RUNDOWN
bracket_labels = {'Top 10%', '80-90%', '70-80%', '60-70%', '50-60%'};
bracket_slopes = zeros(5, 1);
corrected_gains = nan(size(raw_gains));

for p = 1:5
    % Isolate Control gains for this specific bracket
    c_gains = squeeze(raw_gains(p, :, isC))'; % [num_controls x 10 bins]
    mean_drift = nanmean(c_gains, 1);
    valid_bins = find(~isnan(mean_drift));
    
    if length(valid_bins) > 1
        p_fit = polyfit(valid_bins, mean_drift(valid_bins), 1);
        bracket_slopes(p) = p_fit(1);
    end
    
    % Apply correction to ALL valid experiments for this bracket
    for b = 1:10
        expected_baseline = polyval([bracket_slopes(p), 1.0 - bracket_slopes(p)], b);
        offset = 1.0 - expected_baseline;
        corrected_gains(p, b, :) = raw_gains(p, b, :) + offset;
    end
end

%% 4. PLOT CLEAN DASHBOARD & EXPORT CSV
time_labels = {'Bin 1 (Trials 1-10)', 'Bin 2 (Trials 11-20)', 'Bin 3 (Trials 21-30)', ...
               'Bin 4 (Trials 31-40)', 'Bin 5 (Trials 41-50)', 'Session Average (Bins 1-5)'};
figS = figure(812); clf; set(figS, 'Color', 'w', 'Position', [20 20 1800 950]);
tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'loose');
title(tlo, 'FUS Gain vs PC1 (EXCLUDING BAD TARGETS)', 'FontSize', 24, 'FontWeight', 'bold');

results_cell = {};

for t = 1:6
    ax = nexttile; hold on; grid on;
    if t <= 5
        data_slice = squeeze(corrected_gains(:, t, :)); t_title = time_labels{t};
    else
        data_slice = squeeze(nanmean(corrected_gains(:, 1:5, :), 2)); t_title = time_labels{t};
    end
    
    max_panel_y = 1.5;
    for p = 1:5
        vL_raw = data_slice(p, isL); vL = vL_raw(~isnan(vL_raw));
        vH_raw = data_slice(p, isH); vH = vH_raw(~isnan(vH_raw));
        
        xL = p - 0.20; xH = p + 0.20;
        scatter(xL, vL, 30, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
        scatter(xH, vH, 30, [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
        
        mL = NaN; sdL = NaN; p_L = NaN; mH = NaN; sdH = NaN; p_H = NaN; p_anova = NaN;
        
        if ~isempty(vL)
            mL = mean(vL); sdL = std(vL);
            errorbar(xL, mL, sdL, 'b', 'LineWidth', 2.5, 'Marker', 's', 'MarkerSize', 8);
            if length(vL) > 2
                [~, p_L] = safe_1sample_ttest(vL, 1.0); fwL = 'normal'; txt_L = {sprintf('%.2f', mL)};
                if p_L < 0.05, fwL = 'bold'; txt_L{2} = inline_p_formatter(p_L); end
                text(xL - 0.12, mL, txt_L, 'FontSize', 12, 'Color', 'b', 'FontWeight', fwL, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
            end
        end
        
        if ~isempty(vH)
            mH = mean(vH); sdH = std(vH);
            errorbar(xH, mH, sdH, 'r', 'LineWidth', 2.5, 'Marker', 'o', 'MarkerSize', 8);
            if length(vH) > 2
                [~, p_H] = safe_1sample_ttest(vH, 1.0); fwH = 'normal'; txt_H = {sprintf('%.2f', mH)};
                if p_H < 0.05, fwH = 'bold'; txt_H{2} = inline_p_formatter(p_H); end
                text(xH + 0.12, mH, txt_H, 'FontSize', 12, 'Color', 'r', 'FontWeight', fwH, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            end
        end
        
        if length(vL) > 2 && length(vH) > 2
            [~, p_anova] = safe_2sample_ttest(vL, vH); 
            if p_anova < 0.05
                top_of_data = max(mL + sdL, mH + sdH); if isnan(top_of_data), top_of_data = 1.5; end
                bracket_y = top_of_data + 0.25; max_panel_y = max(max_panel_y, bracket_y); 
                plot([xL, xL, xH, xH], [bracket_y-0.05, bracket_y, bracket_y, bracket_y-0.05], '-k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
                text(p, bracket_y + 0.1, inline_p_formatter(p_anova), 'FontSize', 13, 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                max_panel_y = max(max_panel_y, bracket_y + 0.2);
            end
        end
        max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);
        results_cell(end+1, :) = {time_labels{t}, bracket_labels{p}, mL, sdL, p_L, mH, sdH, p_H, p_anova};
    end
    
    title(t_title, 'FontSize', 16, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:5, 'XTickLabel', bracket_labels, 'FontSize', 13, 'FontWeight', 'bold');
    xlim([0.3, 5.7]); ylim([0, max(2.5, max_panel_y + 0.2)]); 
    line([0 6], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
    if t == 1 || t == 4, ylabel('Corrected Gain Ratio', 'FontSize', 14, 'FontWeight', 'bold'); end
end

dummy_L = plot(NaN,NaN,'sb','MarkerFaceColor','b', 'MarkerSize', 8); dummy_H = plot(NaN,NaN,'or','MarkerFaceColor','r', 'MarkerSize', 8);
dummy_C = plot(NaN,NaN,'--','Color',[0.2 0.7 0.2],'LineWidth',2.0); dummy_B = plot(NaN,NaN,'-k','LineWidth',1.5);
legend([dummy_L, dummy_H, dummy_C, dummy_B], {'Low Power (L)', 'High Power (H)', 'Control Baseline', 'ANOVA (L vs H)'}, 'Location', 'northeast', 'FontSize', 13);

col_names = {'Time_Bin', 'PC1_Bracket', 'Low_Mean_Gain', 'Low_SD', 'Low_vs_Baseline_pval', 'High_Mean_Gain', 'High_SD', 'High_vs_Baseline_pval', 'Low_vs_High_pval'};
StatsTable = cell2table(results_cell, 'VariableNames', col_names);
writetable(StatsTable, 'FUS_PC1_Functional_Stats_Summary_UPDATED.csv');
fprintf('>>> SUCCESS: Updated Dashboard generated and data exported to FUS_PC1_Functional_Stats_Summary_UPDATED.csv.\n\n');

%% --- STATS HELPER FUNCTIONS ---
function [h, p] = safe_1sample_ttest(x, m)
    x = x(:); n = length(x); if n < 2, h = 0; p = NaN; return; end
    t_stat = (mean(x) - m) / (std(x) / sqrt(n)); df = n - 1;
    p = betainc(df / (df + t_stat^2), df/2, 0.5); h = double(p < 0.05);
end

function [h, p] = safe_2sample_ttest(x, y)
    x = x(:); y = y(:); nx = length(x); ny = length(y); if nx < 2 || ny < 2, h=0; p=NaN; return; end
    mx = mean(x); my = mean(y); vx = var(x); vy = var(y);
    t_stat = (mx - my) / (sqrt(((nx-1)*vx + (ny-1)*vy)/(nx+ny-2)) * sqrt(1/nx + 1/ny));
    p = betainc((nx+ny-2) / ((nx+ny-2) + t_stat^2), (nx+ny-2)/2, 0.5); h = double(p < 0.05);
end

function p_str = inline_p_formatter(p_val)
    if p_val < 0.001, p_str = 'p<0.001'; else, p_str = sprintf('p=%.3f', p_val); end
end