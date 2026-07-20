%% ULTIMATE FUNCTIONAL PC1 PIPELINE: FAST TIFF + STRICT QC + TRACE SAVING
% -------------------------------------------------------------------------
% 1. Reads TIFFs ONCE and applies N PC1 percentile masks simultaneously.
% 2. Applies STRICT QC (SD <= 0.5, Z >= 5.0) trial-by-trial.
% 3. SAVES ALL RAW TRACES and QC pass/fail flags to 'all_results' struct.
% 4. Calculates physiological rundown uniquely for EACH bracket.
% 5. Generates the Clean Dashboard and exports exact stats to CSV.
% -------------------------------------------------------------------------
% NO CLEARVARS. Your workspace is safe.

rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx';

% Initialize Master Struct for Saving Traces
if ~exist('all_results', 'var') || isempty(fieldnames(all_results))
    all_results = struct();
    fprintf('\n>>> Initializing new all_results struct to save raw traces.\n');
end

% 1. Load Experiment Summary
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

% Global Params
baseline_idx = 50:55; 
resp_win = 56:100; 
numpix = [800, 800];
fs = 18.57; drift_sec = 10; drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');

THRESH_SD = 0.5;        
FINAL_Z   = 5.0;        

% --- EXPANDED PERCENTILE BINS ---
percentile_bins = [0.9, 1.0; 
                   0.8, 0.9; 
                   0.7, 0.8; 
                   0.6, 0.7; 
                   0.5, 0.6;
                   0.4, 0.5;
                   0.3, 0.4;
                   0.2, 0.3;
                   0.1, 0.2]; 
bracket_labels = {'Top 10%', '80-90%', '70-80%', '60-70%', '50-60%', '40-50%', '30-40%', '20-30%', '10-20%'};
num_brackets = size(percentile_bins, 1);

%% 2. FAST EXTRACTION, STRICT QC, AND TRACE SAVING LOOP
fprintf('\n======================================================\n');
fprintf(' PART 1: MULTI-MASK TIFF EXTRACTION, QC, & SAVING\n');
fprintf('======================================================\n');
num_exps = height(expSummary);
raw_gains = nan(num_brackets, 10, num_exps);
isC = startsWith(expSummary.ExperimentType, 'C', 'IgnoreCase', true);
isL = startsWith(expSummary.ExperimentType, 'L', 'IgnoreCase', true);
isH = startsWith(expSummary.ExperimentType, 'H', 'IgnoreCase', true);

for r = 1:num_exps
    expID = expSummary.ExperimentType{r};
    baseDir = expSummary.FolderPath{r};
    numPre = expSummary.PreSet1(r);
    numPost = expSummary.PostTotal(r);
    
    if isnan(numPre) || numPre == 0, continue; end
    fprintf('\n--> Processing: %s\n', expID);
    
    % Prep Dynamic Masks
    maskVarName = sprintf('PC1_%s_norm_upscaled', expID);
    if ~exist(maskVarName, 'var')
        fprintf('  [!] SKIPPED: Missing %s.\n', maskVarName); continue;
    end
    rawPC1 = eval(maskVarName);
    masks = cell(num_brackets,1);
    for p = 1:num_brackets
        masks{p} = (rawPC1 > percentile_bins(p,1)) & (rawPC1 <= percentile_bins(p,2)); 
    end
    
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    postPath = fullfile(baseDir, 'post_10kHz_set_1');
    
    try
        % -- Extract & QC Pre-Baseline --
        fprintf('  Extracting Pre-FUS...');
        pre_traces = fast_multimask_extract(prePath, 1, numPre, numpix, baseline_idx, masks, num_brackets);
        pre_peaks = nan(num_brackets,1);
        
        for p = 1:num_brackets
            tr_p = pre_traces(:,:,p);
            [pre_peaks(p), m_keep_pre] = apply_strict_qc(tr_p, baseline_idx, resp_win, detrendTrace, THRESH_SD, 0);
            
            % !!! CRITICAL SAVE STEP: STORE PRE TRACES AND QC FLAGS !!!
            all_results.(expID).spatial(p).pre_raw_traces = tr_p;
            all_results.(expID).spatial(p).pre_m_keep = m_keep_pre;
        end
        
        % -- Extract & QC Post-Bins --
        binEdges = 1:10:numPost;
        for b = 1:length(binEdges)
            startT = binEdges(b); endT = min(startT + 9, numPost);
            fprintf('\n  Bin %d (Trials %d-%d)...', b, startT, endT);
            post_traces = fast_multimask_extract(postPath, startT, endT, numpix, baseline_idx, masks, num_brackets);
            
            for p = 1:num_brackets
                tr_p = post_traces(:,:,p);
                [post_peak, m_keep_post] = apply_strict_qc(tr_p, baseline_idx, resp_win, detrendTrace, THRESH_SD, FINAL_Z);
                
                if ~isnan(post_peak) && ~isnan(pre_peaks(p))
                    raw_gains(p, b, r) = post_peak / (pre_peaks(p) + eps);
                end
                
                % !!! CRITICAL SAVE STEP: STORE POST TRACES, QC FLAGS, AND GAIN !!!
                all_results.(expID).spatial(p).temporal(b).post_raw_traces = tr_p;
                all_results.(expID).spatial(p).temporal(b).m_keep = m_keep_post;
                all_results.(expID).spatial(p).temporal(b).raw_gain = raw_gains(p, b, r);
            end
        end
        fprintf('\n  [%s] Finished Successfully.\n', expID);
    catch ME
        fprintf('\n  [!] ERROR processing %s: %s\n', expID, ME.message);
    end
end

% SAVE THE MASTER WORKSPACE AUTOMATICALLY TO DISK
save('FUS_PC1_AllTraces_QC_Expanded.mat', 'all_results', '-v7.3');
fprintf('\n>>> ALL RAW TRACES SUCCESSFULLY SAVED TO ''FUS_PC1_AllTraces_QC_Expanded.mat''\n');

%% 3. CALCULATE BRACKET-SPECIFIC CONTROL RUNDOWN
fprintf('\n======================================================\n');
fprintf(' PART 2: BRACKET-SPECIFIC RUNDOWN CORRECTION\n');
fprintf('======================================================\n');
bracket_slopes = zeros(num_brackets, 1);
corrected_gains = nan(size(raw_gains));

for p = 1:num_brackets
    % Isolate Control gains for this specific bracket
    c_gains = squeeze(raw_gains(p, :, isC))'; % [num_controls x 10 bins]
    mean_drift = nanmean(c_gains, 1);
    valid_bins = find(~isnan(mean_drift));
    
    if length(valid_bins) > 1
        p_fit = polyfit(valid_bins, mean_drift(valid_bins), 1);
        bracket_slopes(p) = p_fit(1);
    end
    fprintf('Bracket %d (%s) Control Rundown Slope: %.4f per bin\n', p, bracket_labels{p}, bracket_slopes(p));
    
    % Apply correction to ALL experiments for this bracket
    for b = 1:10
        expected_baseline = polyval([bracket_slopes(p), 1.0 - bracket_slopes(p)], b);
        offset = 1.0 - expected_baseline;
        corrected_gains(p, b, :) = raw_gains(p, b, :) + offset;
    end
end

%% 4. PLOT CLEAN DASHBOARD & EXPORT CSV
time_labels = {'Bin 1 (Trials 1-10)', 'Bin 2 (Trials 11-20)', 'Bin 3 (Trials 21-30)', ...
               'Bin 4 (Trials 31-40)', 'Bin 5 (Trials 41-50)', 'Session Average (Bins 1-5)'};
figS = figure(811); clf; set(figS, 'Color', 'w', 'Position', [20 20 1800 950]);
tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'loose');
title(tlo, 'FUS Gain vs PC1 Functional Percentile (Expanded Spatial Bands)', 'FontSize', 24, 'FontWeight', 'bold');

results_cell = {};

for t = 1:6
    ax = nexttile; hold on; grid on;
    if t <= 5
        data_slice = squeeze(corrected_gains(:, t, :)); t_title = time_labels{t};
    else
        data_slice = squeeze(nanmean(corrected_gains(:, 1:5, :), 2)); t_title = time_labels{t};
    end
    
    max_panel_y = 1.5;
    for p = 1:num_brackets
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
                text(xL - 0.12, mL, txt_L, 'FontSize', 10, 'Color', 'b', 'FontWeight', fwL, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
            end
        end
        
        if ~isempty(vH)
            mH = mean(vH); sdH = std(vH);
            errorbar(xH, mH, sdH, 'r', 'LineWidth', 2.5, 'Marker', 'o', 'MarkerSize', 8);
            if length(vH) > 2
                [~, p_H] = safe_1sample_ttest(vH, 1.0); fwH = 'normal'; txt_H = {sprintf('%.2f', mH)};
                if p_H < 0.05, fwH = 'bold'; txt_H{2} = inline_p_formatter(p_H); end
                text(xH + 0.12, mH, txt_H, 'FontSize', 10, 'Color', 'r', 'FontWeight', fwH, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            end
        end
        
        if length(vL) > 2 && length(vH) > 2
            [~, p_anova] = safe_2sample_ttest(vL, vH); 
            if p_anova < 0.05
                top_of_data = max(mL + sdL, mH + sdH); if isnan(top_of_data), top_of_data = 1.5; end
                bracket_y = top_of_data + 0.25; max_panel_y = max(max_panel_y, bracket_y); 
                plot([xL, xL, xH, xH], [bracket_y-0.05, bracket_y, bracket_y, bracket_y-0.05], '-k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
                text(p, bracket_y + 0.1, inline_p_formatter(p_anova), 'FontSize', 11, 'Color', 'k', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                max_panel_y = max(max_panel_y, bracket_y + 0.2);
            end
        end
        max_panel_y = max([max_panel_y, mL + sdL, mH + sdH]);
        results_cell(end+1, :) = {time_labels{t}, bracket_labels{p}, mL, sdL, p_L, mH, sdH, p_H, p_anova};
    end
    
    title(t_title, 'FontSize', 16, 'FontWeight', 'bold');
    
    % Updated for N brackets and tilted text so they don't overlap
    set(ax, 'XTick', 1:num_brackets, 'XTickLabel', bracket_labels, 'FontSize', 11, 'FontWeight', 'bold');
    xtickangle(ax, 30);
    xlim([0.3, num_brackets + 0.7]); 
    ylim([0, max(2.5, max_panel_y + 0.2)]); 
    
    line([0 num_brackets+1], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2.0, 'DisplayName', 'Control Baseline (1.0)');
    if t == 1 || t == 4, ylabel('Corrected Gain Ratio', 'FontSize', 14, 'FontWeight', 'bold'); end
end

dummy_L = plot(NaN,NaN,'sb','MarkerFaceColor','b', 'MarkerSize', 8); dummy_H = plot(NaN,NaN,'or','MarkerFaceColor','r', 'MarkerSize', 8);
dummy_C = plot(NaN,NaN,'--','Color',[0.2 0.7 0.2],'LineWidth',2.0); dummy_B = plot(NaN,NaN,'-k','LineWidth',1.5);
legend([dummy_L, dummy_H, dummy_C, dummy_B], {'Low Power (L)', 'High Power (H)', 'Control Baseline', 'ANOVA (L vs H)'}, 'Location', 'northeast', 'FontSize', 13);

col_names = {'Time_Bin', 'PC1_Bracket', 'Low_Mean_Gain', 'Low_SD', 'Low_vs_Baseline_pval', 'High_Mean_Gain', 'High_SD', 'High_vs_Baseline_pval', 'Low_vs_High_pval'};
StatsTable = cell2table(results_cell, 'VariableNames', col_names);
writetable(StatsTable, 'FUS_PC1_Functional_Stats_Summary_Expanded.csv');
fprintf('\n>>> SUCCESS: Dashboard generated and data exported to FUS_PC1_Functional_Stats_Summary_Expanded.csv.\n\n');

%% --- HELPER FUNCTIONS ---
function all_mask_traces = fast_multimask_extract(basename, startT, endT, numpix, base_idx, masks, num_brackets)
    num_trials = endT - startT + 1;
    firstFile = [basename int2str(startT) '.tif'];
    if ~exist(firstFile, 'file'), error('File missing: %s', firstFile); end
    info = imfinfo(firstFile); nImg = numel(info);
    
    % Preallocate for N brackets dynamically
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
        close(tObj); warning(oldW); 
        
        sf = zeros(size(f));
        for j = 1:nImg, sf(:,:,j) = imgaussfilt(double(f(:,:,j)), 10); end
        b_img = mean(sf(:,:,base_idx), 3);
        dFF = (sf - b_img) ./ (b_img + eps);
        
        flat_dFF = reshape(dFF, [], nImg);
        
        % Extract trace for each dynamically set bracket
        for p = 1:num_brackets
            all_mask_traces(:, t_idx, p) = mean(flat_dFF(masks{p}(:), :), 1)';
        end
    end
    fprintf(' |'); 
end

function [mean_peak, m_keep] = apply_strict_qc(traces, base_idx, resp_win, detrend_fn, thresh_sd, min_z)
    m_keep = false(1, size(traces, 2));
    for t = 1:size(traces, 2)
        tr = detrend_fn(traces(:,t)); tr = tr - mean(tr(base_idx)); 
        sd_base = std(tr(base_idx)); z_score = max(tr(resp_win)) / (sd_base + eps);
        if sd_base <= thresh_sd && z_score >= min_z, m_keep(t) = true; end
    end
    if sum(m_keep) == 0 
        mean_peak = NaN; 
    else
        clean_tr = detrend_fn(mean(traces(:, m_keep), 2));
        mean_peak = max(clean_tr(resp_win) - mean(clean_tr(base_idx)));
    end
end

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