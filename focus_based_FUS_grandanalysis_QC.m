%% TARGET-CENTRIC FUS PIPELINE (v2.2: FULL TRACE STORAGE + VERBOSE FEEDBACK)
% 1. Saves every individual trial trace.
% 2. Provides real-time console updates for loading and processing.

%% 1. CONFIGURATION & SPREADSHEET LOADING
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:10); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal', 'SonicationX', 'SonicationY'};

numCols = {'MouseNumber', 'PreSet1', 'PostTotal', 'SonicationX', 'SonicationY'};
for i = 1:length(numCols)
    col = numCols{i};
    if ~isnumeric(expSummary.(col)), expSummary.(col) = str2double(string(expSummary.(col))); end
end

if ~exist('target_results', 'var')
    target_results = struct();
    fprintf('Starting fresh target-centric analysis.\n');
else
    fprintf('Existing target-results detected. Resuming...\n');
end

um_to_px = 0.3082; 
radii_um = [250, 500, 750, 1000, 1250]; 
radii_px = radii_um * um_to_px;
baseline_frames = 50:55; 
numpix = [800, 800];
img_center = numpix / 2;
[XX, YY] = meshgrid(1:numpix(2), 1:numpix(1));
SOFT_SNR_LIMIT = 1.5;

%% 2. MAIN EXPERIMENT LOOP
for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    targetX = expSummary.SonicationX(r);
    targetY = expSummary.SonicationY(r);
    
    if isnan(targetX) || isnan(targetY)
        if startsWith(expID, 'C')
            targetX = img_center(2); targetY = img_center(1);
        else
            continue; 
        end
    end
    
    if isfield(target_results, expID) && isfield(target_results.(expID).spatial(1), 'pre_raw_traces')
        fprintf('>> Skipping %s (Already analyzed).\n', expID);
        continue;
    end
    
    baseDir = expSummary.FolderPath{r};
    if ~exist(baseDir, 'dir'), warning('Path not found for %s', expID); continue; end

    fprintf('\n======================================================\n');
    fprintf('  BEGIN PROCESSING: %s\n', expID);
    fprintf('  Location: (%d, %d)\n', round(targetX), round(targetY));
    fprintf('======================================================\n');
    tic; % Start timer for this experiment

    % Generate Masks
    distMap = sqrt((XX - targetX).^2 + (YY - targetY).^2);
    masks = cell(5,1);
    masks{1} = distMap <= radii_px(1);
    for p = 2:5
        masks{p} = (distMap > radii_px(p-1)) & (distMap <= radii_px(p));
    end

    % Visual Check (Non-blocking)
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    checkImg = [prePath '1.tif'];
    if exist(checkImg, 'file')
        fig = figure('Name', ['ROI: ' expID], 'Position', [150 150 400 400]);
        imagesc(imread(checkImg, 1)); colormap gray; hold on;
        centers_rep = repmat([targetX, targetY], length(radii_px), 1);
        viscircles(centers_rep, radii_px(:), 'Color', 'y', 'LineStyle', '--', 'LineWidth', 0.5);
        plot(targetX, targetY, 'rx', 'MarkerSize', 10);
        title(['Targeting: ' expID]); axis image; axis off;
        drawnow; 
    end

    try
        % --- PRE-FUS EXTRACTION ---
        numPre = expSummary.PreSet1(r);
        fprintf('  [PRE] Processing %d trials...\n', numPre);
        [pre_traces, pre_qc] = load_extract_and_qc(prePath, 1, numPre, numpix, baseline_frames, masks);
        
        for p = 1:5
            target_results.(expID).spatial(p).pre_raw_traces = pre_traces(:,:,p);
            target_results.(expID).spatial(p).pre_snr_metadata = pre_qc.snr(:,p);
            target_results.(expID).spatial(p).pre_avg_trace = mean(pre_traces(:,:,p), 2);
        end
        
        % --- POST-FUS EXTRACTION ---
        numPost = expSummary.PostTotal(r);
        binEdges = 1:10:numPost;
        postPath = fullfile(baseDir, 'post_10kHz_set_1');
        
        for b = 1:length(binEdges)
            startT = binEdges(b);
            endT = min(startT + 9, numPost);
            
            fprintf('  [POST] Bin %d/%d (Trials %d-%d)... ', b, length(binEdges), startT, endT);
            [post_traces, post_qc] = load_extract_and_qc(postPath, startT, endT, numpix, baseline_frames, masks);
            
            for p = 1:5
                target_results.(expID).spatial(p).temporal(b).all_traces = post_traces(:,:,p);
                target_results.(expID).spatial(p).temporal(b).snr_metadata = post_qc.snr(:,p);
                
                valid = post_qc.snr(:,p) >= SOFT_SNR_LIMIT;
                if any(valid)
                    clean_bin_avg = mean(post_traces(:, valid, p), 2);
                    target_results.(expID).spatial(p).temporal(b).avg_trace = clean_bin_avg;
                    pre_peak = max(target_results.(expID).spatial(p).pre_avg_trace(55:end));
                    target_results.(expID).spatial(p).temporal(b).gain = max(clean_bin_avg(55:end)) / (pre_peak + eps);
                else
                    target_results.(expID).spatial(p).temporal(b).avg_trace = zeros(size(post_traces,1), 1);
                    target_results.(expID).spatial(p).temporal(b).gain = NaN;
                end
            end
            fprintf('Done.\n'); % End of bin line
        end
        
        fprintf('  Saving data... ');
        save('FUS_WideField_TargetResults_FullTraces.mat', 'target_results', '-v7.3');
        fprintf('Saved.\n');
        
        t_exp = toc;
        fprintf('  COMPLETED %s in %.2f seconds.\n', expID, t_exp);
        
    catch ME
        fprintf('\n  (!) ERROR in %s: %s\n', expID, ME.message);
    end
end

%% --- VERBOSE HELPER FUNCTION ---
function [all_mask_traces, qc_metrics] = load_extract_and_qc(basename, startT, endT, numpix, baseline_frames, masks)
    num_trials = endT - startT + 1;
    [~, folderName] = fileparts(basename);
    
    firstFile = [basename int2str(startT) '.tif'];
    if ~exist(firstFile, 'file')
        all_mask_traces = []; qc_metrics = []; 
        fprintf('\n      Missing file: %s\n', firstFile);
        return;
    end
    
    info = imfinfo(firstFile); 
    num_images = numel(info);
    all_mask_traces = zeros(num_images, num_trials, 5);
    qc_metrics.snr = zeros(num_trials, 5);
    
    % Small sub-progress feedback for the individual files
    for i = startT:endT
        trial_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        
        % Load
        frames = zeros(numpix(1), numpix(2), num_images, 'uint16');
        for j = 1:num_images, frames(:,:,j) = imread(filename, j); end
        
        % Filter & Process
        sframes = zeros(size(frames), 'double');
        for j = 1:num_images, sframes(:,:,j) = imgaussfilt(double(frames(:,:,j)), 10); end
        
        baseline_img = mean(sframes(:,:,baseline_frames), 3);
        dFF = (sframes - baseline_img) ./ (baseline_img + eps);
        
        for p = 1:5
            mask = masks{p}; 
            if any(mask(:))
                flat_dFF = reshape(dFF, [], num_images);
                tr = mean(flat_dFF(mask(:), :), 1)';
                tr_corrected = tr - mean(tr(baseline_frames));
                
                sig_peak = max(abs(tr_corrected(max(baseline_frames)+1:end)));
                noise_floor = std(tr_corrected(baseline_frames));
                
                all_mask_traces(:, trial_idx, p) = tr_corrected;
                qc_metrics.snr(trial_idx, p) = sig_peak / (noise_floor + eps);
            end
        end
        
        % Visual ticker for trial loading (e.g., " . . . ")
        if mod(trial_idx, 2) == 0, fprintf('.'); end
    end
end