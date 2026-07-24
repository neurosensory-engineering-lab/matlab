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

    fig = figure('Name', 'FUS Distance Dashboard', 'Color', 'w', 'Position', [20 20 1800 950]);
    num_panels = num_bins_to_plot + 1;
    num_rows = ceil(sqrt(num_panels));
    num_cols = ceil(num_panels / num_rows);
    tlo = tiledlayout(num_rows, num_cols, 'TileSpacing', 'compact', 'Padding', 'loose');
    title(tlo, 'FUS Gain vs Distance (Safe Stats + Clean Layout + SD)', 'FontSize', 24, 'FontWeight', 'bold');

    summary_rows = cell(0, 11);

    for t = 1:num_panels
        ax = nexttile; hold(ax, 'on'); grid(ax, 'on');
        if t <= num_bins_to_plot
            data_slice = squeeze(local_corrected_gains(:, t, :));
        else
            data_slice = squeeze(nanmean(local_corrected_gains(:, 1:num_bins_to_plot, :), 2));
        end

        title(ax, local_time_labels{t}, 'FontSize', 16, 'FontWeight', 'bold');
        max_panel_y = 1.5;

        for d = 1:num_distances
            vL = data_slice(d, local_isL);
            vH = data_slice(d, local_isH);
            vL = vL(~isnan(vL));
            vH = vH(~isnan(vH));

            xL = d - 0.20;
            xH = d + 0.20;

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
                    text(ax, d, bracket_y + 0.1, inline_p_formatter(p_anova), 'FontSize', 11, 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                    max_panel_y = max(max_panel_y, bracket_y + 0.2);
                end
            else
                p_anova = NaN;
            end

            max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);

            if ~isempty(vL)
                summary_rows(end+1, :) = {local_time_labels{t}, local_distance_labels{d}, 'L', numel(vL), mL, sdL, p_L, p_L < 0.05, NaN, NaN, sprintf('%.6f,', vL)};
            end
            if ~isempty(vH)
                summary_rows(end+1, :) = {local_time_labels{t}, local_distance_labels{d}, 'H', numel(vH), mH, sdH, p_H, p_H < 0.05, NaN, NaN, sprintf('%.6f,', vH)};
            end
        end

        set(ax, 'XTick', 1:num_distances, 'XTickLabel', local_distance_labels, 'FontSize', 11, 'FontWeight', 'bold');
        xtickangle(ax, 30);
        xlim(ax, [0.3, num_distances + 0.7]);
        bracket_top = draw_nested_pairwise_brackets(ax, data_slice, local_isL, local_isH, num_distances);
        if ~isempty(bracket_top)
            max_panel_y = max(max_panel_y, bracket_top);
        end
        ylim(ax, [0, max(2.5, max_panel_y + 0.2)]);
        line(ax, [0 num_distances+1], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
        if t == 1 || t == 4
            ylabel(ax, 'Corrected Gain Ratio', 'FontSize', 14, 'FontWeight', 'bold');
        end
        legend(ax, 'off');
    end

    annotation(fig, 'textbox', [0.75 0.12 0.18 0.08], 'String', {'Low Power (L)', 'High Power (H)', 'Control Baseline'}, 'FitBoxToText', 'on', 'BackgroundColor', 'white');
    export_dashboard_summary(summary_rows, 'FUS_distance_dashboard_summary.csv');
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

function max_y = draw_nested_pairwise_brackets(ax, data_slice, isL, isH, num_distances)
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
