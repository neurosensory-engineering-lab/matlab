%% ============================================================
%  DT EXPERIMENT VISUALIZATION SCRIPT (CORRECTED P-VALUES)
% =============================================================
% REQUIRES: G10_all, G30_all matrices to be in the workspace.
% =============================================================

% --- Data Check ---
requiredVars = {'G10_all', 'G30_all'};
for v = 1:length(requiredVars)
    if ~exist(requiredVars{v}, 'var')
        error('Data variable "%s" not found in workspace.', requiredVars{v});
    end
end

% --- Figure Setup & Colors ---
[numExps, numBins] = size(G10_all);
x_bins = 1:numBins;

jitter_offset = 0.16; 
point_jitter_width = 0.05; 

color10 = [0, 0.4470, 0.7410]; % Blue
color30 = [0.8500, 0.3250, 0.0980]; % Red

fig = figure('Color', 'w', 'Position', [100, 100, 1000, 650]);
hold on; grid on;

% --- 1. Draw Baseline Reference Line ---
line([0.5 numBins+0.5], [1 1], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% --- 2. Calculate Group Statistics ---
mean10 = nanmean(G10_all, 1);
mean30 = nanmean(G30_all, 1);
sem10 = nanstd(G10_all, [], 1) ./ sqrt(sum(~isnan(G10_all), 1));
sem30 = nanstd(G30_all, [], 1) ./ sqrt(sum(~isnan(G30_all), 1));

p_vs_base10 = nan(1, numBins);
p_vs_base30 = nan(1, numBins);
p_between10_30 = nan(1, numBins);

alpha = 0.05; 

for b = 1:numBins
    v10 = G10_all(:, b); v10c = v10(~isnan(v10));
    v30 = G30_all(:, b); v30c = v30(~isnan(v30));
    
    % Safe manual 1-sample t-test vs 1.0 (Baseline)
    if length(v10c) > 2, [~, p_vs_base10(b)] = safe_1sample_ttest(v10c, 1.0); end
    if length(v30c) > 2, [~, p_vs_base30(b)] = safe_1sample_ttest(v30c, 1.0); end
    
    % Safe manual 2-sample t-test (10kHz vs 30kHz)
    if length(v10c) > 2 && length(v30c) > 2
        [~, p_between10_30(b)] = safe_2sample_ttest(v10c, v30c);
    end
end

% --- 3. Plot Individual Datapoints ---
marker_size = 40;
for b = 1:numBins
    % 10kHz column
    num10_this_bin = sum(~isnan(G10_all(:, b)));
    x_jit10 = (b - jitter_offset) + (rand(num10_this_bin, 1) - 0.5) * point_jitter_width;
    scatter(x_jit10, G10_all(~isnan(G10_all(:,b)), b), marker_size, color10, 'o', ...
        'MarkerFaceColor', color10, 'MarkerFaceAlpha', 0.25, ...
        'MarkerEdgeAlpha', 0.4, 'HandleVisibility', 'off');
        
    % 30kHz column
    num30_this_bin = sum(~isnan(G30_all(:, b)));
    x_jit30 = (b + jitter_offset) + (rand(num30_this_bin, 1) - 0.5) * point_jitter_width;
    scatter(x_jit30, G30_all(~isnan(G30_all(:,b)), b), marker_size, color30, 's', ...
        'MarkerFaceColor', color30, 'MarkerFaceAlpha', 0.25, ...
        'MarkerEdgeAlpha', 0.4, 'HandleVisibility', 'off');
end

% --- 4. Plot Staggered Means and Error Bars ---
h10 = errorbar(x_bins - jitter_offset, mean10, sem10, 'o', 'Color', color10, ...
    'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', color10, 'CapSize', 6);
h30 = errorbar(x_bins + jitter_offset, mean30, sem30, 's', 'Color', color30, ...
    'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', color30, 'CapSize', 6);

% --- 5. Add ALL Significance Indicators ---
y_full_max = max([G10_all(:); G30_all(:); 1.25]);
sig_marker_y_offset = y_full_max * 0.06; 

for b = 1:numBins
    % -- 10kHz vs Baseline Text --
    if ~isnan(p_vs_base10(b))
        fw = 'normal'; p_str = format_pval(p_vs_base10(b));
        if p_vs_base10(b) < alpha, fw = 'bold'; p_str = sprintf('%s*', p_str); end
        text(b - jitter_offset, mean10(b) + sem10(b) + sig_marker_y_offset*0.4, p_str, ...
            'Color', color10, 'FontSize', 9, 'FontWeight', fw, 'HorizontalAlignment', 'center');
    end
    
    % -- 30kHz vs Baseline Text --
    if ~isnan(p_vs_base30(b))
        fw = 'normal'; p_str = format_pval(p_vs_base30(b));
        if p_vs_base30(b) < alpha, fw = 'bold'; p_str = sprintf('%s*', p_str); end
        text(b + jitter_offset, mean30(b) + sem30(b) + sig_marker_y_offset*0.4, p_str, ...
            'Color', color30, 'FontSize', 9, 'FontWeight', fw, 'HorizontalAlignment', 'center');
    end
    
    % -- 10kHz vs 30kHz Bracket and Text --
    if ~isnan(p_between10_30(b))
        y_max_at_bin = max([mean10(b) + sem10(b), mean30(b) + sem30(b)]);
        y_bracket_top = y_max_at_bin + sig_marker_y_offset * 1.5;
        y_bracket_arm_bottom = y_bracket_top - sig_marker_y_offset * 0.3;
        
        plot([b - jitter_offset, b - jitter_offset], [y_bracket_arm_bottom, y_bracket_top], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot([b + jitter_offset, b + jitter_offset], [y_bracket_arm_bottom, y_bracket_top], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        plot([b - jitter_offset, b + jitter_offset], [y_bracket_top, y_bracket_top], 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        
        fw = 'normal'; p_str = format_pval(p_between10_30(b));
        if p_between10_30(b) < alpha, fw = 'bold'; p_str = sprintf('%s*', p_str); end
        
        text(b, y_bracket_top + sig_marker_y_offset*0.3, p_str, ...
            'Color', 'k', 'FontSize', 10, 'FontWeight', fw, 'HorizontalAlignment', 'center');
    end
end

% --- 6. Final Formatting ---
ylabel('Normalized Gain (Post / Pre at 10kHz ROI)');
xlabel('Time Bin (10 trials each)');
title('FUS Specificity: 10kHz vs 30kHz Targeting');

xlim([0.5 numBins+0.5]);
ylim_max = y_full_max + sig_marker_y_offset * 3.5; 
ylim([max(0, min([G10_all(:); G30_all(:)]) - 0.2), ylim_max]);

set(gca, 'XTick', 1:numBins, 'FontSize', 12, 'LineWidth', 1.2);
legend([h10, h30], {'10kHz Stim', '30kHz Stim'}, 'Location', 'best', 'FontSize', 12);
box on;

%% ============================================================
% TOOLBOX-INDEPENDENT HELPER FUNCTIONS
% =============================================================
function [h, p] = safe_1sample_ttest(x, mu)
    x = x(:);
    n = length(x);
    if n < 2
        h = 0; p = NaN; return;
    end
    t_stat = (mean(x) - mu) / (std(x) / sqrt(n));
    p = betainc((n-1) / ((n-1) + t_stat^2), (n-1)/2, 0.5);
    h = double(p < 0.05);
end

function [h, p] = safe_2sample_ttest(x, y)
    x = x(:); y = y(:);
    nx = length(x); ny = length(y);
    if nx < 2 || ny < 2
        h = 0; p = NaN; return;
    end
    mx = mean(x); my = mean(y);
    vx = var(x); vy = var(y);
    t_stat = (mx - my) / ...
        (sqrt(((nx-1)*vx + (ny-1)*vy)/(nx+ny-2)) * sqrt(1/nx + 1/ny));
    p = betainc((nx+ny-2) / ((nx+ny-2) + t_stat^2), (nx+ny-2)/2, 0.5);
    h = double(p < 0.05);
end

function p_str = format_pval(p)
    if p < 0.01
        p_str = sprintf('p<0.01');
    elseif p > 0.99
        p_str = sprintf('p>0.99');
    else
        p_str = sprintf('p=%.2f', p);
    end
end