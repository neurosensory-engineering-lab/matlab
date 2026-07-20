%% PC_RELAY_CHRONOMETER_V8_GRANDMASTER
% -------------------------------------------------------------------------
% 1. IMREAD OPTIMIZATION: Bypasses Tiff class for warning-free performance.
% 2. FAULT TOLERANCE: Encapsulated in try/catch to protect longitudinal runs.
% 3. RETENTION PIPELINE: Stores unique pre/post latencies inside workspace arrays.
% 4. TRACE DIAGNOSTICS: Dual validation figures displaying raw vs. master averages.
% 5. GRAND SUMMARY ANALYSIS: Automated cohort averaging and line plotting at conclusion.
% -------------------------------------------------------------------------

% --- CONFIGURATION ---
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

% --- GLOBAL PARAMETERS ---
baseline_idx = 50:55;   
resp_win = 56:100;      
tone_onset = 56;
numpix = [800, 800];
fs = 18.57;            
drift_sec = 10; 
drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');
THRESH_SD = 0.5;        
FINAL_Z   = 5.0;        

% 1. Load Experiment Summary
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'L2'), 1);
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

num_exps = height(expSummary);
if ~exist('relay_results', 'var'), relay_results = struct(); end

% Preallocate Matrix for Grand Compilation [Mice x Bins x PCs]
% Bin 1 = Pre-FUS, Bins 2 to 6 = Post-FUS Bins 1 to 5
max_tracked_bins = 5; 
grand_matrix = nan(num_exps, max_tracked_bins + 1, 3);

fprintf('\n>>> Initiating V8 GrandMaster Chronometer Pipeline...\n');

%% 2. MAIN PROCESSING LOOP
for r = 1:num_exps
    expID = expSummary.ExperimentType{r};
    baseDir = expSummary.FolderPath{r};
    numPre = expSummary.PreSet1(r);
    numPost = expSummary.PostTotal(r);
    if isnan(numPre) || numPre == 0, continue; end
    
    fprintf('\n======================================================\n');
    fprintf(' MOUSE [%d/%d]: %s\n', r, num_exps, expID);
    fprintf('======================================================\n');
    
    % Fault-Tolerance Shield: Protects entire execution from folder/file errors
    try
        % Prep PC Maps
        pc1_var = sprintf('PC1_%s_norm_upscaled', expID);
        if ~exist(pc1_var, 'var')
            fprintf('  [!] SKIPPED: Missing spatial maps for %s\n', pc1_var); 
            continue; 
        end
        
        PCs_spatial = zeros(numpix(1)*numpix(2), 3);
        for p = 1:3
            tmp_map = eval(sprintf('PC%d_%s_norm_upscaled', p, expID));
            if any(size(tmp_map) ~= numpix), tmp_map = imresize(tmp_map, numpix); end
            PCs_spatial(:,p) = tmp_map(:);
        end
        
        masks = cell(3,1);
        for p = 1:3, masks{p} = PCs_spatial(:,p) > prctile(PCs_spatial(:,p), 90); end
        
        %% --- PHASE 1: PRE-FUS ---
        prePath = fullfile(baseDir, 'pre_10kHz_set_1');
        fprintf('  Phase: PRE-FUS (%d trials)...\n', numPre);
        [pre_lats, pre_traces, pre_qc] = extract_and_qc_diagnostic(prePath, 1, numPre, numpix, ...
            baseline_idx, resp_win, masks, detrendTrace, THRESH_SD, FINAL_Z, fs);
        
        % Workspace Logging
        relay_results.(expID).pre.latencies = pre_lats;
        grand_matrix(r, 1, :) = pre_lats; % Assign to index 1 (Pre-Baseline)
        
        render_diagnostic_figs(PCs_spatial, masks, pre_lats, pre_traces, pre_qc, expID, 'PRE', r, baseline_idx, fs);
        
        %% --- PHASE 2: POST-FUS BINS ---
        postPath = fullfile(baseDir, 'post_10kHz_set_1');
        binEdges = 1:10:numPost;
        
        for b = 1:length(binEdges)
            if b > max_tracked_bins, break; end % Cap at Bin 5 to match dashboard sizing
            
            startT = binEdges(b); endT = min(startT + 9, numPost);
            fprintf('  Phase: POST Bin %d (T%d-%d)...\n', b, startT, endT);
            
            [post_lats, post_traces, post_qc] = extract_and_qc_diagnostic(postPath, startT, endT, numpix, ...
                baseline_idx, resp_win, masks, detrendTrace, THRESH_SD, FINAL_Z, fs);
            
            % Workspace Logging
            relay_results.(expID).post(b).latencies = post_lats;
            grand_matrix(r, b + 1, :) = post_lats; % Shift by 1 to accommodate Pre index
            
            if ~all(isnan(post_lats))
                render_diagnostic_figs(PCs_spatial, masks, post_lats, post_traces, post_qc, expID, sprintf('POST Bin %d', b), r+b, baseline_idx, fs);
            end
        end
        
        fprintf('\n  [+] Completed Processing for %s successfully.\n', expID);
        
    catch ME
        % Error-Interception block prevents workspace lock or crash
        fprintf('\n  [!!!] RUNTIME WARNING: Problem handling experiment %s.\n', expID);
        fprintf('        Error Context: %s\n', ME.message);
        fprintf('        Skipping to next experiment block cleanly...\n');
    end
end

% Save Structured Variable data safely to disk
save('FUS_Relay_Timings_V8_Workspace.mat', 'relay_results', 'grand_matrix');
fprintf('\n>>> Workspace tracking matrices saved to FUS_Relay_Timings_V8_Workspace.mat\n');

%% 3. COHORT-LEVEL GRAND ANALYSIS & VISUALIZATION
fprintf('\n======================================================\n');
fprintf(' PART 3: COHORT GRAND ANALYSIS GENERATION\n');
fprintf('======================================================\n');

% Compute means and standard error across valid animals
mean_latencies = squeeze(nanmean(grand_matrix, 1)); % Resulting shape: [Bins x PCs]
num_valid_mice = sum(~isnan(grand_matrix(:, :, 1)), 1); % Track count per bin

figGrand = figure(999); clf;
set(figGrand, 'Color', 'w', 'Position', [100 100 900 600]);
hold on; grid on;

pc_colors = [1 0.2 0.2; 0.2 1 0.2; 0.2 0.6 1]; % Red, Green, Blue
pc_labels = {'PC1 ROI', 'PC2 ROI', 'PC3 ROI'};
x_bins = 1:(max_tracked_bins + 1);

for p = 1:3
    y_vals = mean_latencies(:, p)';
    
    % Calculate Standard Error of the Mean (SEM) unique to each position
    sem_vals = zeros(1, max_tracked_bins + 1);
    for b = 1:(max_tracked_bins + 1)
        slice_data = grand_matrix(:, b, p);
        valid_data = slice_data(~isnan(slice_data));
        if length(valid_data) > 1
            sem_vals(b) = std(valid_data) / sqrt(length(valid_data));
        else
            sem_vals(b) = 0;
        end
    end
    
    % Draw the variance fields using shaded error bars or errorbars
    errorbar(x_bins, y_vals, sem_vals, 'Color', pc_colors(p,:), 'LineWidth', 3, ...
        'Marker', 'o', 'MarkerSize', 8, 'MarkerFaceColor', pc_colors(p,:), ...
        'DisplayName', pc_labels{p});
end

% Configure Plot Environment
set(gca, 'XTick', x_bins, 'XTickLabel', ...
    {'Pre-FUS', 'Post Bin 1', 'Post Bin 2', 'Post Bin 3', 'Post Bin 4', 'Post Bin 5'}, ...
    'FontSize', 12, 'FontWeight', 'bold');
xtickangle(45);

ylabel('Activation Latency / Time-to-Peak (ms)', 'FontSize', 14, 'FontWeight', 'bold');
title({'Grand Cohort Relay Kinetics Summary', 'Longitudinal Evolution Across FUS Blocks'}, ...
    'FontSize', 16, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 12);
ylim([0 max(mean_latencies(:)) + 20]);

drawnow;
fprintf('>>> Cohort Grand Summary Figure Constructed Successfully.\n\n');

%% --- HELPER FUNCTIONS (V7 DIAGNOSTIC COMPATIBLE) ---

function [latencies, master_traces, qc_flags] = extract_and_qc_diagnostic(path, sT, eT, pix, b_idx, r_win, masks, detrend_fn, thr_sd, min_z, fs)
    num_trials = eT - sT + 1;
    latencies = nan(1,3);
    
    warnState = warning('off', 'all'); cleanupObj = onCleanup(@() warning(warnState));
    firstFile = [path int2str(sT) '.tif'];
    if ~exist(firstFile, 'file'), error('Base image block file missing: %s', firstFile); end
    info = imfinfo(firstFile); nImg = numel(info);
    raw_roi_traces = zeros(nImg, num_trials, 3);
    
    for i = sT:eT
        t_idx = i - sT + 1;
        fname = [path int2str(i) '.tif'];
        if ~exist(fname, 'file'), continue; end
        f = zeros(pix(1), pix(2), nImg, 'single');
        for j = 1:nImg, f(:,:,j) = imread(fname, j); end
        b_img = mean(f(:,:,1:10), 3); 
        dFF = (f - b_img) ./ (b_img + eps);
        flat_dFF = reshape(dFF, [], nImg);
        for p = 1:3, raw_roi_traces(:, t_idx, p) = mean(flat_dFF(masks{p}, :), 1)'; end
    end
    
    master_traces = cell(1,3);
    qc_flags = false(num_trials, 3);
    
    for p = 1:3
        tr_p = raw_roi_traces(:,:,p); 
        for t = 1:num_trials
            proj_t = detrend_fn(tr_p(:,t));
            proj_t = proj_t - mean(proj_t(b_idx));
            sd_base = std(proj_t(b_idx));
            z_score = max(proj_t(r_win)) / (sd_base + eps);
            if sd_base <= thr_sd && z_score >= min_z, qc_flags(t, p) = true; end
        end
        
        master_traces{p} = tr_p; 
        if any(qc_flags(:,p))
            m_avg = mean(tr_p(:, qc_flags(:,p)), 2);
            m_avg = detrend_fn(m_avg); m_avg = m_avg - mean(m_avg(b_idx));
            [~, pk] = max(m_avg(r_win));
            latencies(p) = (r_win(pk) - r_win(1)) / fs * 1000;
            fprintf('    ROI PC%d: %d/%d trials passed QC. Latency: %.1f ms\n', p, sum(qc_flags(:,p)), num_trials, latencies(p));
        else
            fprintf('    ROI PC%d: 0 trials passed QC. Latency: NaN\n', p);
        end
    end
end

function render_diagnostic_figs(PCs, masks, lats, traces, qc, id, phase, r, b_idx, fs)
    colors = [1 0.2 0.2; 0.2 1 0.2; 0.2 0.6 1];
    
    % FIG 1: Cortical Map
    figure(r*10); clf; set(gcf,'Color','w','Units','normalized','Position',[0.1 0.4 0.3 0.4]);
    bg = reshape(PCs(:,1), 800, 800);
    imagesc(bg); colormap(gray); axis image; axis off; hold on; alpha(0.2);
    for p = 1:3
        m = reshape(masks{p}, 800, 800);
        roi_rgb = cat(3, ones(800,800)*colors(p,1), ones(800,800)*colors(p,2), ones(800,800)*colors(p,3));
        h = imagesc(roi_rgb); set(h, 'AlphaData', m * 0.6);
        [rows, cols] = find(m); cx = mean(cols); cy = mean(rows);
        text(cx, cy, sprintf(' PC%d: %.1f ms ', p, lats(p)), 'Color', 'w', 'FontSize', 14, ...
            'FontWeight','bold','BackgroundColor',colors(p,:)*0.8,'HorizontalAlignment','center','EdgeColor','k');
    end
    title(sprintf('%s | %s', id, phase)); set(gca,'YDir','reverse');

    % FIG 2: Trace Validator
    figure(r*10 + 5); clf; set(gcf,'Color','w','Units','normalized','Position',[0.45 0.4 0.4 0.4]);
    t_vec = (1:size(traces{1},1)) / fs * 1000; 
    for p = 1:3
        subplot(3,1,p); hold on;
        tr_p = traces{p};
        if any(qc(:,p))
            plot(t_vec, tr_p(:, qc(:,p)), 'Color', [colors(p,:) 0.2]); 
            avg = mean(tr_p(:, qc(:,p)), 2);
            plot(t_vec, avg, 'Color', colors(p,:), 'LineWidth', 2.5);
        end
        ylabel(sprintf('PC%d dF/F', p)); grid on;
        title(sprintf('ROI %d | QC Pass: %d trials', p, sum(qc(:,p))));
        if p == 3, xlabel('Time (ms)'); end
    end
    drawnow;
end