function plot_FUS_distance_dashboard_from_workspace()
% plot_FUS_distance_dashboard_from_workspace
% Uses the current workspace data to generate a distance-specific dashboard.
% It will use corrected_gains if present, otherwise it reconstructs a gain
% matrix from target_results in the base workspace.

    if evalin('base', 'exist(''corrected_gains'',''var'')')
        local_corrected_gains = evalin('base', 'corrected_gains');
        local_isL = evalin('base', 'isL');
        local_isH = evalin('base', 'isH');
    elseif evalin('base', 'exist(''raw_gains'',''var'')')
        local_corrected_gains = evalin('base', 'raw_gains');
        if evalin('base', 'exist(''isL'',''var'')') && evalin('base', 'exist(''isH'',''var'')')
            local_isL = evalin('base', 'isL');
            local_isH = evalin('base', 'isH');
        else
            [local_corrected_gains, local_isL, local_isH] = build_gain_matrices_from_target_results();
        end
    elseif evalin('base', 'exist(''target_results'',''var'')')
        [local_corrected_gains, local_isL, local_isH] = build_gain_matrices_from_target_results();
    else
        error('No usable gain data found. Load target_results, raw_gains, or corrected_gains first.');
    end

    if isempty(local_corrected_gains)
        error('No gain data could be reconstructed from the workspace.');
    end

    num_distances = size(local_corrected_gains, 1);
    num_bins = size(local_corrected_gains, 2);
    num_bins_to_plot = min(num_bins, 4);

    if evalin('base', 'exist(''distance_labels'',''var'')')
        local_distance_labels = evalin('base', 'distance_labels');
    else
        local_distance_labels = generate_default_distance_labels(num_distances);
    end

    if evalin('base', 'exist(''time_labels'',''var'')')
        local_time_labels = evalin('base', 'time_labels');
        local_time_labels = ensure_time_labels(local_time_labels, num_bins_to_plot);
    else
        local_time_labels = generate_default_time_labels(num_bins_to_plot);
    end

    fig = figure('Name', 'FUS Distance Dashboard', 'Color', 'w', 'Position', [20 20 1800 1440]);
    set(fig, 'PaperUnits', 'inches', 'PaperPosition', [0 0 6.0 4.8], ...
        'PaperSize', [6.0 4.8]);
    num_panels = num_bins_to_plot + 1;
    tlo = tiledlayout(2, num_panels, 'TileSpacing', 'compact', 'Padding', 'loose');
    title(tlo, 'FUS Gain vs Distance', 'FontSize', 11, 'FontWeight', 'bold');

    summary_rows = cell(0, 11);
    group_p_values = nan(num_panels, num_distances);
    cross_distance_p_values = nan(num_distances, num_distances, 2, num_panels);

    for t = 1:num_panels
        ax = nexttile(tlo, t); hold(ax, 'on'); grid(ax, 'on');
        if t <= num_bins_to_plot
            data_slice = squeeze(local_corrected_gains(:, t, :));
        else
            data_slice = squeeze(nanmean(local_corrected_gains(:, 1:num_bins_to_plot, :), 2));
        end

        title(ax, local_time_labels{t}, 'FontSize', 10, 'FontWeight', 'bold');
        max_panel_y = 1.5;
        panel_errorbar_top = 1.5;
        for d = 1:num_distances
            panel_values = data_slice(d, :);
            panel_values = panel_values(isfinite(panel_values));
            if ~isempty(panel_values)
                panel_errorbar_top = max(panel_errorbar_top, mean(panel_values) + std(panel_values));
            end
        end
        group_bracket_y = panel_errorbar_top + 0.20;

        for d = 1:num_distances
            mL = NaN; sdL = NaN; p_L = NaN;
            mH = NaN; sdH = NaN; p_H = NaN; p_anova = NaN;
            vL = data_slice(d, local_isL);
            vH = data_slice(d, local_isH);
            vL = vL(~isnan(vL));
            vH = vH(~isnan(vH));
            vL = vL(:);
            vH = vH(:);

            xL = d - 0.20;
            xH = d + 0.20;

            if ~isempty(vL)
                xL_points = xL + linspace(-0.08, 0.08, numel(vL)).';
                scatter(ax, xL_points, vL, 18, [0.2 0.4 0.8], 'filled', ...
                    'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', [0.1 0.25 0.55], ...
                    'MarkerEdgeAlpha', 0.35, 'HandleVisibility', 'off');
                mL = mean(vL); sdL = std(vL);
                errorbar(ax, xL, mL, sdL, 'b', 'LineWidth', 1.0, 'Marker', 's', 'MarkerSize', 4, 'CapSize', 4);
                txt = sprintf('%.2f', mL);
                if numel(vL) > 2
                    [~, p_L] = safe_1sample_ttest(vL, 1.0);
                    if p_L < 0.05
                        txt = sprintf('%s\n%s', txt, inline_p_formatter(p_L));
                    end
                end
                text(ax, xL - 0.08, mL - 0.03, txt, 'FontSize', 7, 'Color', 'b', 'FontWeight', 'bold', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
            else
                mL = NaN; sdL = NaN; p_L = NaN;
            end

            if ~isempty(vH)
                xH_points = xH + linspace(-0.08, 0.08, numel(vH)).';
                scatter(ax, xH_points, vH, 18, [0.8 0.2 0.2], 'filled', ...
                    'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', [0.55 0.1 0.1], ...
                    'MarkerEdgeAlpha', 0.35, 'HandleVisibility', 'off');
                mH = mean(vH); sdH = std(vH);
                errorbar(ax, xH, mH, sdH, 'r', 'LineWidth', 1.0, 'Marker', 'o', 'MarkerSize', 4, 'CapSize', 4);
                txt = sprintf('%.2f', mH);
                if numel(vH) > 2
                    [~, p_H] = safe_1sample_ttest(vH, 1.0);
                    if p_H < 0.05
                        txt = sprintf('%s\n%s', txt, inline_p_formatter(p_H));
                    end
                end
                text(ax, xH + 0.08, mH + 0.03, txt, 'FontSize', 7, 'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
            else
                mH = NaN; sdH = NaN; p_H = NaN;
            end

            if numel(vL) > 2 && numel(vH) > 2
                [~, p_anova] = safe_2sample_ttest(vL, vH);
            end
            group_p_values(t, d) = p_anova;

            max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);

            if isfinite(p_anova) && p_anova < 0.05
                bracket_top = group_bracket_y;
                bracket_y_base = bracket_top - 0.05;
                plot(ax, [xL, xL, xH, xH], [bracket_y_base, bracket_top, bracket_top, bracket_y_base], ...
                    'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
                plot(ax, [xL, xH], [bracket_top, bracket_top], ...
                    'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
                text(ax, d, bracket_top + 0.06, inline_p_formatter(p_anova), ...
                    'FontSize', 7, 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                max_panel_y = max(max_panel_y, bracket_top + 0.08);
            end

            if ~isempty(vL)
                summary_rows(end+1, :) = {local_time_labels{t}, local_distance_labels{d}, 'L', numel(vL), mL, sdL, p_L, p_L < 0.05, NaN, NaN, sprintf('%.6f,', vL)};
            end
            if ~isempty(vH)
                summary_rows(end+1, :) = {local_time_labels{t}, local_distance_labels{d}, 'H', numel(vH), mH, sdH, p_H, p_H < 0.05, NaN, NaN, sprintf('%.6f,', vH)};
            end
        end

        [pairwise_max_y, panel_pairwise_p_values] = draw_nested_pairwise_brackets( ...
            ax, data_slice, local_isL, local_isH, num_distances, group_bracket_y);
        cross_distance_p_values(:, :, :, t) = panel_pairwise_p_values;
        if ~isempty(pairwise_max_y)
            max_panel_y = max(max_panel_y, pairwise_max_y);
        end

        set(ax, 'XTick', 1:num_distances, 'XTickLabel', local_distance_labels, 'FontSize', 7, 'FontWeight', 'bold');
        xtickangle(ax, 30);
        xlim(ax, [0.3, num_distances + 0.7]);
        ylim(ax, [0, max(2.5, max_panel_y + 0.2)]);
        line(ax, [0 num_distances+1], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
        if t == 1 || t == 4
            ylabel(ax, 'Corrected Gain Ratio', 'FontSize', 8, 'FontWeight', 'bold');
        end
        legend(ax, 'off');
    end

    annotation(fig, 'textbox', [0.37 0.01 0.26 0.02], 'String', 'Blue=L   Red=H   dashed line=1.0', ...
        'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 6.5, 'HorizontalAlignment', 'center');
    add_vertical_pvalue_colorbar(fig, [0.955 0.13 0.008 0.74], [0.1 0.3 0.8], 'L', 'left');
    add_vertical_pvalue_colorbar(fig, [0.975 0.13 0.008 0.74], [0.8 0.1 0.1], 'H', 'right');
    export_dashboard_summary(summary_rows, 'FUS_distance_dashboard_summary.csv');
    export_cross_distance_pvalue_matrices(cross_distance_p_values, local_distance_labels, ...
        local_time_labels(1:num_panels), 'FUS_distance_cross_distance_pvalue_matrices.csv');
    plot_cross_distance_pvalue_matrices(fig, tlo, cross_distance_p_values, local_distance_labels, local_time_labels(1:num_panels));
    fprintf('Figure generated. Use the MATLAB figure window to review the plot.\n');
end

function [corrected_gains, isL, isH] = build_gain_matrices_from_target_results()
    target_results = evalin('base', 'target_results');
    expIDs = fieldnames(target_results);
    validIDs = {};

    for i = 1:numel(expIDs)
        id = expIDs{i};
        if isstruct(target_results.(id)) && isfield(target_results.(id), 'spatial')
            validIDs{end+1} = id;
        end
    end

    if isempty(validIDs)
        error('No experiment entries with a spatial field were found in target_results.');
    end

    isL = false(size(validIDs));
    isH = false(size(validIDs));
    for i = 1:numel(validIDs)
        id = validIDs{i};
        isL(i) = startsWith(id, 'L', 'IgnoreCase', true);
        isH(i) = startsWith(id, 'H', 'IgnoreCase', true);
    end

    keep = isL | isH;
    validIDs = validIDs(keep);
    isL = isL(keep);
    isH = isH(keep);

    num_exps = numel(validIDs);
    raw_gains = nan(5, 10, num_exps);

    for e = 1:num_exps
        id = validIDs{e};
        for p = 1:5
            if ~isfield(target_results.(id).spatial(p), 'temporal')
                continue;
            end
            num_bins = min(10, numel(target_results.(id).spatial(p).temporal));
            for b = 1:num_bins
                if isfield(target_results.(id).spatial(p).temporal(b), 'gain')
                    g = target_results.(id).spatial(p).temporal(b).gain;
                    if ~isempty(g) && isfinite(g)
                        raw_gains(p, b, e) = g;
                    end
                end
            end
        end
    end

    corrected_gains = nan(size(raw_gains));
    for p = 1:5
        base_ref = nanmean(squeeze(raw_gains(p, 1, :)));
        if ~isfinite(base_ref) || abs(base_ref) < eps
            base_ref = 1.0;
        end
        for b = 1:size(raw_gains, 2)
            corrected_gains(p, b, :) = raw_gains(p, b, :) / base_ref;
        end
    end

    assignin('base', 'raw_gains', raw_gains);
    assignin('base', 'corrected_gains', corrected_gains);
    assignin('base', 'isL', isL);
    assignin('base', 'isH', isH);
end

function text_str = format_pairwise_band_pvals(data_slice, isL, isH)
    text_str = '';
    group_names = {'L', 'H'};
    group_masks = {isL, isH};

    for gi = 1:numel(group_names)
        mask = logical(group_masks{gi});
        if sum(mask) < 2
            continue;
        end

        vals = data_slice(:, mask);
        if size(vals, 1) < 2
            continue;
        end

        for b = 1:size(vals, 1)-1
            x = vals(b, :)';
            y = vals(b+1, :)';
            valid = isfinite(x) & isfinite(y);
            if sum(valid) < 2
                continue;
            end
            p_val = safe_paired_ttest(x(valid), y(valid));
            if isempty(text_str)
                text_str = sprintf('%s band %d vs %d: p=%.3f', group_names{gi}, b, b+1, p_val);
            else
                text_str = sprintf('%s\n%s band %d vs %d: p=%.3f', text_str, group_names{gi}, b, b+1, p_val);
            end
        end
    end

    if isempty(text_str)
        text_str = 'No paired band comparisons available.';
    end
end

function [h, p] = safe_paired_ttest(x, y)
    x = x(:);
    y = y(:);
    if numel(x) ~= numel(y)
        h = 0; p = NaN; return;
    end
    d = x - y;
    n = numel(d);
    if n < 2
        h = 0; p = NaN; return;
    end
    md = mean(d);
    sd = std(d);
    if abs(sd) < eps
        h = 0; p = NaN; return;
    end
    t_stat = abs(md) / (sd / sqrt(n));
    df = n - 1;
    p = betainc(df / (df + t_stat^2), df/2, 0.5);
    h = double(p < 0.05);
end

function [max_y, pairwise_p_values] = draw_nested_pairwise_brackets(ax, data_slice, isL, isH, num_distances, group_bracket_y)
    max_y = [];
    group_names = {'L', 'H'};
    group_masks = {isL, isH};
    group_colors = {[0.1 0.3 0.8], [0.8 0.1 0.1]};
    pairwise_p_values = nan(num_distances, num_distances, numel(group_names));
    finite_data = data_slice(isfinite(data_slice));
    if isempty(finite_data)
        return;
    end
    base_range = max(finite_data) - min(finite_data);
    if base_range <= 0
        base_range = 0.5;
    end
    base_y = max(group_bracket_y + 0.20, max(finite_data) + 0.15 * base_range);
    max_y_val = base_y;

    for gi = 1:numel(group_names)
        mask = logical(group_masks{gi});
        if sum(mask) < 2
            continue;
        end
        values = data_slice(:, mask);
        for i = 1:num_distances-1
            for j = i+1:num_distances
                x1 = i - 0.20;
                x2 = j + 0.20;
                x = values(i, :)';
                y = values(j, :)';
                valid = isfinite(x) & isfinite(y);
                if sum(valid) < 2
                    continue;
                end
                [~, p_val] = safe_paired_ttest(x(valid), y(valid));
                pairwise_p_values(i, j, gi) = p_val;
                pairwise_p_values(j, i, gi) = p_val;
                if ~isfinite(p_val) || p_val >= 0.05
                    continue;
                end
                span = j - i;
                offset = 0.08 * span + 0.05 * (gi - 1);
                ytop = base_y + offset;
                line_color = pvalue_line_color(group_colors{gi}, p_val);
                plot(ax, [x1, x1, x2, x2], [ytop-0.01, ytop, ytop, ytop-0.01], ...
                    'Color', line_color, 'LineWidth', 1.5, 'HandleVisibility', 'off');
                max_y_val = max(max_y_val, ytop + 0.03 * base_range);
            end
        end
    end

    if ~isempty(max_y_val)
        max_y = max_y_val;
    end
end

function labels = generate_default_time_labels(num_bins)
    labels = cell(1, num_bins + 1);
    for b = 1:num_bins
        labels{b} = sprintf('Bin %d', b);
    end
    labels{end} = sprintf('Session Average (Bins 1-%d)', num_bins);
end

function line_color = pvalue_line_color(base_color, p_val)
    significance_strength = min(1, max(0, -log10(p_val / 0.05) / 3));
    significance_strength = 0.25 + 0.75 * significance_strength;
    line_color = 1 - significance_strength * (1 - base_color);
end

function plot_cross_distance_pvalue_matrices(fig, matrix_layout, p_values, distance_labels, panel_labels)
    num_distances = numel(distance_labels);
    num_panels = numel(panel_labels);
    low_color = [0.1 0.3 0.8];
    high_color = [0.8 0.1 0.1];

    for t = 1:num_panels
        ax = nexttile(matrix_layout, num_panels + t); hold(ax, 'on');
        rgb_image = ones(num_distances, num_distances, 3);
        for i = 1:num_distances
            for j = 1:num_distances
                if i == j
                    rgb_image(i, j, :) = 0.92;
                    continue;
                end
                if i > j
                    p_val = p_values(i, j, 1, t);
                    base_color = low_color;
                else
                    p_val = p_values(i, j, 2, t);
                    base_color = high_color;
                end
                if isfinite(p_val)
                    strength = pvalue_strength(p_val);
                    rgb_image(i, j, :) = 1 - strength * (1 - base_color);
                end
            end
        end
        image(ax, rgb_image);
        set(ax, 'Color', [0.92 0.92 0.92], 'YDir', 'reverse', ...
            'XTick', 1:num_distances, 'YTick', 1:num_distances, ...
            'XTickLabel', distance_labels, 'YTickLabel', distance_labels, ...
            'FontSize', 6.5, 'TickLength', [0 0]);
        xtickangle(ax, 45);
        title(ax, sprintf('P-values: %s', panel_labels{t}), 'FontSize', 8, 'FontWeight', 'bold');
        if t == 3
            xlabel(ax, 'Distance', 'FontSize', 6);
        end
        if t == 1
            ylabel(ax, 'Distance', 'FontSize', 6);
        end
        axis(ax, 'square');

        for i = 1:num_distances
            for j = 1:num_distances
                if i == j
                    text_value = '-';
                    text_color = [0.35 0.35 0.35];
                elseif i > j
                    p_val = p_values(i, j, 1, t);
                    text_value = format_matrix_pvalue(p_val);
                    text_color = matrix_text_color(pvalue_strength(p_val));
                else
                    p_val = p_values(i, j, 2, t);
                    text_value = format_matrix_pvalue(p_val);
                    text_color = matrix_text_color(pvalue_strength(p_val));
                end
                text(ax, j, i, text_value, 'HorizontalAlignment', 'center', ...
                    'FontSize', 6.2, 'FontWeight', 'bold', 'Color', text_color);
            end
        end
        plot(ax, [0.5 num_distances+0.5], [0.5 num_distances+0.5], ...
            'Color', [0.65 0.65 0.65], 'LineStyle', '--', 'HandleVisibility', 'off');
    end
    annotation(fig, 'textbox', [0.37 0.035 0.26 0.018], ...
        'String', 'Lower triangle: low power   |   Upper triangle: high power', ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontSize', 6.5);
end

function add_vertical_pvalue_colorbar(fig, position, base_color, label, y_axis_location)
    colorbar_ax = axes('Parent', fig, 'Position', position, 'Color', 'none', ...
        'Box', 'on', 'FontSize', 5.5, 'YAxisLocation', y_axis_location);
    p_scale = linspace(0.05, 0.001, 100);
    rgb_image = zeros(numel(p_scale), 1, 3);
    for k = 1:numel(p_scale)
        rgb_image(k, 1, :) = pvalue_line_color(base_color, p_scale(k));
    end
    image(colorbar_ax, 1, 1:numel(p_scale), rgb_image);
    set(colorbar_ax, 'YDir', 'normal', 'XTick', [], ...
        'YTick', [1 34 67 100], 'YTickLabel', {'0.05', '0.033', '0.017', '0.001'}, ...
        'TickLength', [0.02 0.02]);
    ylim(colorbar_ax, [1 numel(p_scale)]);
    xlim(colorbar_ax, [0.5 1.5]);
    title(colorbar_ax, label, 'FontSize', 6.5, 'FontWeight', 'bold');
end

function strength = pvalue_strength(p_val)
    if ~isfinite(p_val)
        strength = 0;
    elseif p_val < 0.05
        strength = 0.25 + 0.75 * min(1, max(0, -log10(p_val / 0.05) / 3));
    else
        strength = 0.08;
    end
end

function text_color = matrix_text_color(score)
    if score > 0.45
        text_color = [1 1 1];
    else
        text_color = [0.1 0.1 0.1];
    end
end

function text_value = format_matrix_pvalue(p_val)
    if ~isfinite(p_val)
        text_value = '';
    elseif p_val < 0.001
        text_value = 'p<.001';
    else
        text_value = sprintf('%.3f', p_val);
    end
end

function labels = ensure_time_labels(labels, num_bins)
    if isempty(labels)
        labels = generate_default_time_labels(num_bins);
        return;
    end

    labels = labels(:).';
    if numel(labels) < num_bins + 1
        defaults = generate_default_time_labels(num_bins);
        labels = [labels, defaults(numel(labels)+1:end)];
    elseif numel(labels) > num_bins + 1
        labels = labels(1:num_bins+1);
    end
end

function labels = generate_default_distance_labels(num_distances)
    if num_distances == 5
        labels = {'0-250', '250-500', '500-750', '750-1000', '1000-1250'};
    else
        labels = cell(1, num_distances);
        for i = 1:num_distances
            labels{i} = sprintf('Ring %d', i);
        end
    end
end

function [h, p] = safe_1sample_ttest(x, m)
    x = x(:);
    n = length(x);
    if n < 2
        h = 0; p = NaN;
        return;
    end
    t_stat = (mean(x) - m) / (std(x) / sqrt(n));
    df = n - 1;
    p = betainc(df / (df + t_stat^2), df/2, 0.5);
    h = double(p < 0.05);
end

function [h, p] = safe_2sample_ttest(x, y)
    x = x(:);
    y = y(:);
    nx = length(x);
    ny = length(y);
    if nx < 2 || ny < 2
        h = 0; p = NaN;
        return;
    end
    mx = mean(x);
    my = mean(y);
    vx = var(x);
    vy = var(y);
    s_pool = sqrt(((nx-1)*vx + (ny-1)*vy) / (nx+ny-2));
    t_stat = (mx - my) / (s_pool * sqrt(1/nx + 1/ny));
    df = nx + ny - 2;
    p = betainc(df / (df + t_stat^2), df/2, 0.5);
    h = double(p < 0.05);
end

function p_str = inline_p_formatter(p_val)
    if isnan(p_val)
        p_str = 'n/a';
    elseif p_val < 0.001
        p_str = 'p<0.001';
    else
        p_str = sprintf('p=%.3f', p_val);
    end
end

function export_dashboard_summary(summary_rows, file_name)
    if isempty(summary_rows)
        summary_table = table();
    else
        summary_table = cell2table(summary_rows, 'VariableNames', {...
            'panel_label', 'spatial_label', 'intensity', 'n_observations', 'mean_gain', 'sd_gain', ...
            'baseline_p_value', 'baseline_significant', 'group_comparison_p_value', 'group_comparison_significant', 'raw_gain_values'});
    end

    output_path = fullfile(fileparts(mfilename('fullpath')), file_name);
    writetable(summary_table, output_path);
    fprintf('Saved dashboard summary to %s\n', output_path);
end

function export_cross_distance_pvalue_matrices(p_values, distance_labels, panel_labels, file_name)
    % Store each matrix cell as one row so the CSV remains unambiguous and filterable.
    group_names = {'L', 'H'};
    num_distances = numel(distance_labels);
    num_panels = numel(panel_labels);
    matrix_rows = cell(0, 11);

    for t = 1:num_panels
        for i = 1:num_distances
            for j = 1:num_distances
                if i == j
                    comparison_group = 'Diagonal';
                    triangle = 'Diagonal';
                    p_val = NaN;
                    display_value = '-';
                elseif i > j
                    comparison_group = group_names{1};
                    triangle = 'Lower';
                    p_val = p_values(i, j, 1, t);
                    display_value = format_matrix_pvalue(p_val);
                else
                    comparison_group = group_names{2};
                    triangle = 'Upper';
                    p_val = p_values(i, j, 2, t);
                    display_value = format_matrix_pvalue(p_val);
                end

                matrix_rows(end+1, :) = {t, panel_labels{t}, comparison_group, triangle, ...
                    i, distance_labels{i}, j, distance_labels{j}, p_val, display_value, ...
                    p_val < 0.05};
            end
        end
    end

    matrix_table = cell2table(matrix_rows, 'VariableNames', {...
        'panel_index', 'panel_label', 'comparison_group', 'triangle', ...
        'row_index', 'row_distance_label', 'column_index', 'column_distance_label', ...
        'p_value', 'matrix_display_value', 'significant_at_0_05'});
    output_path = fullfile(fileparts(mfilename('fullpath')), file_name);
    writetable(matrix_table, output_path);
    fprintf('Saved cross-distance p-value matrices to %s\n', output_path);
end
