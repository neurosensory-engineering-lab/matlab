%% FINAL INTEGRATED FUS PIPELINE (AUTO-PATH + SMART RESUME + AXIS FIX)
% This script reads your Excel sheet and picks up where you left off.

%% 1. CONFIGURATION & SPREADSHEET LOADING
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

% Read the Excel sheet (8 columns including the new 'Folder path')
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);

% Slice data (Columns: Type, Mouse, Date, Path, Pre1, Pre2, Pre3, PostTotal)
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

% Numeric cleanup for processing
colsToConvert = {'MouseNumber', 'PreSet1', 'PostTotal'};
for i = 1:length(colsToConvert)
    col = colsToConvert{i};
    if ~isnumeric(expSummary.(col)), expSummary.(col) = str2double(string(expSummary.(col))); end
end

% Check if 'all_results' already exists in your workspace (to avoid re-doing work)
if ~exist('all_results', 'var')
    all_results = struct();
    fprintf('Starting fresh analysis.\n');
else
    fprintf('Existing progress detected. Will skip completed experiments (C1-L4).\n');
end

% Parameters (Identical to your original settings)
percentile_bins = [0.9, 1.0; 0.8, 0.9; 0.7, 0.8; 0.6, 0.7; 0.5, 0.6]; 
baseline_frames = 50:55; 
numpix = [800, 800];

%% 2. MAIN EXPERIMENT LOOP
for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    
    % --- SMART SKIP ---
    % Checks if this Experiment (e.g., 'C1') is already in your results variable
    if isfield(all_results, expID)
        fprintf('>> Skipping %s (Data already present in workspace).\n', expID);
        continue; 
    end

    numPreSet1 = expSummary.PreSet1(r); 
    numPostTotal = expSummary.PostTotal(r);
    baseDir = expSummary.FolderPath{r}; % Pulls path directly from Excel
    
    if isnan(numPreSet1) || numPreSet1 == 0, continue; end

    fprintf('\n======================================================\n');
    fprintf('ANALYZING: %s (Mouse %s)\n', expID, num2str(expSummary.MouseNumber(r)));
    fprintf('======================================================\n');
    
    % Fail-safe: Skip if the path in Excel is broken or the drive disconnected
    if ~exist(baseDir, 'dir')
        warning('SKIPPING %s: Folder path not found: %s', expID, baseDir);
        continue;
    end

    % Prepare ROI Masks
    maskVarName = sprintf('PC1_%s_norm_upscaled', expID);
    if ~exist(maskVarName, 'var'), warning('Mask %s missing from workspace.', maskVarName); continue; end
    rawPC1 = eval(maskVarName);
    masks = cell(5,1);
    for p = 1:5
        masks{p} = (rawPC1 > percentile_bins(p,1)) & (rawPC1 <= percentile_bins(p,2));
    end
    
    % Naming Convention: This results in "set_1" + "11" = "set_111.tif"
    prePath = fullfile(baseDir, 'pre_10kHz_set_1'); 
    postPath = fullfile(baseDir, 'post_10kHz_set_1');
    
    try
        % --- LOAD PRE-FUS ---
        fprintf('--> Loading PRE-FUS...\n');
        all_pre_traces = load_and_extract_all_masks(prePath, 1, numPreSet1, numpix, baseline_frames, masks);
        [~, kept_pre_idx] = clean_traces_interactively(all_pre_traces(:,:,1), [expID ' PRE Selection']);
        
        mean_pre_peaks = zeros(5,1);
        for p = 1:5
            temp_pre = all_pre_traces(:, kept_pre_idx, p);
            mean_pre_peaks(p) = mean(max(temp_pre(55:end, :)));
        end
        
        % --- LOAD POST-FUS BINS ---
        binEdges = 1:10:numPostTotal;
        for b = 1:length(binEdges)
            startT = binEdges(b);
            endT = min(startT + 9, numPostTotal);
            
            fprintf('--> Loading POST Bin %d (Trials %d-%d)...\n', b, startT, endT);
            all_post_traces = load_and_extract_all_masks(postPath, startT, endT, numpix, baseline_frames, masks);
            [~, kept_post_idx] = clean_traces_interactively(all_post_traces(:,:,1), [expID ' POST Bin ' num2str(b)]);
            
            for p = 1:5
                temp_post = all_post_traces(:, kept_post_idx, p);
                gain_val = mean(max(temp_post(55:end, :))) / mean_pre_peaks(p);
                all_results.(expID).spatial(p).temporal(b).gain = gain_val;
            end
        end
        
        % Checkpoint: Save to file after every successful experiment
        save('FUS_Analysis_Checkpoint.mat', 'all_results');
        
    catch ME
        fprintf('(!) ERROR IN %s: %s\n', expID, ME.message);
        fprintf('Skipping to next mouse to save progress...\n');
    end
end

%% --- HELPER FUNCTIONS ---

function all_mask_traces = load_and_extract_all_masks(basename, startT, endT, numpix, baseline_frames, masks)
    num_trials = endT - startT + 1;
    fname1 = [basename int2str(startT) '.tif'];
    if ~exist(fname1, 'file'), error('File missing: %s', fname1); end
    info = imfinfo(fname1); num_images = numel(info);
    all_mask_traces = zeros(num_images, num_trials, 5);
    for i = startT:endT
        trial_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        fprintf('    Processing %s...', [int2str(i) '.tif']);
        frames = zeros(numpix(1), numpix(2), num_images, 'uint16');
        for j = 1:num_images, frames(:,:,j) = imread(filename, j); end
        sframes = zeros(size(frames), 'double');
        for j = 1:num_images, sframes(:,:,j) = imgaussfilt(double(frames(:,:,j)), 10); end
        baseline_img = mean(sframes(:,:,baseline_frames), 3);
        dFF = (sframes - baseline_img) ./ (baseline_img + eps);
        for p = 1:5
            mask = masks{p}; flat_dFF = reshape(dFF, [], num_images);
            tr = mean(flat_dFF(mask(:), :), 1)';
            all_mask_traces(:, trial_idx, p) = tr - mean(tr(baseline_frames));
        end
        fprintf(' Done.\n');
    end
end

function [cleaned_traces, kept_idx] = clean_traces_interactively(traces, titleStr)
    num_trials = size(traces, 2);
    num_frames = size(traces, 1);
    f = figure('Name', titleStr, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
    for t = 1:num_trials
        subplot(ceil(num_trials/5), 5, t); plot(traces(:,t));
        title(['T' num2str(t)]); grid on;
        xlim([1 num_frames]); % STANDARD X-AXIS
        ylim([-0.05 0.20]);   % STANDARD Y-AXIS
    end
    sgtitle(['Reviewing: ' titleStr]);
    commandwindow;
    isValid = false;
    while ~isValid
        txt = input(['KEEP for ' titleStr ' [Enter for ALL]: '], 's');
        if isempty(strtrim(txt)), kept_idx = 1:num_trials; isValid = true;
        else
            candidate_idx = str2num(txt); 
            if isempty(candidate_idx) || any(candidate_idx > num_trials)
                fprintf('(!) Invalid entry.\n');
            else, kept_idx = candidate_idx; isValid = true; end
        end
    end
    cleaned_traces = traces(:, kept_idx); close(f);
end