%% FINAL INTEGRATED FUS PIPELINE (AUTO-TRACE + REAL-TIME MONITOR)
% This version saves all waveforms and provides a detailed live log of data loading.

%% 1. CONFIGURATION & SPREADSHEET LOADING
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

% Load Excel
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);

expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

% Cleanup numeric columns
colsToConvert = {'MouseNumber', 'PreSet1', 'PostTotal'};
for i = 1:length(colsToConvert)
    col = colsToConvert{i};
    if ~isnumeric(expSummary.(col)), expSummary.(col) = str2double(string(expSummary.(col))); end
end

% Check for existing results
if ~exist('all_results', 'var')
    all_results = struct();
    fprintf('Starting fresh analysis.\n');
else
    fprintf('Existing progress detected. Overwriting selected experiments to save traces...\n');
end

% Parameters
percentile_bins = [0.9, 1.0; 0.8, 0.9; 0.7, 0.8; 0.6, 0.7; 0.5, 0.6]; 
baseline_frames = 50:55; 
numpix = [800, 800];

%% 2. MAIN EXPERIMENT LOOP
for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    
    % --- SMART SKIP ---
    % If you want to re-run EVERYTHING to get traces, run "clear all_results" before starting.
    if isfield(all_results, expID) && isfield(all_results.(expID).spatial(1), 'pre_avg_trace')
        fprintf('>> Skipping %s (Traces already present).\n', expID);
        continue; 
    end
    
    numPreSet1 = expSummary.PreSet1(r); 
    numPostTotal = expSummary.PostTotal(r);
    baseDir = expSummary.FolderPath{r}; 
    
    if isnan(numPreSet1) || numPreSet1 == 0, continue; end
    
    fprintf('\n\n======================================================\n');
    fprintf('  PROCESSING: %s (Mouse %s)\n', expID, num2str(expSummary.MouseNumber(r)));
    fprintf('  PATH: %s\n', baseDir);
    fprintf('======================================================\n');
    
    if ~exist(baseDir, 'dir')
        warning('SKIPPING %s: Path not found.', expID);
        continue;
    end

    % Prepare ROI Masks
    maskVarName = sprintf('PC1_%s_norm_upscaled', expID);
    if ~exist(maskVarName, 'var'), warning('Mask %s missing.', maskVarName); continue; end
    rawPC1 = eval(maskVarName);
    masks = cell(5,1);
    for p = 1:5
        masks{p} = (rawPC1 > percentile_bins(p,1)) & (rawPC1 <= percentile_bins(p,2));
    end
    
    prePath = fullfile(baseDir, 'pre_10kHz_set_1'); 
    postPath = fullfile(baseDir, 'post_10kHz_set_1');
    
    try
        % --- PRE-FUS ---
        fprintf('  [PRE-FUS] Loading %d trials...\n', numPreSet1);
        all_pre_traces = load_and_extract_all_masks(prePath, 1, numPreSet1, numpix, baseline_frames, masks);
        
        mean_pre_peaks = zeros(5,1);
        for p = 1:5
            temp_pre = all_pre_traces(:, :, p);
            all_results.(expID).spatial(p).pre_avg_trace = mean(temp_pre, 2);
            mean_pre_peaks(p) = mean(max(temp_pre(55:end, :)));
        end
        fprintf('    Done. Mean Pre-Peak (Center): %.4f\n', mean_pre_peaks(1));
        
        % --- POST-FUS BINS ---
        binEdges = 1:10:numPostTotal;
        for b = 1:length(binEdges)
            startT = binEdges(b);
            endT = min(startT + 9, numPostTotal);
            
            fprintf('  [POST BIN %d] Trials %d-%d...\n', b, startT, endT);
            all_post_traces = load_and_extract_all_masks(postPath, startT, endT, numpix, baseline_frames, masks);
            
            for p = 1:5
                temp_post = all_post_traces(:, :, p);
                all_results.(expID).spatial(p).temporal(b).avg_trace = mean(temp_post, 2);
                
                gain_val = mean(max(temp_post(55:end, :))) / mean_pre_peaks(p);
                all_results.(expID).spatial(p).temporal(b).gain = gain_val;
            end
            fprintf('    Bin %d Gain (Center): %.4f\n', b, all_results.(expID).spatial(1).temporal(b).gain);
        end
        
        % Auto-Save Checkpoint
        save('FUS_Analysis_FullTraces.mat', 'all_results');
        
    catch ME
        fprintf('  (!) ERROR in %s: %s\n', expID, ME.message);
    end
end

%% --- MONITORING HELPER FUNCTION ---
function all_mask_traces = load_and_extract_all_masks(basename, startT, endT, numpix, baseline_frames, masks)
    num_trials = endT - startT + 1;
    [fDir, fBaseName] = fileparts(basename);
    
    % Pre-check first file
    firstFile = [basename int2str(startT) '.tif'];
    if ~exist(firstFile, 'file'), error('Missing file: %s', firstFile); end
    
    info = imfinfo(firstFile); 
    num_images = numel(info);
    all_mask_traces = zeros(num_images, num_trials, 5);
    
    for i = startT:endT
        trial_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        
        % Live Monitor Output
        fprintf('      Loading: %s%s.tif...', fBaseName, int2str(i));
        
        frames = zeros(numpix(1), numpix(2), num_images, 'uint16');
        for j = 1:num_images, frames(:,:,j) = imread(filename, j); end
        
        sframes = zeros(size(frames), 'double');
        for j = 1:num_images, sframes(:,:,j) = imgaussfilt(double(frames(:,:,j)), 10); end
        
        baseline_img = mean(sframes(:,:,baseline_frames), 3);
        dFF = (sframes - baseline_img) ./ (baseline_img + eps);
        
        for p = 1:5
            mask = masks{p}; 
            flat_dFF = reshape(dFF, [], num_images);
            tr = mean(flat_dFF(mask(:), :), 1)';
            all_mask_traces(:, trial_idx, p) = tr - mean(tr(baseline_frames));
        end
        fprintf(' OK\n'); % Confirming file was processed successfully
    end
end