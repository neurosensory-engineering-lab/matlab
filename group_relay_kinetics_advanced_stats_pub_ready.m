%% GROUP RELAY KINETICS (COMPREHENSIVE ALL-TO-ALL LONGITUDINAL ANALYSIS)
% -------------------------------------------------------------------------
% 1. TARGETED PANELS: Low Power (L) and High Power (H) cohorts only.
% 2. INTRA-BIN LAYERS: Runs cross-sectional post-hoc pairs per time point.
% 3. ALL-TO-ALL LONGITUDINAL: Compares every PC to itself across ALL possible 
%    bin combinations (e.g., Bin 1 vs Bin 3, Bin 2 vs Bin 4, etc.).
% 4. AUTOMATED CLUTTER FILTER: Strictly draws brackets ONLY when p < 0.05.
% -------------------------------------------------------------------------

% 1. Data Verification & Loading
if ~exist('grand_matrix', 'var') || ~exist('relay_results', 'var')
    matFile = 'FUS_Relay_Timings_V8_Workspace.mat';
    if exist(matFile, 'file')
        load(matFile);
        fprintf('>>> Successfully loaded %s\n', matFile);
    else
        error('Workspace matrix not found. Run the GrandMaster script first.');
    end
end

mouse_names = fieldnames(relay_results);
num_mice = length(mouse_names);

isL = false(num_mice, 1); isH = false(num_mice, 1);
for m = 1:num_mice
    name = mouse_names{m};
    if startsWith(name, 'L', 'IgnoreCase', true),     isL(m) = true;
    elseif startsWith(name, 'H', 'IgnoreCase', true), isH(m) = true;
    end
end

[total_mice_mat, num_bins, num_pcs] = size(grand_matrix); 
x_labels = {'Pre-FUS', 'Post Bin 1', 'Post Bin 2', 'Post Bin 3', 'Post Bin 4', 'Post Bin 5'};

% Target low power and high power cohorts exclusively
group_matrices_norm = {norm_grand_matrix(isL, :, :), norm_grand_matrix(isH, :, :)};
group_labels = {'Low Power Cohort (L)', 'High Power Cohort (H)'};
group_prefixes = {'L', 'H'};

% Widened Horizontal Offset Footprint
pc_colors = [0.85 0.15 0.15;   % PC1: Deep Red
             0.15 0.65 0.15;   % PC2: Emerald Green
             0.15 0.45 0.85];  % PC3: Cobalt Blue
         
pc_offsets = [-0.26, 0.0, 0.26]; 
pc_markers = {'s', '^', 'o'};    

cross_sectional_stats = struct();
longitudinal_bin_stats = struct();

%% 2. GENERATE PANELS
figClean = figure(14000); clf;
set(figClean, 'Color', 'w', 'Position', [50 50 1850 950]);
tlo = tiledlayout(1, 2, 'TileSpacing', 'loose', 'Padding', 'normal');
title(tlo, 'Cortical Relay Profiling: Intra-Bin Layers & All-to-All Longitudinal Shifts', ...
    'FontSize', 18, 'FontWeight', 'bold');

for g = 1:2
    ax = nexttile; hold on; grid on;
    set(ax, 'GridLineStyle', ':', 'GridAlpha', 0.4, 'LineWidth', 1.5);
    
    g_data = group_matrices_norm{g};
    p_prefix = group_prefixes{g};
    
    if isempty(g_data) || size(g_data, 1) == 0
        title([group_labels{g} ' - No Data Available'], 'Color', 'r', 'FontSize', 14);
        continue;
    end
    
    % Track global plot bounds dynamically
    global_max_y = 1.5;
    bin_local_maxes = zeros(num_bins, 1);
    
    % Step A: Render Raw Jitter Points & Isolated Mean Bars
    for b = 1:num_bins
        local_max = 1.2;
        for p = 1:num_pcs
            raw_pts = g_data(:, b, p);
            valid_pts = raw_pts(~isnan(raw_pts));
            x_pos = b + pc_offsets(p);
            
            if ~isempty(valid_pts)
                m_val = mean(valid_pts);
                s_val = std(valid_pts) / sqrt(length(valid_pts));
                
                scatter(ones(size(valid_pts))*x_pos, valid_pts, 60, pc_colors(p,:), ...
                    pc_markers{p}, 'filled', 'MarkerFaceAlpha', 0.14, 'HandleVisibility', 'off');
                
                errorbar(x_pos, m_val, s_val, 'Color', pc_colors(p,:), 'LineWidth', 3.0, ...
                    'Marker', pc_markers{p}, 'MarkerSize', 11, 'MarkerFaceColor', 'w', ...
                    'MarkerEdgeColor', pc_colors(p,:), 'HandleVisibility', 'off');
                
                local_max = max([local_max, max(valid_pts), m_val + s_val]);
            end
        end
        bin_local_maxes(b) = local_max;
        global_max_y = max(global_max_y, local_max);
    end
    
    fprintf('\n=======================================================================\n');
    fprintf('  EXHAUSTIVE REPORT: %s\n', group_labels{g});
    fprintf('=======================================================================\n');
    
    %% Step B: Cross-Sectional Analysis (Within Each Bin)
    fprintf(' [CROSS-SECTIONAL LAYERS]:\n');
    for b = 1:num_bins
        bin_slice = squeeze(g_data(:, b, :)); 
        p1_idx = [1, 2, 1]; p2_idx = [2, 3, 3];
        bracket_colors = [0.55 0.20 0.55; 0.15 0.55 0.55; 0.35 0.35 0.35];
                      
        local_ceiling = bin_local_maxes(b) + 0.08;
        visible_bracket_count = 0;
        
        for pair = 1:3
            idxA = p1_idx(pair); idxB = p2_idx(pair);
            valA = bin_slice(:, idxA); valB = bin_slice(:, idxB);
            
            matched_mask = ~isnan(valA) & ~isnan(valB);
            xA = valA(matched_mask); xB = valB(matched_mask);
            n_pairs = length(xA);
            mean_diff = mean(xB) - mean(xA);
            
            if n_pairs >= 2
                diff_vec = xB - xA;
                if std(diff_vec) > 0
                    t_stat = mean(diff_vec) / (std(diff_vec) / sqrt(n_pairs));
                    p_val = 2 * (1 - tcdf(abs(t_stat), n_pairs - 1));
                else
                    p_val = 1.0; 
                end
            else
                p_val = NaN;
            end
            
            log_fieldname = sprintf('%s_Bin%d_PC%dto%d', p_prefix, b, idxA, idxB);
            cross_sectional_stats.(log_fieldname).delta_mean = mean_diff;
            cross_sectional_stats.(log_fieldname).p_value = p_val;
            
            if ~isnan(p_val) && p_val < 0.05
                fprintf('    • Bin %d | PC%d vs PC%d -> Delta = %5.2f | p = %.4f*\n', b, idxA, idxB, mean_diff, p_val);
                
                if p_val < 0.001,     p_str = 'p<0.001***';
                elseif p_val < 0.01,  p_str = sprintf('\\Delta:%.2f\np=%.3f**', mean_diff, p_val);
                else,                 p_str = sprintf('\\Delta:%.2f\np=%.3f*', mean_diff, p_val);
                end
                
                x1 = b + pc_offsets(idxA); x2 = b + pc_offsets(idxB);
                y_bar = local_ceiling + (visible_bracket_count * 0.15); 
                tick_h = 0.02; 
                
                plot([x1, x1, x2, x2], [y_bar-tick_h, y_bar, y_bar, y_bar-tick_h], ...
                    'Color', bracket_colors(pair,:), 'LineWidth', 1.3, 'HandleVisibility', 'off');
                
                text((x1+x2)/2, y_bar + 0.01, p_str, 'Color', bracket_colors(pair,:), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
                
                visible_bracket_count = visible_bracket_count + 1;
            end
        end
        bin_local_maxes(b) = local_ceiling + (visible_bracket_count * 0.15);
    end
    
    %% Step C: All-to-All Longitudinal Matrix Analysis (Any Time Point Shift)
    fprintf('\n [ALL-TO-ALL LONGITUDINAL SHIFTS]:\n');
    longitudinal_ceiling = max(bin_local_maxes) + 0.12;
    longitudinal_bracket_layer = 0;
    
    % Comprehensive combinatorial scanning loop
    for b1 = 1:(num_bins - 1)
        for b2 = (b1 + 1):num_bins
            for p = 1:num_pcs
                val_t1 = g_data(:, b1, p);
                val_t2 = g_data(:, b2, p);
                
                matched_mask = ~isnan(val_t1) & ~isnan(val_t2);
                x_t1 = val_t1(matched_mask);
                x_t2 = val_t2(matched_mask);
                n_pairs = length(x_t1);
                mean_diff = mean(x_t2) - mean(x_t1);
                
                if n_pairs >= 2
                    diff_vec = x_t2 - x_t1;
                    if std(diff_vec) > 0
                        t_stat = mean(diff_vec) / (std(diff_vec) / sqrt(n_pairs));
                        p_val = 2 * (1 - tcdf(abs(t_stat), n_pairs - 1));
                    else
                        p_val = 1.0;
                    end
                else
                    p_val = NaN;
                end
                
                log_fieldname = sprintf('%s_PC%d_Bin%dto%d', p_prefix, p, b1, b2);
                longitudinal_bin_stats.(log_fieldname).pc_channel = p;
                longitudinal_bin_stats.(log_fieldname).transition = sprintf('%s to %s', x_labels{b1}, x_labels{b2});
                longitudinal_bin_stats.(log_fieldname).delta_mean = mean_diff;
                longitudinal_bin_stats.(log_fieldname).p_value = p_val;
                
                % Render if significant
                if ~isnan(p_val) && p_val < 0.05
                    fprintf('    • PC%d | %s vs %s -> Delta = %5.2f | p = %.4f*\n', ...
                        p, x_labels{b1}, x_labels{b2}, mean_diff, p_val);
                    
                    if p_val < 0.001,     p_str = sprintf('PC%d [%d\\rightarrow%d] \\Delta:%.2f\np<0.001***', p, b1-1, b2-1, mean_diff);
                    elseif p_val < 0.01,  p_str = sprintf('PC%d [%d\\rightarrow%d] \\Delta:%.2f\np=%.3f**', p, b1-1, b2-1, mean_diff, p_val);
                    else,                 p_str = sprintf('PC%d [%d\\rightarrow%d] \\Delta:%.2f\np=%.3f*', p, b1-1, b2-1, mean_diff, p_val);
                    end
                    
                    % Anchor coordinates connect the same channel across the specified bins
                    x1 = b1 + pc_offsets(p);
                    x2 = b2 + pc_offsets(p);
                    
                    y_bar = longitudinal_ceiling + (longitudinal_bracket_layer * 0.20);
                    tick_h = 0.04;
                    
                    % Render a high-arched bridge bridging the target timeframes
                    plot([x1, x1, x2, x2], [y_bar-tick_h, y_bar, y_bar, y_bar-tick_h], ...
                        'Color', pc_colors(p,:), 'LineWidth', 1.5, 'LineStyle', '-', 'HandleVisibility', 'off');
                    
                    text((x1+x2)/2, y_bar + 0.01, p_str, 'Color', pc_colors(p,:), ...
                        'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
                    
                    longitudinal_bracket_layer = longitudinal_bracket_layer + 1;
                end
            end
        end
    end
    
    global_max_y = longitudinal_ceiling + (longitudinal_bracket_layer * 0.20) + 0.15;
    
    % Step D: Figure Customization & Fine-Tuning
    title(group_labels{g}, 'FontSize', 16, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:num_bins, 'XTickLabel', x_labels, 'FontSize', 13, 'FontWeight', 'bold');
    xtickangle(ax, 35);
    xlim([0.4, num_bins + 0.6]);
    ylim([0, global_max_y]); 
    
    plot([0.4, num_bins + 0.6], [1.0, 1.0], '--k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    text(0.42, 1.05, 'Baseline Ref', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
    
    if g == 1
        ylabel('Relative Latency Fold-Change (Pre = 1.0)', 'FontSize', 14, 'FontWeight', 'bold');
        for p=1:3
            plot(NaN,NaN,'Color',pc_colors(p,:),'Marker',pc_markers{p},'LineWidth',3.0,...
                'MarkerFaceColor','w','DisplayName',sprintf('PC%d ROI', p));
        end
        legend('Location', 'southwest', 'FontSize', 13, 'Box', 'off');
    end
end

% Assign structures to workspace
assignin('base', 'cross_sectional_stats', cross_sectional_stats);
assignin('base', 'longitudinal_bin_stats', longitudinal_bin_stats);
fprintf('\n>>> Full matrix tracking operational. Workspace variables saved.\n');