%% FUS SPATIAL CALIBRATION VERIFIER (FULL STANDALONE)
% -------------------------------------------------------------------------
% Purpose: Load Excel coordinates and overlay them on raw vessel anatomy 
% to verify that 'SonicationX' and 'SonicationY' match the physical target.
% -------------------------------------------------------------------------

%% 1. CONFIGURATION & SPREADSHEET LOADING
rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

% Read the raw table and find the start of the experimental data (C1)
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);

% Extract and name the summary table
expSummary = rawTable(c1_idx:end, 1:10); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal', 'SonicationX', 'SonicationY'};

% Convert numeric columns to ensure proper plotting
numCols = {'MouseNumber', 'PreSet1', 'PostTotal', 'SonicationX', 'SonicationY'};
for i = 1:length(numCols)
    col = numCols{i};
    if ~isnumeric(expSummary.(col))
        expSummary.(col) = str2double(string(expSummary.(col)));
    end
end

% Spatial Constants (Matches your pipeline)
um_to_px = 0.3082; 
radii_um = [250, 500, 750, 1000, 1250]; 
radii_px = radii_um * um_to_px;

%% 2. VISUAL CALIBRATION LOOP
fprintf('\nStarting Visual Verification. Press any key to cycle through experiments.\n');

for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    targetX = expSummary.SonicationX(r);
    targetY = expSummary.SonicationY(r);
    baseDir = expSummary.FolderPath{r};
    
    % Handle missing coordinates or paths
    if isnan(targetX) || isnan(targetY)
        fprintf('>> Skipping %s: Missing Sonication Coordinates.\n', expID);
        continue; 
    end
    
    if ~exist(baseDir, 'dir')
        fprintf('>> Skipping %s: Path not found (%s).\n', expID, baseDir);
        continue;
    end
    
    % Path to the very first frame of the first pre-FUS set
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    firstTiff = [prePath '1.tif'];
    
    if exist(firstTiff, 'file')
        % Create High-Contrast Figure
        fig = figure('Name', ['Targeting Check: ' expID], 'Color', 'w', 'Position', [100 100 900 800]);
        
        % Load first frame and enhance contrast for vessel detection
        img = imread(firstTiff, 1);
        img_adj = imadjust(uint16(img)); 
        
        imagesc(img_adj); colormap gray; hold on;
        
        % 1. Plot the Focal Point (Excel X/Y)
        plot(targetX, targetY, 'rx', 'MarkerSize', 20, 'LineWidth', 3);
        
        % 2. Plot the Analysis Rings (The "Grab" Regions)
        centers_rep = repmat([targetX, targetY], length(radii_px), 1);
        viscircles(centers_rep, radii_px(:), 'Color', [1, 0.8, 0], 'LineStyle', '--', 'LineWidth', 1);
        
        % 3. Text Overlay
        title(['Exp: ' expID ' | Location: (' num2str(round(targetX)) ',' num2str(round(targetY)) ')'], ...
              'FontSize', 18, 'Interpreter', 'none');
        text(targetX + 20, targetY - 20, 'TARGET', 'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold');
        
        % Final Clean up
        axis image; axis off;
        
        fprintf('Displaying %s. Inspect vessels and press any key for next...\n', expID);
        pause; 
        if ishandle(fig), close(fig); end
    else
        fprintf('>> Warning: TIFF not found for %s: %s\n', expID, firstTiff);
    end
end

fprintf('\nVerification complete.\n');