%% FUS STATS MASTER SCRIPT (V21.0): BULLETPROOF MATH + CLEAN PLOTS + CSV
% -------------------------------------------------------------------------
% 1. Uses custom safe_ttest to bypass broken path toolboxes (no negative p-values).
% 2. Generates the Clean Layout Dashboard (SD error bars, multiline text).
% 3. Automatically compiles and exports all exact stats to a CSV file.
% -------------------------------------------------------------------------

if ~exist('corrected_gains', 'var')
    error('Missing ''corrected_gains'' in workspace. Run extraction first.');
end

% Set up Labels and Figures
distance_labels = {'0-250', '250-500', '500-750', '750-1000', '1000-1250'};
time_labels = {'Bin 1 (Trials 1-10)', 'Bin 2 (Trials 11-20)', 'Bin 3 (Trials 21-30)', ...
               'Bin 4 (Trials 31-40)', 'Bin 5 (Trials 41-50)', 'Session Average (Bins 1-5)'};

figS = figure(807); clf; set(figS, 'Color', 'w', 'Position', [20 20 1800 950]);
tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'loose');
title(tlo, 'FUS Gain vs Distance (Safe Stats + Clean Layout + SD)', 'FontSize', 24, 'FontWeight', 'bold');

% Preallocate cell array for CSV export
results_cell = {};

for t = 1:6
    ax = nexttile; hold on; grid on;
    
    if t <= 5
        data_slice = squeeze(corrected_gains(:, t, :));
        t_title = time_labels{t};
    else
        data_slice = squeeze(nanmean(corrected_gains(:, 1:5, :), 2));
        t_title = time_labels{t};
    end

    max_panel_y = 1.5; % Track highest necessary feature to prevent squishing

    for p = 1:5
        % Isolate clean data
        vL_raw = data_slice(p, isL); vL = vL_raw(~isnan(vL_raw));
        vH_raw = data_slice(p, isH); vH = vH_raw(~isnan(vH_raw));
        
        xL = p - 0.20;
        xH = p + 0.20;
        
        % Plot Jittered Raw Data
        scatter(xL, vL, 30, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
        scatter(xH, vH, 30, [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
        
        % Initialize safe defaults for CSV table
        mL = NaN; sdL = NaN; p_L = NaN;
        mH = NaN; sdH = NaN; p_H = NaN;
        p_anova = NaN;
        
        %% --- LOW POWER STATS & ANNOTATIONS ---
        if ~isempty(vL)
            mL = mean(vL); sdL = std(vL);
            errorbar(xL, mL, sdL, 'b', 'LineWidth', 2.5, 'Marker', 's', 'MarkerSize', 8);
            
            if length(vL) > 2
                [~, p_L] = safe_1sample_ttest(vL, 1.0); 
                fwL = 'normal';
                txt_L = {sprintf('%.2f', mL)};
                
                if p_L < 0.05
                    fwL = 'bold';
                    txt_L{2} = inline_p_formatter(p_L);
                end
                
                % Push text strictly to the left of the data
                text(xL - 0.12, mL, txt_L, 'FontSize', 12, 'Color', 'b', 'FontWeight', fwL, ...
                    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
            end
        end
        
        %% --- HIGH POWER STATS & ANNOTATIONS ---
        if ~isempty(vH)
            mH = mean(vH); sdH = std(vH);
            errorbar(xH, mH, sdH, 'r', 'LineWidth', 2.5, 'Marker', 'o', 'MarkerSize', 8);
            
            if length(vH) > 2
                [~, p_H] = safe_1sample_ttest(vH, 1.0); 
                fwH = 'normal';
                txt_H = {sprintf('%.2f', mH)};
                
                if p_H < 0.05
                    fwH = 'bold';
                    txt_H{2} = inline_p_formatter(p_H);
                end
                
                % Push text strictly to the right of the data
                text(xH + 0.12, mH, txt_H, 'FontSize', 12, 'Color', 'r', 'FontWeight', fwH, ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            end
        end
        
        %% --- ANOVA BRACKETS (L vs H) ---
        if length(vL) > 2 && length(vH) > 2
            [~, p_anova] = safe_2sample_ttest(vL, vH); 
            
            if p_anova < 0.05
                % Calculate bracket height based on ERROR BARS, not scatter outliers
                top_of_data = max(mL + sdL, mH + sdH);
                if isnan(top_of_data), top_of_data = 1.5; end
                
                bracket_y = top_of_data + 0.25; 
                max_panel_y = max(max_panel_y, bracket_y); 
                
                plot([xL, xL, xH, xH], [bracket_y-0.05, bracket_y, bracket_y, bracket_y-0.05], '-k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
                
                % Print Exact p-value on top of bracket
                text(p, bracket_y + 0.1, inline_p_formatter(p_anova), 'FontSize', 13, 'Color', 'k', ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                
                max_panel_y = max(max_panel_y, bracket_y + 0.2);
            end
        end
        
        % Track overall max height for clean Y-axis scaling
        max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);
        
        % Append exact values to our master list for CSV export
        results_cell(end+1, :) = {time_labels{t}, distance_labels{p}, ...
                                  mL, sdL, p_L, mH, sdH, p_H, p_anova};
    end
    
    % Tile Formatting
    title(t_title, 'FontSize', 16, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:5, 'XTickLabel', distance_labels, 'FontSize', 13, 'FontWeight', 'bold');
    
    % Smart Axes Adjustments
    xlim([0.3, 5.7]); 
    ylim([0, max(2.5, max_panel_y + 0.2)]); 
    
    line([0 6], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
    if t == 1 || t == 4, ylabel('Corrected Gain Ratio', 'FontSize', 14, 'FontWeight', 'bold'); end
end

% Finalize Plot Legend
dummy_L = plot(NaN,NaN,'sb','MarkerFaceColor','b', 'MarkerSize', 8);
dummy_H = plot(NaN,NaN,'or','MarkerFaceColor','r', 'MarkerSize', 8);
dummy_C = plot(NaN,NaN,'--','Color',[0.2 0.7 0.2],'LineWidth',2.0);
dummy_B = plot(NaN,NaN,'-k','LineWidth',1.5);

legend([dummy_L, dummy_H, dummy_C, dummy_B], ...
    {'Low Power (L)', 'High Power (H)', 'Control Baseline', 'ANOVA (L vs H)'}, ...
    'Location', 'northeast', 'FontSize', 13);
fprintf('\n>>> Plotting Dashboard Complete.\n');

% Finalize CSV Export
col_names = {'Time_Bin', 'Distance_Ring_um', ...
             'Low_Mean_Gain', 'Low_SD', 'Low_vs_Baseline_pval', ...
             'High_Mean_Gain', 'High_SD', 'High_vs_Baseline_pval', ...
             'Low_vs_High_pval'};

StatsTable = cell2table(results_cell, 'VariableNames', col_names);
filename = 'FUS_Spatial_Stats_Summary_Fixed.csv';
writetable(StatsTable, filename);
fprintf('>>> SUCCESS: Statistics perfectly exported to %s.\n\n', filename);

%% --- BULLETPROOF MATH HELPERS ---
function [h, p] = safe_1sample_ttest(x, m)
    % Exact 2-tailed p-value bypassing broken toolboxes
    x = x(:); n = length(x);
    if n < 2, h = 0; p = NaN; return; end
    
    t_stat = (mean(x) - m) / (std(x) / sqrt(n));
    df = n - 1;
    
    p = betainc(df / (df + t_stat^2), df/2, 0.5);
    h = double(p < 0.05);
end

function [h, p] = safe_2sample_ttest(x, y)
    % Exact 2-sample p-value bypassing broken toolboxes
    x = x(:); y = y(:);
    nx = length(x); ny = length(y);
    if nx < 2 || ny < 2, h=0; p=NaN; return; end
    
    mx = mean(x); my = mean(y);
    vx = var(x); vy = var(y);
    
    s_pool = sqrt(((nx-1)*vx + (ny-1)*vy) / (nx+ny-2));
    t_stat = (mx - my) / (s_pool * sqrt(1/nx + 1/ny));
    df = nx + ny - 2;
    
    p = betainc(df / (df + t_stat^2), df/2, 0.5);
    h = double(p < 0.05);
end

function p_str = inline_p_formatter(p_val)
    if p_val < 0.001
        p_str = 'p<0.001';
    else
        p_str = sprintf('p=%.3f', p_val);
    end
end