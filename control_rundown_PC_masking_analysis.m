%% FINAL FUS ANALYSIS (V19.0): STRICT QC + PC1 RUNDOWN + CORRECTION
% -------------------------------------------------------------------------
% 1. Extracts "Natural Rundown" from Controls (C) using Top 10% PC1 Mask
% 2. Applies STRICT QC (SD <= 0.5, Z >= 5.0) to Control trials
% 3. Mutes LibTIFF warnings for clean console output
% 4. Loads pre-computed Spatial Ring data for L and H groups
% 5. Corrects L and H for systemic session drift & plots Dashboard
% -------------------------------------------------------------------------

%% 1. CONFIGURATION
clearvars -except PC1_* target_results all_results; 
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

% Global Math & STRICT QC Params
baseline_idx = 50:55; 
resp_win = 56:100; 
numpix = [800, 800];
fs = 18.57; drift_sec = 10; drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');

THRESH_SD = 0.5;        % Strict Baseline Noise Gate
FINAL_Z   = 5.0;        % Strict Peak Response Gate

%% 2. CONTROL RUNDOWN EXTRACTION (WITH STRICT QC)
isControl = startsWith(expSummary.ExperimentType, 'C', 'IgnoreCase', true);
controlSummary = expSummary(isControl, :);
control_gains = nan(height(controlSummary), 10); 

fprintf('\n======================================================\n');
fprintf(' PART 1: EXTRACTING CONTROL RUNDOWN (PC1 Top 10%% + STRICT QC)\n');
fprintf('======================================================\n');

for r = 1:height(controlSummary)
    expID = controlSummary.ExperimentType{r};
    baseDir = controlSummary.FolderPath{r};
    numPre = controlSummary.PreSet1(r);
    numPost = controlSummary.PostTotal(r);
    
    if isnan(numPre) || numPre == 0, continue; end
    fprintf('\n--> Processing Control: %s\n', expID);
    
    maskVarName = sprintf('PC1_%s_norm_upscaled', expID);
    if ~exist(maskVarName, 'var')
        fprintf('  [!] SKIPPED: Missing %s.\n', maskVarName);
        continue;
    end
    rawPC1 = eval(maskVarName);
    active_mask = rawPC1 > 0.9; % TOP 10%
    
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    postPath = fullfile(baseDir, 'post_10kHz_set_1');
    
    try
        % -- Extract & QC Pre-Baseline --
        fprintf('  Extracting Pre-FUS...');
        pre_traces = fast_PC1_extract(prePath, 1, numPre, numpix, baseline_idx, active_mask);
        
        m_pre_keep = false(1, size(pre_traces, 2));
        for t = 1:size(pre_traces, 2)
            tr = detrendTrace(pre_traces(:,t)); tr = tr - mean(tr(baseline_idx));
            if std(tr(baseline_idx)) <= THRESH_SD, m_pre_keep(t) = true; end
        end
        
        if ~any(m_pre_keep)
            fprintf(' [!] ALL PRE-TRIALS FAILED QC.\n'); continue; 
        end
        pre_c = detrendTrace(mean(pre_traces(:, m_pre_keep), 2));
        pre_peak = max(pre_c(resp_win) - mean(pre_c(baseline_idx)));
        
        % -- Extract & QC Post-Bins --
        binEdges = 1:10:numPost;
        for b = 1:length(binEdges)
            startT = binEdges(b); endT = min(startT + 9, numPost);
            fprintf('\n  Bin %d (Trials %d-%d)...', b, startT, endT);
            post_traces = fast_PC1_extract(postPath, startT, endT, numpix, baseline_idx, active_mask);
            
            m_post_keep = false(1, size(post_traces, 2));
            for t = 1:size(post_traces, 2)
                tr = detrendTrace(post_traces(:,t)); tr = tr - mean(tr(baseline_idx));
                sd_base = std(tr(baseline_idx));
                p_resp = max(tr(resp_win));
                z_score = p_resp / (sd_base + eps);
                if sd_base <= THRESH_SD && z_score >= FINAL_Z
                    m_post_keep(t) = true;
                end
            end
            
            if any(m_post_keep)
                post_c = detrendTrace(mean(post_traces(:, m_post_keep), 2));
                post_peak = max(post_c(resp_win) - mean(post_c(baseline_idx)));
                control_gains(r, b) = post_peak / (pre_peak + eps);
                fprintf(' (Kept %d/%d)', sum(m_post_keep), size(post_traces,2));
            else
                control_gains(r, b) = NaN;
                fprintf(' (Kept 0 - Bin Dropped)');
            end
        end
        fprintf('\n  [%s] Finished Successfully.\n', expID);
    catch ME
        fprintf('\n  [!] ERROR: %s\n', ME.message);
    end
end

% Compute the Linear Rundown Slope
mean_control_drift = nanmean(control_gains, 1);
valid_bins = find(~isnan(mean_control_drift));
p_fit = polyfit(valid_bins, mean_control_drift(valid_bins), 1);
fprintf('\n>>> Systemic Rundown Slope Calculated (QC applied): %.4f gain/bin\n', p_fit(1));

%% 3. LOAD SPATIAL DATA FOR L AND H 
fprintf('\n======================================================\n');
fprintf(' PART 2: LOADING L & H SPATIAL DATA\n');
fprintf('======================================================\n');

if ~exist('target_results', 'var'), load('FUS_WideField_TargetResults_FullTraces.mat'); end
expIDs = fieldnames(target_results);
isL = startsWith(expIDs, 'L', 'IgnoreCase', true);
isH = startsWith(expIDs, 'H', 'IgnoreCase', true);

num_exps = numel(expIDs);
raw_spatial_gains = nan(5, 10, num_exps); 

for e = 1:num_exps
    id = expIDs{e};
    if startsWith(id, 'C', 'IgnoreCase', true), continue; end 
    
    for p = 1:5
        pre_c = detrendTrace(mean(target_results.(id).spatial(p).pre_raw_traces, 2));
        denom = max(pre_c(resp_win) - mean(pre_c(baseline_idx)));
        num_b = min(10, numel(target_results.(id).spatial(p).temporal));
        for b = 1:num_b
            post_raw = target_results.(id).spatial(p).temporal(b).all_traces;
            if isempty(post_raw), continue; end
            post_c = detrendTrace(mean(post_raw, 2));
            numr = max(post_c(resp_win) - mean(post_c(baseline_idx)));
            raw_spatial_gains(p, b, e) = numr / (denom + eps);
        end
    end
end

%% 4. APPLY RUNDOWN CORRECTION
corrected_gains = nan(size(raw_spatial_gains));
for b = 1:10
    expected_baseline = polyval(p_fit, b);
    offset = 1.0 - expected_baseline; 
    corrected_gains(:, b, :) = raw_spatial_gains(:, b, :) + offset;
end

%% 5. PLOT CORRECTED 6-PANEL EVOLUTION
labels = {'0-250', '250-500', '500-750', '750-1000', '1000-1250'};
figS = figure(802); clf; set(figS, 'Color', 'w', 'Position', [20 20 1800 950]);
tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'loose');
title(tlo, 'FUS Gain vs Distance (QC-Filtered Physiological Rundown Corrected)', 'FontSize', 22);

for t = 1:6
    ax = nexttile; hold on; grid on;
    if t <= 5
        data_slice = squeeze(corrected_gains(:, t, :));
        t_title = sprintf('Bin %d (Trials %d-%d)', t, (t-1)*10+1, t*10);
    else
        data_slice = squeeze(nanmean(corrected_gains(:, 1:5, :), 2));
        t_title = 'Session Average (Bins 1-5)';
    end

    for p = 1:5
        vL = data_slice(p, isL); vH = data_slice(p, isH);
        
        scatter(p-0.15, vL, 30, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.4, 'HandleVisibility', 'off');
        scatter(p+0.15, vH, 30, [0.8 0.2 0.2], 'filled', 'MarkerFaceAlpha', 0.4, 'HandleVisibility', 'off');
        
        errorbar(p-0.15, nanmean(vL), std(vL,'omitnan')/sqrt(sum(~isnan(vL))), 'b', 'LineWidth', 2.5, 'Marker', 's');
        errorbar(p+0.15, nanmean(vH), std(vH,'omitnan')/sqrt(sum(~isnan(vH))), 'r', 'LineWidth', 2.5, 'Marker', 'o');
        
        if sum(~isnan(vH)) > 2
            [~, p_stat] = ttest(vH, 1.0); 
            if p_stat < 0.05
                text(p+0.15, max(vH)+0.3, '*', 'FontSize', 22, 'Color', 'r', 'HorizontalAlignment', 'center');
            end
        end
    end
    
    title(t_title, 'FontSize', 16);
    set(ax, 'XTick', 1:5, 'XTickLabel', labels, 'FontSize', 12);
    ylim([0.2 3.5]); 
    line([0 6], [1 1], 'Color', [0.2 0.7 0.2], 'LineStyle', '--', 'LineWidth', 2, 'DisplayName', 'Control Baseline (1.0)');
    if t == 1 || t == 4, ylabel('Corrected Gain Ratio'); end
end
legend({'Low Power (L)', 'High Power (H)', 'Control Baseline'}, 'Location', 'northeast');
fprintf('\n>>> Complete! Dashboard generated.\n');

%% --- ULTRA-FAST TIFF READER HELPER (WARNINGS MUTED) ---
function traces = fast_PC1_extract(basename, startT, endT, numpix, baseline_idx, mask)
    num_trials = endT - startT + 1;
    firstFile = [basename int2str(startT) '.tif'];
    if ~exist(firstFile, 'file'), error('File missing: %s', firstFile); end
    
    info = imfinfo(firstFile); nImg = numel(info);
    traces = zeros(nImg, num_trials);
    
    for i = startT:endT
        t_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        fprintf(' F%d', i); 
        
        oldWarningState = warning('off', 'all'); 
        f = zeros(numpix(1), numpix(2), nImg, 'uint16');
        tObj = Tiff(filename, 'r');
        for j = 1:nImg
            f(:,:,j) = tObj.read();
            if ~tObj.lastDirectory(), tObj.nextDirectory(); end
        end
        close(tObj);
        warning(oldWarningState); 
        
        sf = zeros(size(f));
        for j = 1:nImg, sf(:,:,j) = imgaussfilt(double(f(:,:,j)), 10); end
        b_img = mean(sf(:,:,baseline_idx), 3);
        dFF = (sf - b_img) ./ (b_img + eps);
        
        flat_dFF = reshape(dFF, [], nImg);
        traces(:, t_idx) = mean(flat_dFF(mask(:), :), 1)';
    end
    fprintf(' |'); 
end