%% ========================================================================
%  DT-ONLY BINNED SPATIAL SPECIFICITY ANALYSIS WITH DUAL-TONE INTERACTION ENGINE
% ========================================================================
% 1. DATA EXTRACTION: Extracts 10kHz and 30kHz trial traces inside the 10kHz focus.
% 2. ROW FIX: Scans the ENTIRE spreadsheet row space to capture DT trials above C1.
% 3. PATH VERIFICATION: Intelligently ensures trailing slashes are handled before loading .tif files.
% 4. CASE SAFETY NET: Handles workspace variables named with either 'kHz' or 'KHz'.
% 5. PAIRWISE REANALYSIS: Evaluates whether local FUS gain acts as a blind spatial 
%    blanket or varies depending on the acoustic driving frequency.
% 6. CLUTTER-FREE PLOTTING: Removes trend lines and displays brackets ONLY if p < 0.05.
% ========================================================================

rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx';

fprintf('\n===================================================\n');
fprintf(' INITIALIZING DUAL-TONE GAIN SPATIAL SPECIFICITY\n');
fprintf('===================================================\n');

%% 1. LOAD SPREADSHEET DATA (ROBUST FULL TABLE SCAN)
if ~exist(filename, 'file')
    error('Spreadsheet not found: %s. Check your working directory path.', filename);
end

% Read the full table without throwing away rows above C1
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', true);

% Clean up potential string whitespace anomalies using standard MATLAB built-in 'strip'
expTypeCol = strip(string(rawTable{:, 1}));

% Build an index of rows starting with "DT" across the entire document footprint
all_dt_rows = find(startsWith(expTypeCol, 'DT', 'IgnoreCase', true));

if isempty(all_dt_rows)
    fprintf('\n[!] DIAGNOSTIC REPORT: No rows starting with ''DT'' found.\n');
    fprintf('    First few entries found in Column 1:\n');
    for i = 1:min(10, length(expTypeCol))
        fprintf('    Row %d: "%s"\n', i, expTypeCol(i));
    end
    error('Parsing failed. Please verify that Column 1 contains your DT identifiers.');
end

% Extract unique base IDs (e.g., "DT1" from "DT1_10")
baseIDs = cell(length(all_dt_rows), 1);
for i = 1:length(all_dt_rows)
    str = expTypeCol(all_dt_rows(i));
    parts = split(str, '_');
    baseIDs{i} = char(parts{1}); 
end

uniqueExps = unique(baseIDs, 'stable');
num_exps = length(uniqueExps);
fprintf('Found %d unique DT experiments across %d spreadsheet rows\n', num_exps, length(all_dt_rows));

%% 2. GLOBAL PIPELINE PARAMETERS
baseline_idx = 50:55; 
resp_win = 56:100; 
numpix = [800, 800];
fs = 18.57; 
drift_sec = 10; 
drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');
THRESH_SD = 0.5;        
FINAL_Z   = 5.0;        

num_bins = 10;
G10_all = nan(num_exps, num_bins); % 10k stim @ 10k ROI
G30_all = nan(num_exps, num_bins); % 30k stim @ 10k ROI

%% 3. MAIN ACQUISITION LOOP
for idx = 1:num_exps
    baseID = uniqueExps{idx};
    fprintf('\n--> Processing %s\n', baseID);
    
    % Track corresponding spreadsheet rows for this experiment
    match_indices = all_dt_rows(strcmp(baseIDs, baseID));
    r_10 = NaN;
    for m = 1:length(match_indices)
        row_idx = match_indices(m);
        if contains(expTypeCol(row_idx), '_10')
            r_10 = row_idx; 
            break;
        end
    end
    if isnan(r_10), r_10 = match_indices(1); end
    
    % --- LOAD PC1 MAPS (WITH CASE-INSENSITIVE SAFETY CHECK) ---
    var10 = sprintf('PC1_%s_10kHz_norm_upscaled', baseID);
    var30 = sprintf('PC1_%s_30kHz_norm_upscaled', baseID);
    
    % Fallback option to check if workspace uses 'KHz' instead of 'kHz'
    if ~exist(var10, 'var')
        var10_alt = sprintf('PC1_%s_10KHz_norm_upscaled', baseID);
        if exist(var10_alt, 'var'), var10 = var10_alt; end
    end
    if ~exist(var30, 'var')
        var30_alt = sprintf('PC1_%s_30KHz_norm_upscaled', baseID);
        if exist(var30_alt, 'var'), var30 = var30_alt; end
    end
    
    if ~exist(var10, 'var') || ~exist(var30, 'var')
        fprintf('  [!] Missing upscaled PC1 reference maps in workspace for %s (Checked both kHz and KHz)\n', baseID);
        continue;
    end
    
    PC1_10 = eval(var10);
    PC1_30 = eval(var30);
    
    % --- DEFINE ROIs ---
    mask_10 = (PC1_10 > 0.9);
    mask_30 = (PC1_30 > 0.9);
    masks = {mask_10, mask_30};
    num_rois = 2;
    
    % --- PATH RESOLUTION (Using exact column names from your table) ---
    baseDir = char(rawTable{r_10, 'Folder path'});
    numPre  = double(rawTable{r_10, 'number of pre set 1 trials'});
    numPost = double(rawTable{r_10, 'number of post trials'});
    
    prePath_10  = fullfile(baseDir, 'pre_10kHz_set_1');
    prePath_30  = fullfile(baseDir, 'pre_30kHz_set_1'); 
    postPath_10 = fullfile(baseDir, 'post_10kHz_set_1');
    postPath_30 = fullfile(baseDir, 'post_30kHz_set_1');
    
    try
        % --- EXTRACT PRE BASELINES ---
        fprintf('  Extracting PRE 10kHz...');
        pre_traces_10 = robust_multimask_extract(prePath_10, 1, numPre, ...
            numpix, baseline_idx, masks, num_rois);
            
        fprintf('\n  Extracting PRE 30kHz...');
        pre_traces_30 = robust_multimask_extract(prePath_30, 1, numPre, ...
            numpix, baseline_idx, masks, num_rois);
        
        pre_peaks_10 = nan(2,1);
        pre_peaks_30 = nan(2,1);
        
        for roi_idx = 1:2
            [pre_peaks_10(roi_idx), ~] = apply_strict_qc( ...
                pre_traces_10(:,:,roi_idx), baseline_idx, resp_win, ...
                detrendTrace, THRESH_SD, 0);
                
            [pre_peaks_30(roi_idx), ~] = apply_strict_qc( ...
                pre_traces_30(:,:,roi_idx), baseline_idx, resp_win, ...
                detrendTrace, THRESH_SD, 0);
        end
        
        % --- POST-FUS TIME BINNING ---
        binEdges = 1:10:numPost;
        for b = 1:min(length(binEdges), num_bins)
            startT = binEdges(b);
            endT   = min(startT + 9, numPost);
            
            fprintf('\n  Bin %d (%d-%d)...', b, startT, endT);
            
            post10 = robust_multimask_extract(postPath_10, startT, endT, ...
                numpix, baseline_idx, masks, num_rois);
            
            post30 = robust_multimask_extract(postPath_30, startT, endT, ...
                numpix, baseline_idx, masks, num_rois);
            
            % Isolate ROI 1 (The 10kHz Focus Centroid Location)
            roi = 1; 
            
            [p10, ~] = apply_strict_qc(post10(:,:,roi), ...
                baseline_idx, resp_win, detrendTrace, THRESH_SD, FINAL_Z);
            
            [p30, ~] = apply_strict_qc(post30(:,:,roi), ...
                baseline_idx, resp_win, detrendTrace, THRESH_SD, FINAL_Z);
            
            % Baseline Normalization
            if ~isnan(pre_peaks_10(roi))
                G10_all(idx, b) = p10 / (pre_peaks_10(roi) + eps);
            end
            if ~isnan(pre_peaks_30(roi))
                G30_all(idx, b) = p30 / (pre_peaks_30(roi) + eps);
            end
        end
        fprintf('\n');
    catch ME
        fprintf('\n  [!] ERROR RUNNING SUBJECT %s: %s\n', baseID, ME.message);
    end
end

%% ============================================================
% 4. REANALYSIS STATISTICAL INTERACTION ENGINE
% =============================================================
valid_mask = ~isnan(G10_all) & ~isnan(G30_all);
clean_G10 = G10_all; clean_G10(~valid_mask) = NaN;
clean_G30 = G30_all; clean_G30(~valid_mask) = NaN;

mean10 = nanmean(clean_G10, 1);
mean30 = nanmean(clean_G30, 1);
sem10  = nanstd(clean_G10, [], 1) ./ sqrt(sum(~isnan(clean_G10), 1));
sem30  = nanstd(clean_G30, [], 1) ./ sqrt(sum(~isnan(clean_G30), 1));

dual_tone_interaction_stats = struct();

fprintf('\n=======================================================================\n');
fprintf('  DUAL-TONE MECHANISTIC GAIN READOUT (10kHz Focus Zone Analysis)\n');
fprintf('=======================================================================\n');

bin_local_maxes = zeros(num_bins, 1);
for b = 1:num_bins
    v10 = clean_G10(:, b);
    v30 = clean_G30(:, b);
    
    matched_idx = find(~isnan(v10) & ~isnan(v30));
    n_pairs = length(matched_idx);
    
    if n_pairs >= 2
        x10 = v10(matched_idx);
        x30 = v30(matched_idx);
        
        diff_vec = x30 - x10;
        mean_diff = mean(diff_vec);
        
        if std(diff_vec) > 0
            t_stat = mean(diff_vec) / (std(diff_vec) / sqrt(n_pairs));
            p_val = 2 * (1 - tcdf(abs(t_stat), n_pairs - 1));
        else
            p_val = 1.0;
        end
        
        log_name = sprintf('Bin%d_10kHz_vs_30kHz', b);
        dual_tone_interaction_stats.(log_name).time_bin = sprintf('Bin %d', b);
        dual_tone_interaction_stats.(log_name).delta_gain = mean_diff;
        dual_tone_interaction_stats.(log_name).p_value = p_val;
        dual_tone_interaction_stats.(log_name).n_samples = n_pairs;
        
        fprintf('  • Time Bin %2d | Gain Delta (30k-10k) = %6.2f | p = %.4f ', b, mean_diff, p_val);
        if p_val < 0.05
            fprintf('[SIGNIFICANT]*\n');
        else
            fprintf('[NOT SIGNIFICANT]\n');
        end
        bin_local_maxes(b) = max([x10; x30; mean10(b)+sem10(b); mean30(b)+sem30(b)]);
    else
        fprintf('  • Time Bin %2d | Insufficient matched pairs (n=%d). Skipping.\n', b, n_pairs);
        bin_local_maxes(b) = 1.2;
    end
end
global_max_y = max(bin_local_maxes);

%% ============================================================
% 5. PLOT PANEL (CLEAN STRIPPED TREND LINES)
% =============================================================
figDT = figure(15000); clf;
set(figDT, 'Color', 'w', 'Position', [100 100 1100 750]);
ax = axes('Parent', figDT); hold on; grid on;
set(ax, 'GridLineStyle', ':', 'GridAlpha', 0.4, 'LineWidth', 1.5, 'FontSize', 13, 'FontWeight', 'bold');

offset10 = -0.18;
offset30 =  0.18;

for b = 1:num_bins
    v10 = clean_G10(:, b); valid10 = v10(~isnan(v10));
    v30 = clean_G30(:, b); valid30 = v30(~isnan(v30));
    
    if ~isempty(valid10)
        scatter(ones(size(valid10))*b + offset10, valid10, 50, [0.85 0.15 0.15], ...
            'o', 'filled', 'MarkerFaceAlpha', 0.12, 'HandleVisibility', 'off');
        errorbar(b + offset10, mean10(b), sem10(b), 'Color', [0.85 0.15 0.15], 'LineWidth', 3.0, ...
            'Marker', 'o', 'MarkerSize', 11, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.85 0.15 0.15], 'HandleVisibility', 'off');
    end
    
    if ~isempty(valid30)
        scatter(ones(size(valid30))*b + offset30, valid30, 50, [0.15 0.45 0.85], ...
            's', 'filled', 'MarkerFaceAlpha', 0.12, 'HandleVisibility', 'off');
        errorbar(b + offset30, mean30(b), sem30(b), 'Color', [0.15 0.45 0.85], 'LineWidth', 3.0, ...
            'Marker', 's', 'MarkerSize', 11, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.15 0.45 0.85], 'HandleVisibility', 'off');
    end
end

for b = 1:num_bins
    log_name = sprintf('Bin%d_10kHz_vs_30kHz', b);
    if isfield(dual_tone_interaction_stats, log_name)
        p_val = dual_tone_interaction_stats.(log_name).p_value;
        d_gain = dual_tone_interaction_stats.(log_name).delta_gain;
        
        if ~isnan(p_val) && p_val < 0.05
            if p_val < 0.001,     p_str = sprintf('\\Delta:%.2f\np<0.001***', d_gain);
            elseif p_val < 0.01,  p_str = sprintf('\\Delta:%.2f\np=%.3f**', d_gain, p_val);
            else,                 p_str = sprintf('\\Delta:%.2f\np=%.3f*', d_gain, p_val);
            end
            
            x1 = b + offset10;
            x2 = b + offset30;
            
            y_bar = bin_local_maxes(b) + (global_max_y * 0.06);
            tick_h = global_max_y * 0.018;
            
            plot([x1, x1, x2, x2], [y_bar-tick_h, y_bar, y_bar, y_bar-tick_h], ...
                'Color', [0.3 0.3 0.3], 'LineWidth', 1.4, 'HandleVisibility', 'off');
            
            text((x1+x2)/2, y_bar + (global_max_y * 0.01), p_str, 'Color', [0.2 0.2 0.2], ...
                'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            
            global_max_y = max(global_max_y, y_bar + (global_max_y * 0.15));
        end
    end
end

xlabel('Time Bin (10 Trials Each)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Relative Gain Change (Normalized to Baseline)', 'FontSize', 14, 'FontWeight', 'bold');
title('Mechanistic Gain Profiling: 10kHz vs 30kHz Probe inside 10kHz Focus', 'FontSize', 15, 'FontWeight', 'bold');

xlim([0.4, num_bins + 0.6]);
ylim([0, global_max_y]);
set(ax, 'XTick', 1:num_bins);

plot([0.4, num_bins + 0.6], [1.0, 1.0], '--k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
text(0.45, 1.04, 'Baseline Ref', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.4]);

plot(NaN, NaN, 'Color', [0.85 0.15 0.15], 'Marker', 'o', 'LineWidth', 3.0, 'MarkerFaceColor', 'w', 'DisplayName', '10 kHz Probe');
plot(NaN, NaN, 'Color', [0.15 0.45 0.85], 'Marker', 's', 'LineWidth', 3.0, 'MarkerFaceColor', 'w', 'DisplayName', '30 kHz Probe');
legend('Location', 'southwest', 'FontSize', 12, 'Box', 'off');

assignin('base', 'dual_tone_interaction_stats', dual_tone_interaction_stats);
fprintf('\n>>> Processing complete. Array variables exported to workspace base.\n');


%% ============================================================
% 6. PIPELINE HELPER FUNCTIONS (WITH ROBUST DIR CHECKS)
% =============================================================
function all_mask_traces = robust_multimask_extract(basename, startT, endT, numpix, base_idx, masks, num_brackets)
    num_trials = endT - startT + 1;
    
    % Suffix Check: Dynamically inject character file separators if omitted in folder parameters
    if ~endsWith(basename, filesep) && ~endsWith(basename, '/') && ~endsWith(basename, '\')
        testFile = [basename int2str(startT) '.tif'];
        if ~exist(testFile, 'file')
            basename = [basename filesep]; % Inject explicit folder divider
        end
    end
    
    firstFile = [basename int2str(startT) '.tif'];
    if ~exist(firstFile, 'file')
        error('File missing: %s. Check suffix path string structure.', firstFile); 
    end
    
    info = imfinfo(firstFile); 
    nImg = numel(info);
    all_mask_traces = zeros(nImg, num_trials, num_brackets);
    
    for i = startT:endT
        t_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        fprintf(' F%d', i);
        
        oldW = warning('off', 'all');
        f = zeros(numpix(1), numpix(2), nImg, 'uint16');
        tObj = Tiff(filename, 'r');
        for j = 1:nImg
            f(:,:,j) = tObj.read();
            if ~tObj.lastDirectory(), tObj.nextDirectory(); end
        end
        close(tObj);
        warning(oldW);
        
        sf = zeros(size(f));
        for j = 1:nImg
            sf(:,:,j) = imgaussfilt(double(f(:,:,j)), 10);
        end
        b_img = mean(sf(:,:,base_idx), 3);
        dFF = (sf - b_img) ./ (b_img + eps);
        flat_dFF = reshape(dFF, [], nImg);
        
        for p = 1:num_brackets
            all_mask_traces(:, t_idx, p) = mean(flat_dFF(masks{p}(:), :), 1)';
        end
    end
    fprintf(' |');
end

function [mean_peak, m_keep] = apply_strict_qc(traces, base_idx, resp_win, detrend_fn, thresh_sd, min_z)
    m_keep = false(1, size(traces, 2));
    for t = 1:size(traces, 2)
        tr = detrend_fn(traces(:,t));
        tr = tr - mean(tr(base_idx));
        sd_base = std(tr(base_idx));
        z_score = max(tr(resp_win)) / (sd_base + eps);
        if sd_base <= thresh_sd && z_score >= min_z
            m_keep(t) = true;
        end
    end
    if sum(m_keep) == 0
        mean_peak = NaN;
    else
        clean_tr = detrend_fn(mean(traces(:, m_keep), 2));
        mean_peak = max(clean_tr(resp_win) - mean(clean_tr(base_idx)));
    end
end