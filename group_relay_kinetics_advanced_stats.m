%% GROUP RELAY KINETICS (RAW NON-NORMALIZED VISUALIZATION & ANALYTICS)
% -------------------------------------------------------------------------
% 1. TARGETED PANELS: Low Power (L) and High Power (H) cohorts only.
% 2. NO NORMALIZATION: Evaluates raw, non-normalized metrics directly from grand_matrix.
% 3. HORIZONTAL FOOTPRINT WIDENING: Spreads out PC1, PC2, and PC3 within bins.
% 4. DYNAMIC BRACKET SPACING: Scales bracket step intervals based on raw scale heights.
% 5. PUBLICATION TYPOGRAPHY: Crisp, legible font scaling and bold significance flags.
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

% Target low power and high power cohorts exclusively using RAW values
group_matrices_raw = {grand_matrix(isL, :, :), grand_matrix(isH, :, :)};
group_labels = {'Low Power Cohort (L)', 'High Power Cohort (H)'};
group_prefixes = {'L', 'H'};

% Widened Horizontal Offset Footprint (Prevents symbol and line crowding)
pc_colors = [0.85 0.15 0.15;   % PC1: Deep Red
             0.15 0.65 0.15;   % PC2: Emerald Green
             0.15 0.45 0.85];  % PC3: Cobalt Blue
         
pc_offsets = [-0.26, 0.0, 0.26]; 
pc_markers = {'s', '^', 'o'};    

cross_sectional_raw_stats = struct();

%% 2. GENERATE RAW PANELS
figRaw = figure(13000); clf;
set(figRaw, 'Color', 'w', 'Position', [50 50 1600 850]);
tlo = tiledlayout(1, 2, 'TileSpacing', 'loose', 'Padding', 'normal');
title(tlo, 'Raw Intra-Bin Cross-Sectional Cortical Relay Profiling', ...
    'FontSize', 18, 'FontWeight', 'bold');

for g = 1:2
    ax = nexttile; hold on; grid on;
    set(ax, 'GridLineStyle', ':', 'GridAlpha', 0.4, 'LineWidth', 1.5);
    
    g_data = group_matrices_raw{g};
    p_prefix = group_prefixes{g};
    
    if isempty(g_data) || size(g_data, 1) == 0
        title([group_labels{g} ' - No Data Available'], 'Color', 'r', 'FontSize', 14);
        continue;
    end
    
    % Track global plot bounds dynamically
    global_max_y = 0.01;
    bin_local_maxes = zeros(num_bins, 1);
    
    % Step A: Render Raw Jitter Points & Isolated Mean Bars
    for b = 1:num_bins
        local_max = 0.01;
        for p = 1:num_pcs
            raw_pts = g_data(:, b, p);
            valid_pts = raw_pts(~isnan(raw_pts));
            x_pos = b + pc_offsets(p);
            
            if ~isempty(valid_pts)
                m_val = mean(valid_pts);
                s_val = std(valid_pts) / sqrt(length(valid_pts));
                
                % Raw scatter dots
                scatter(ones(size(valid_pts))*x_pos, valid_pts, 60, pc_colors(p,:), ...
                    pc_markers{p}, 'filled', 'MarkerFaceAlpha', 0.14, 'HandleVisibility', 'off');
                
                % High-contrast Mean point + SEM whisker
                errorbar(x_pos, m_val, s_val, 'Color', pc_colors(p,:), 'LineWidth', 3.0, ...
                    'Marker', pc_markers{p}, 'MarkerSize', 11, 'MarkerFaceColor', 'w', ...
                    'MarkerEdgeColor', pc_colors(p,:), 'HandleVisibility', 'off');
                
                local_max = max([local_max, max(valid_pts), m_val + s_val]);
            end
        end
        bin_local_maxes(b) = local_max;
        global_max_y = max(global_max_y, local_max);
    end
    
    % Step B: Run Statistics & Draw Locally-Normalized Static Brackets
    for b = 1:num_bins
        bin_slice = squeeze(g_data(:, b, :)); 
        
        % Mapping definitions (Pair 1: PC1-PC2 | Pair 2: PC2-PC3 | Pair 3: PC1-PC3)
        p1_idx = [1, 2, 1];
        p2_idx = [2, 3, 3];
        bracket_colors = [0.55 0.20 0.55;  % PC1-PC2: Purple
                          0.15 0.55 0.55;  % PC2-PC3: Teal
                          0.35 0.35 0.35]; % PC1-PC3: Charcoal Gray
                      
        % Dynamic structural spacing padding adjusted precisely for raw metric domains
        padding_gap = bin_local_maxes(b) * 0.08;
        step_increment = bin_local_maxes(b) * 0.12;
        tick_h = bin_local_maxes(b) * 0.02;
        
        local_ceiling = bin_local_maxes(b) + padding_gap;
        
        for pair = 1:3
            idxA = p1_idx(pair);
            idxB = p2_idx(pair);
            
            valA = bin_slice(:, idxA);
            valB = bin_slice(:, idxB);
            
            matched_mask = ~isnan(valA) & ~isnan(valB);
            xA = valA(matched_mask);
            xB = valB(matched_mask);
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
            
            % Typography and Weight Selection
            if isnan(p_val)
                stat_txt = sprintf('\\Delta:%.2f\nn<2', mean_diff);
                font_w = 'normal'; font_sz = 9; txt_color = [0.6 0.6 0.6];
            elseif p_val < 0.001
                stat_txt = sprintf('\\Delta:%.2f\np<0.001***', mean_diff);
                font_w = 'bold'; font_sz = 10; txt_color = bracket_colors(pair,:);
            elseif p_val < 0.05
                stat_txt = sprintf('\\Delta:%.2f\np=%.3f*', mean_diff, p_val);
                font_w = 'bold'; font_sz = 10; txt_color = bracket_colors(pair,:);
            else
                stat_txt = sprintf('\\Delta:%.2f\np=%.2f', mean_diff, p_val);
                font_w = 'normal'; font_sz = 9; txt_color = [0.45 0.45 0.45];
            end
            
            % Workspace logging assignment
            log_fieldname = sprintf('%s_Bin%d_PC%dto%d', p_prefix, b, idxA, idxB);
            cross_sectional_raw_stats.(log_fieldname).delta_mean = mean_diff;
            cross_sectional_raw_stats.(log_fieldname).p_value = p_val;
            cross_sectional_raw_stats.(log_fieldname).n_samples = n_pairs;
            
            % Compute visual bracket line span coordinates
            x1 = b + pc_offsets(idxA);
            x2 = b + pc_offsets(idxB);
            
            % Step the lines cleanly based on raw scale parameters to remove collisions
            y_bar = local_ceiling + (pair - 1) * step_increment; 
            
            % Draw geometric drop bracket
            plot([x1, x1, x2, x2], [y_bar-tick_h, y_bar, y_bar, y_bar-tick_h], ...
                'Color', txt_color, 'LineWidth', 1.3, 'HandleVisibility', 'off');
            
            % Render statistical tracking text centered on the horizontal segment
            text((x1+x2)/2, y_bar + (step_increment * 0.08), stat_txt, 'Color', txt_color, ...
                'FontSize', font_sz, 'FontWeight', font_w, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom');
        end
        % Track ultimate canvas peak bounds dynamically per sub-panel
        global_max_y = max(global_max_y, local_ceiling + 3 * step_increment);
    end
    
    % Step C: Figure Customization & Fine-Tuning
    title(group_labels{g}, 'FontSize', 16, 'FontWeight', 'bold');
    set(ax, 'XTick', 1:num_bins, 'XTickLabel', x_labels, 'FontSize', 13, 'FontWeight', 'bold');
    xtickangle(ax, 35);
    xlim([0.4, num_bins + 0.6]);
    ylim([0, global_max_y]); 
    
    if g == 1
        ylabel('Cortical Relay Latency (Raw Values)', 'FontSize', 14, 'FontWeight', 'bold');
        for p=1:3
            plot(NaN,NaN,'Color',pc_colors(p,:),'Marker',pc_markers{p},'LineWidth',3.0,...
                'MarkerFaceColor','w','DisplayName',sprintf('PC%d ROI', p));
        end
        legend('Location', 'southwest', 'FontSize', 13, 'Box', 'off');
    end
end

% Clear functional variables from local scope and save data struct out
assignin('base', 'cross_sectional_raw_stats', cross_sectional_raw_stats);
fprintf('\n>>> Raw processing complete. Data logged to workspace object: "cross_sectional_raw_stats"\n');