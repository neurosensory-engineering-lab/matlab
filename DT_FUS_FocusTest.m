%% ============================================================
%  DT EXPERIMENT: PC OVERLAY & FUS TARGETING VERIFICATION
% =============================================================
% Purpose: Verify 10kHz and 30kHz ROIs against physical FUS targets.
% Requires: Workspace variables PC1_DTX_10kHz... and PC1_DTX_30kHz...
% =============================================================

rootPath = '/Volumes/fisher_lab/Jacob HD Backup 2025/JHT7/'; 
filename = 'Experiment summary.xlsx'; 

fprintf('\nGenerating Spatial Verification Figure...\n');

%% 1. LOAD SPREADSHEET DATA
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);

expSummary = rawTable(c1_idx:end, 1:10); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal', 'SonicationX', 'SonicationY'};

% Convert numeric columns safely
numCols = {'SonicationX', 'SonicationY'};
for i = 1:length(numCols)
    col = numCols{i};
    if ~isnumeric(expSummary.(col))
        expSummary.(col) = str2double(string(expSummary.(col)));
    end
end

%% 2. GROUP EXPERIMENTS
all_dt_rows = find(startsWith(expSummary.ExperimentType, 'DT'));
baseIDs = cell(length(all_dt_rows), 1);
for i = 1:length(all_dt_rows)
    str = expSummary.ExperimentType{all_dt_rows(i)};
    parts = split(str, '_');
    baseIDs{i} = parts{1}; 
end
uniqueExps = unique(baseIDs, 'stable');
num_exps = length(uniqueExps);

%% 3. PLOTTING SETUP
% Spatial Constants
um_to_px = 0.3082; 
radii_um = [250, 500, 750, 1000]; 
radii_px = radii_um * um_to_px;

color10 = [0, 0.4470, 0.7410]; % Blue
color30 = [0.8500, 0.3250, 0.0980]; % Red

fig = figure('Name', 'Spatial Targeting Verification', 'Color', 'w', 'Position', [100 100 1200 1000]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

%% 4. MAIN VISUALIZATION LOOP
for idx = 1:num_exps
    baseID = uniqueExps{idx};
    
    % Find the spreadsheet row for the 10kHz entry
    match_indices = all_dt_rows(strcmp(baseIDs, baseID));
    r_10 = NaN;
    for m = 1:length(match_indices)
        if contains(expSummary.ExperimentType{match_indices(m)}, '_10')
            r_10 = match_indices(m); break;
        end
    end
    if isnan(r_10), r_10 = match_indices(1); end
    
    targetX = expSummary.SonicationX(r_10);
    targetY = expSummary.SonicationY(r_10);
    baseDir = expSummary.FolderPath{r_10};
    
    nexttile; hold on;
    
    % --- A. Load and Plot Background Anatomy ---
    prePath = fullfile(baseDir, 'pre_10kHz_set_1');
    firstTiff = [prePath '1.tif']; % Resolves to your ...set_11.tif
    
    if exist(firstTiff, 'file')
        img = imread(firstTiff, 1);
        img_adj = imadjust(uint16(img)); 
        imagesc(img_adj); colormap(gca, gray);
    else
        % Fallback if image path is broken
        imagesc(zeros(800, 800)); colormap(gca, gray);
        text(400, 400, 'Raw TIFF Not Found', 'Color', 'w', 'HorizontalAlignment', 'center');
    end
    
    % --- B. Load and Plot PC1 Masks ---
    var10 = sprintf('PC1_%s_10kHz_norm_upscaled', baseID);
    var30 = sprintf('PC1_%s_30kHz_norm_upscaled', baseID);
    
    if exist(var10, 'var') && exist(var30, 'var')
        PC1_10 = eval(var10);
        PC1_30 = eval(var30);
        
        mask10 = (PC1_10 > 0.9);
        mask30 = (PC1_30 > 0.9);
        
        % 1. Draw BOTH semi-transparent color fills FIRST (Background layer)
        blue_img = cat(3, zeros(size(mask10)), 0.447*ones(size(mask10)), 0.741*ones(size(mask10)));
        h10 = imagesc(blue_img);
        set(h10, 'AlphaData', mask10 * 0.4); % 40% opacity
        
        red_img = cat(3, 0.85*ones(size(mask30)), 0.325*ones(size(mask30)), 0.098*ones(size(mask30)));
        h30 = imagesc(red_img);
        set(h30, 'AlphaData', mask30 * 0.4); % 40% opacity
        
        % 2. Draw BOTH solid contours LAST (Foreground layer)
        % Increased LineWidth to 3.0 for bolder perimeters
        contour(mask10, [0.5 0.5], 'Color', color10, 'LineWidth', 3.0);
        contour(mask30, [0.5 0.5], 'Color', color30, 'LineWidth', 3.0);
    else
        text(400, 450, 'PC Maps Missing from Workspace', 'Color', 'r', 'HorizontalAlignment', 'center');
    end
    
    % --- C. Plot FUS Target ---
    if ~isnan(targetX) && ~isnan(targetY)
        % Plot the "X"
        plot(targetX, targetY, 'yx', 'MarkerSize', 14, 'LineWidth', 3);
        
        % Plot concentric targeting rings
        centers_rep = repmat([targetX, targetY], length(radii_px), 1);
        viscircles(centers_rep, radii_px(:), 'Color', 'y', 'LineStyle', '--', 'LineWidth', 1.2);
    end
    
    % --- D. Formatting ---
    set(gca, 'YDir', 'reverse'); % Ensure image isn't flipped upside down
    axis image; axis off;
    
    % Create custom legend elements
    h_leg1 = plot(NaN, NaN, 's', 'MarkerFaceColor', color10, 'MarkerEdgeColor', 'none', 'MarkerSize', 10);
    h_leg2 = plot(NaN, NaN, 's', 'MarkerFaceColor', color30, 'MarkerEdgeColor', 'none', 'MarkerSize', 10);
    h_leg3 = plot(NaN, NaN, 'yx', 'MarkerSize', 10, 'LineWidth', 2);
    
    legend([h_leg1, h_leg2, h_leg3], {'10kHz ROI', '30kHz ROI', 'FUS Target'}, ...
        'Location', 'southwest', 'TextColor', 'w', 'Color', 'none', 'EdgeColor', 'none');
        
    title(sprintf('%s | FUS Target: (%d, %d)', baseID, round(targetX), round(targetY)), ...
        'FontSize', 14, 'Color', 'k', 'Interpreter', 'none');
end

% Overall Title
title(t, 'Dual Tone Spatial Specificity: PC1 Maps vs Physical FUS Target', 'FontSize', 18, 'FontWeight', 'bold');
fprintf('Done!\n');