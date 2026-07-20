%% TARGET-CENTRIC FUS PIPELINE (1.25mm WIDE-FIELD + CENTERED CONTROLS)
% Controls (C1-C3) with NA coordinates are assigned the image center (400, 400).
% Only processes experiments not already present in 'target_results'.

%% 1. CONFIGURATION & SPREADSHEET LOADING
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);

expSummary = rawTable(c1_idx:end, 1:10); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal', 'SonicationX', 'SonicationY'};

% Convert necessary columns to numeric (NA becomes NaN)
numCols = {'MouseNumber', 'PreSet1', 'PostTotal', 'SonicationX', 'SonicationY'};
for i = 1:length(numCols)
    col = numCols{i};
    if ~isnumeric(expSummary.(col)), expSummary.(col) = str2double(string(expSummary.(col))); end
end

% Result container
if ~exist('target_results', 'var')
    target_results = struct();
    fprintf('Starting fresh target-centric analysis.\n');
else
    fprintf('Existing target-results detected. Resuming...\n');
end

% RADIUS PARAMETERS
um_to_px = 0.3082; 
radii_um = [250, 500, 750, 1000, 1250]; 
radii_px = radii_um * um_to_px;

baseline_frames = 50:55; 
numpix = [800, 800];
img_center = numpix / 2; % [400, 400]
[XX, YY] = meshgrid(1:numpix(2), 1:numpix(1));

%% 2. MAIN EXPERIMENT LOOP
for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    targetX = expSummary.SonicationX(r);
    targetY = expSummary.SonicationY(r);
    
    % --- HANDLE CONTROLS (NA -> Image Center) ---
    if isnan(targetX) || isnan(targetY)
        if startsWith(expID, 'C')
            fprintf('>> Control detected (%s). Assigning image center (400, 400) for spatial reference.\n', expID);
            targetX = img_center(2); 
            targetY = img_center(1);
        else
            fprintf('>> Skipping %s (Non-control with missing coordinates).\n', expID);
            continue; 
        end
    end
    
    % SMART SKIP: Only run if results aren't already saved
    if isfield(target_results, expID) && isfield(target_results.(expID).spatial(1), 'pre_avg_trace')
        fprintf('>> Skipping %s (Already analyzed).\n', expID);
        continue;
    end
    
    baseDir = expSummary.FolderPath{r};
    if ~exist(baseDir, 'dir')
        warning('SKIPPING %s: Path not found.', expID);
        continue;
    end

    fprintf('\n\n======================================================\n');
    fprintf('  PROCESSING: %s (Focus: %d, %d)\n', expID, round(targetX), round(targetY));
    fprintf('======================================================\n');

    % --- GENERATE DISTANCE-BASED DONUT MASKS ---
    distMap = sqrt((XX - targetX).^2 + (YY - targetY).^2);
    masks = cell(5,1);
    masks{1} = distMap <= radii_px(1);
    for p = 2:5
        masks{p} = (distMap > radii_px(p-1)) & (distMap <= radii_px(p));
    end

    % --- VISUAL SANITY CHECK ---
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    checkImg = [prePath '1.tif'];
    if exist(checkImg, 'file')
        fig = figure('Name', ['ROI Verification: ' expID], 'Position', [150 150 800 800]);
        imagesc(imread(checkImg, 1)); colormap gray; hold on;
        
        % Corrected viscircles for the rings
        centers_rep = repmat([targetX, targetY], length(radii_px), 1);
        viscircles(centers_rep, radii_px(:), 'Color', 'y', 'LineStyle', '--', 'LineWidth', 1);
        
        % Plot the focus point
        plot(targetX, targetY, 'rx', 'MarkerSize', 15, 'LineWidth', 2);
        
        title(sprintf('%s Analysis Rings\n(Center-aligned for Controls)\nClose window to proceed', expID));
        axis image; axis off;
        waitfor(fig); 
    end

    try
        % --- EXTRACTION ENGINE ---
        numPre = expSummary.PreSet1(r);
        fprintf('  [PRE-FUS] Extracting %d trials...\n', numPre);
        all_pre_traces = load_and_extract_all_masks(prePath, 1, numPre, numpix, baseline_frames, masks);
        
        mean_pre_peaks = zeros(5,1);
        for p = 1:5
            temp_pre = all_pre_traces(:,:,p);
            target_results.(expID).spatial(p).pre_avg_trace = mean(temp_pre, 2);
            mean_pre_peaks(p) = mean(max(temp_pre(55:end, :)));
        end
        
        numPost = expSummary.PostTotal(r);
        binEdges = 1:10:numPost;
        postPath = fullfile(baseDir, 'post_10kHz_set_1');
        
        for b = 1:length(binEdges)
            startT = binEdges(b);
            endT = min(startT + 9, numPost);
            
            fprintf('  [POST BIN %d] Trials %d-%d...\n', b, startT, endT);
            all_post_traces = load_and_extract_all_masks(postPath, startT, endT, numpix, baseline_frames, masks);
            
            for p = 1:5
                temp_post = all_post_traces(:,:,p);
                target_results.(expID).spatial(p).temporal(b).avg_trace = mean(temp_post, 2);
                
                % Gain relative to specific spatial ring
                gain_val = mean(max(temp_post(55:end, :))) / (mean_pre_peaks(p) + eps);
                target_results.(expID).spatial(p).temporal(b).gain = gain_val;
            end
            fprintf('    Bin %d Completed. Inner Ring Gain: %.4f\n', b, target_results.(expID).spatial(1).temporal(b).gain);
        end
        
        % Save to the Target-Centric results file
        save('FUS_WideField_TargetResults.mat', 'target_results');
        
    catch ME
        fprintf('  (!) ERROR in %s: %s\n', expID, ME.message);
    end
end

%% --- HELPER FUNCTION (UNCHANGED) ---
function all_mask_traces = load_and_extract_all_masks(basename, startT, endT, numpix, baseline_frames, masks)
    num_trials = endT - startT + 1;
    [~, fBaseName] = fileparts(basename);
    firstFile = [basename int2str(startT) '.tif'];
    info = imfinfo(firstFile); 
    num_images = numel(info);
    all_mask_traces = zeros(num_images, num_trials, 5);
    
    for i = startT:endT
        trial_idx = i - startT + 1;
        filename = [basename int2str(i) '.tif'];
        fprintf('      Loading: %s%s.tif... ', fBaseName, int2str(i));
        
        frames = zeros(numpix(1), numpix(2), num_images, 'uint16');
        for j = 1:num_images, frames(:,:,j) = imread(filename, j); end
        
        sframes = zeros(size(frames), 'double');
        for j = 1:num_images, sframes(:,:,j) = imgaussfilt(double(frames(:,:,j)), 10); end
        
        baseline_img = mean(sframes(:,:,baseline_frames), 3);
        dFF = (sframes - baseline_img) ./ (baseline_img + eps);
        
        for p = 1:5
            mask = masks{p}; 
            if any(mask(:))
                flat_dFF = reshape(dFF, [], num_images);
                tr = mean(flat_dFF(mask(:), :), 1)';
                all_mask_traces(:, trial_idx, p) = tr - mean(tr(baseline_frames));
            else
                all_mask_traces(:, trial_idx, p) = zeros(num_images, 1);
            end
        end
        fprintf('OK\n');
    end
end