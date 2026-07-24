function plot_PC1_percentile_dashboard_from_workspace()
% plot_PC1_percentile_dashboard_from_workspace
% Uses existing workspace variables to generate a PCA-percentile dashboard
% similar to the ``FUS Gain vs PC1 Functional Percentile (Expanded Spatial Bands)`` figure.
% This function does not perform new TIFF extraction or raw data processing.

    if ~evalin('base', 'exist(''corrected_gains'',''var'')')
        error('Variable ''corrected_gains'' not found in base workspace. Load the workspace first.');
    end
    if ~evalin('base', 'exist(''isL'',''var'')') || ~evalin('base', 'exist(''isH'',''var'')')
        error('Variables ''isL'' and/or ''isH'' not found in base workspace. Load the workspace first.');
    end

    local_corrected_gains = evalin('base', 'corrected_gains');
    local_isL = evalin('base', 'isL');
    local_isH = evalin('base', 'isH');

    num_brackets = size(local_corrected_gains, 1);
    num_bins = size(local_corrected_gains, 2);
    num_bins_to_plot = min(num_bins, 4);

    if evalin('base', 'exist(''bracket_labels'',''var'')')
        local_bracket_labels = evalin('base', 'bracket_labels');
    else
        local_bracket_labels = generate_default_bracket_labels(num_brackets);
    end

    if evalin('base', 'exist(''time_labels'',''var'')')
        local_time_labels = evalin('base', 'time_labels');
        local_time_labels = ensure_time_labels(local_time_labels, num_bins_to_plot);
    else
        local_time_labels = generate_default_time_labels(num_bins_to_plot);
    end

    if numel(local_time_labels) < num_bins_to_plot + 1
        local_time_labels = ensure_time_labels(local_time_labels, num_bins_to_plot);
    end
    if numel(local_time_labels) >= num_bins_to_plot + 1
        local_time_labels{num_bins_to_plot + 1} = 'Session Average';
    end

    fig = figure('Name', 'PCA Percentile Dashboard', 'Color', 'w', 'Position', [20 20 1800 950]);
    num_panels = num_bins_to_plot + 1;
    num_rows = ceil(sqrt(num_panels));
    num_cols = ceil(num_panels / num_rows);
    tlo = tiledlayout(num_rows, num_cols, 'TileSpacing', 'compact', 'Padding', 'loose');
    title(tlo, 'FUS Gain vs PC1 Functional Percentile (Expanded Spatial Bands)', 'FontSize', 24, 'FontWeight', 'bold');

    summary_rows = cell(0, 11);
    results_cell = cell(0, 9);
    for t = 1:num_panels
        ax = nexttile; hold(ax, 'on'); grid(ax, 'on');
        if t <= num_bins_to_plot
            data_slice = squeeze(local_corrected_gains(:, t, :));
        else
            data_slice = squeeze(nanmean(local_corrected_gains(:, 1:num_bins_to_plot, :), 2));
        end

        title(ax, local_time_labels{t}, 'FontSize', 16, 'FontWeight', 'bold');
        max_panel_y = 1.5;

        for p = 1:num_brackets
            vL = data_slice(p, local_isL);
            vH = data_slice(p, local_isH);
            vL = vL(~isnan(vL));
            vH = vH(~isnan(vH));

            xL = p - 0.20;
            xH = p + 0.20;

            if ~isempty(vL)
                scatter(ax, ones(size(vL))*xL, vL, 30, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
                mL = mean(vL); sdL = std(vL);
                errorbar(ax, xL, mL, sdL, 'b', 'LineWidth', 2.5, 'Marker', 's', 'MarkerSize', 8);
                if numel(vL) > 2
                    [~, p_L] = safe_1sample_ttest(vL, 1.0);
                    txt = sprintf('%.2f', mL);
                    if p_L < 0.05
                        txt = sprintf('%s\n%s', txt, inline_p_formatter(p_L));
                    end
                    text(ax, xL - 0.12, mL, txt, 'FontSize', 10, 'Color', 'b', 'FontWeight', 'bold', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
                end
            else
                mL = NaN; sdL = NaN; p_L = NaN;
            end

            if ~isempty(vH)
                scatter(ax, ones(size(vH))*xH, vH, 30, [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
                mH = mean(vH); sdH = std(vH);
                errorbar(ax, xH, mH, sdH, 'r', 'LineWidth', 2.5, 'Marker', 'o', 'MarkerSize', 8);
                if numel(vH) > 2
                    [~, p_H] = safe_1sample_ttest(vH, 1.0);
                    txt = sprintf('%.2f', mH);
                    if p_H < 0.05
                        txt = sprintf('%s\n%s', txt, inline_p_formatter(p_H));
                    end
                    text(ax, xH + 0.12, mH, txt, 'FontSize', 10, 'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
                end
            else
                mH = NaN; sdH = NaN; p_H = NaN;
            end

            if numel(vL) > 2 && numel(vH) > 2
                [~, p_anova] = safe_2sample_ttest(vL, vH);
                if p_anova < 0.05
                    top_of_data = max([mL + sdL, mH + sdH]);
                    if isnan(top_of_data), top_of_data = 1.5; end
                    bracket_y = top_of_data + 0.25;
                    plot(ax, [xL, xL, xH, xH], [bracket_y-0.05, bracket_y, bracket_y, bracket_y-0.05], '-k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
                    text(ax, p, bracket_y + 0.1, inline_p_formatter(p_anova), 'FontSize', 11, 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                    max_panel_y = max(max_panel_y, bracket_y + 0.2);
                end
            else
                p_anova = NaN;
            end

            max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);
            results_cell(end+1, :) = {local_time_labels{t}, safe_get_label(local_bracket_labels, p), mL, sdL, p_L, mH, sdH, p_H, p_anova};
            summary_rows(end+1, :) = {local_time_labels{t}, safe_get_label(local_bracket_labels, p), 'L', numel(vL), mL, sdL, p_L, p_L < 0.05, p_anova, p_anova < 0.05, sprintf('%.6f,', vL)};
            summary_rows(end+1, :) = {local_time_labels{t}, safe_get_label(local_bracket_labels, p), 'H', numel(vH), mH, sdH, p_H, p_H < 0.05, p_anova, p_anova < 0.05, sprintf('%.6f,', vH)};
        end

        set(ax, 'XTick', 1:num_brackets, 'XTickLabel', local_bracket_labels, 'FontSize', 11, 'FontWeight', 'bold');
        xtickangle(ax, 30);
        xlim(ax, [0.3, num_brackets + 0.7]);
        bracket_top = draw_nested_pairwise_brackets(ax, data_slice, local_isL, local_isH, num_brackets);
        if ~isempty(bracket_top)
            max_panel_y = max(max_panel_y, bracket_top);
        end
        ylim(ax, [0, max(2.5, max_panel_y + 0.2)]);
        line(ax, [0 num_brackets+1], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
        if t == 1 || t == 4
            ylabel(ax, 'Corrected Gain Ratio', 'FontSize', 14, 'FontWeight', 'bold');
        end
    end

    legend(ax, 'off');
    scatter(nan, nan, 30, [0.2 0.4 0.8], 'filled', 'HandleVisibility', 'off');
    hold(ax, 'off');

    annotation(fig, 'textbox', [0.75 0.12 0.18 0.08], 'String', {'Low Power (L)', 'High Power (H)', 'Control Baseline'}, 'FitBoxToText', 'on', 'BackgroundColor', 'white');

    export_dashboard_summary(summary_rows, 'PC1_percentile_dashboard_summary.csv');
    fprintf('Figure generated. Use the MATLAB figure window to review the plot.\n');
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
                text_str = sprintf('%s bracket %d vs %d: p=%.3f', group_names{gi}, b, b+1, p_val);
            else
                text_str = sprintf('%s\n%s bracket %d vs %d: p=%.3f', text_str, group_names{gi}, b, b+1, p_val);
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

function max_y = draw_nested_pairwise_brackets(ax, data_slice, isL, isH, num_brackets)
    max_y = [];
    group_names = {'L', 'H'};
    group_masks = {isL, isH};
    group_colors = {[0.1 0.3 0.8], [0.8 0.1 0.1]};
    base_range = max(data_slice(:)) - min(data_slice(:));
    if isempty(base_range) || base_range <= 0
        base_range = 0.5;
    end
    base_y = max(data_slice(:)) + 0.15 * base_range;
    max_y_val = base_y;

    for gi = 1:numel(group_names)
        mask = logical(group_masks{gi});
        if sum(mask) < 2
            continue;
        end
        values = data_slice(:, mask);
        for i = 1:num_brackets-1
            for j = i+1:num_brackets
                x1 = i - 0.20;
                x2 = j + 0.20;
                x = values(i, :)';
                y = values(j, :)';
                valid = isfinite(x) & isfinite(y);
                if sum(valid) < 2
                    continue;
                end
                [~, p_val] = safe_paired_ttest(x(valid), y(valid));
                if p_val >= 0.05
                    continue;
                end
                span = j - i;
                offset = 0.08 * span + 0.05 * (gi - 1);
                ytop = base_y + offset;
                plot(ax, [x1, x1, x2, x2], [ytop-0.01, ytop, ytop, ytop-0.01], 'Color', group_colors{gi}, 'LineWidth', 1.5);
                text(ax, mean([x1, x2]), ytop + 0.02 * base_range, sprintf('p=%.3f', p_val), ...
                     'Color', group_colors{gi}, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
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

function labels = generate_default_bracket_labels(num_brackets)
    labels = cell(1, num_brackets);
    if num_brackets == 9
        labels = {'Top 10%', '80-90%', '70-80%', '60-70%', '50-60%', '40-50%', '30-40%', '20-30%', '10-20%'};
    else
        for i = 1:num_brackets
            labels{i} = sprintf('Bracket %d', i);
        end
    end
end

function label = safe_get_label(labels, idx)
    if idx <= numel(labels)
        label = labels{idx};
    else
        label = sprintf('Bracket %d', idx);
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
