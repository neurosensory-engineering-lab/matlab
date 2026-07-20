%% FUNCTIONAL VS. PHYSICAL RINGS VISUALIZER (TRUE FUS CENTER)
% -------------------------------------------------------------------------
% Overlays physical concentric distance rings (in um) on top of the 
% functional "concentric" PC1 percentile brackets, anchored to true targets.
% -------------------------------------------------------------------------

% 1. Configuration
target_exp = 'H4';  % Experiment name for title purposes

% Automatically try to grab the correct PC1 image from the workspace
pc1_var_name = sprintf('PC1_%s_norm_upscaled', target_exp);
if evalin('base', sprintf('exist(''%s'', ''var'')', pc1_var_name))
    PC1_img = evalin('base', pc1_var_name);
else
    error('Could not find %s in the workspace. Please load it or update the variable name.', pc1_var_name);
end

% Spatial Conversion Parameters
um_to_px = 0.3082; 
radii_um = [250, 500, 750, 1000, 1250];

%% 1.5 LOAD FUS TARGET FROM SPREADSHEET
filename = '/Experiment summary.xlsx'; 
if ~exist(filename, 'file')
    error('Spreadsheet not found. Please check the path: %s', filename);
end

% Replicate the table loading logic from your main pipeline
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:10); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal', 'SonicationX', 'SonicationY'};

% Convert X and Y to numeric if they aren't already
if ~isnumeric(expSummary.SonicationX), expSummary.SonicationX = str2double(string(expSummary.SonicationX)); end
if ~isnumeric(expSummary.SonicationY), expSummary.SonicationY = str2double(string(expSummary.SonicationY)); end

% Find the exact row for the target experiment
row_idx = find(strcmpi(expSummary.ExperimentType, target_exp), 1);
if isempty(row_idx)
    error('Experiment %s not found in the spreadsheet.', target_exp);
end

% Extract true center
center_x = expSummary.SonicationX(row_idx);
center_y = expSummary.SonicationY(row_idx);

% Fallback logic for Controls / missing coordinates
img_size = size(PC1_img);
if isnan(center_x) || isnan(center_y)
    if startsWith(target_exp, 'C', 'IgnoreCase', true)
        fprintf('Control experiment detected. Defaulting to image center.\n');
        center_x = img_size(2) / 2;
        center_y = img_size(1) / 2;
    else
        error('NaN coordinates found for non-Control experiment (%s). Check your spreadsheet.', target_exp);
    end
else
    fprintf('Loaded true FUS coordinates for %s: X=%.1f, Y=%.1f\n', target_exp, center_x, center_y);
end

%% 2. Calculate the PC1 Percentile Brackets ("Functional Rings")
% Find the exact threshold values for the percentiles
p50 = prctile(PC1_img(:), 50);
p60 = prctile(PC1_img(:), 60);
p70 = prctile(PC1_img(:), 70);
p80 = prctile(PC1_img(:), 80);
p90 = prctile(PC1_img(:), 90);

% Build a discrete map where each bracket gets a specific integer value
bracket_map = zeros(size(PC1_img));
bracket_map(PC1_img >= p50 & PC1_img < p60) = 1; % 50-60%
bracket_map(PC1_img >= p60 & PC1_img < p70) = 2; % 60-70%
bracket_map(PC1_img >= p70 & PC1_img < p80) = 3; % 70-80%
bracket_map(PC1_img >= p80 & PC1_img < p90) = 4; % 80-90%
bracket_map(PC1_img >= p90)                 = 5; % Top 10%

%% 3. Plot Dashboard
figCompare = figure(825); clf;
set(figCompare, 'Color', 'w', 'Position', [100 100 900 850]);

% Create a custom colormap so the brackets pop
% 0=Gray (Background), 1=Cyan, 2=Green, 3=Yellow, 4=Orange, 5=Red
cmap = [0.15 0.15 0.15;  % Background (<50%)
        0.00 0.80 0.80;  % 50-60%
        0.20 0.80 0.20;  % 60-70%
        0.90 0.90 0.10;  % 70-80%
        0.90 0.50 0.00;  % 80-90%
        0.90 0.10 0.10]; % Top 10%

% Display the functional brackets
imagesc(bracket_map);
colormap(gca, cmap);
axis image; hold on;
title(sprintf('%s | Functional PC1 vs. True FUS Center Distance', target_exp), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Mark the true focus
plot(center_x, center_y, 'w+', 'MarkerSize', 15, 'LineWidth', 2);
plot(center_x, center_y, 'ko', 'MarkerSize', 6, 'LineWidth', 1.5); % Little bulls-eye

%% 4. Draw the Physical Concentric Rings
theta = linspace(0, 2*pi, 200);

for i = 1:length(radii_um)
    % Convert the physical radius to pixel radius
    r_px = radii_um(i) * um_to_px;
    
    % Calculate circle coordinates
    x_circle = center_x + r_px * cos(theta);
    y_circle = center_y + r_px * sin(theta);
    
    % Plot the circular ring (using a crisp white dashed line)
    plot(x_circle, y_circle, 'w--', 'LineWidth', 2);
    plot(x_circle, y_circle, 'k:', 'LineWidth', 1); % Shadow for visibility
    
    % Add a text label right at the top of each ring
    text(center_x, center_y - r_px - 8, sprintf('%d \\mum', radii_um(i)), ...
        'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

%% 5. Add a legend for the functional brackets
% Creating dummy plots just to generate a nice legend
c_labels = {'< 50%', '50-60%', '60-70%', '70-80%', '80-90%', 'Top 10%'};
for i = 1:6
    plot(NaN, NaN, 's', 'MarkerSize', 10, 'MarkerFaceColor', cmap(i,:), 'MarkerEdgeColor', 'none', 'DisplayName', c_labels{i});
end
plot(NaN, NaN, 'w--', 'LineWidth', 2, 'DisplayName', 'True Distance Rings');

legend('Location', 'northeastoutside', 'FontSize', 11, 'Color', 'k', 'TextColor', 'w');
axis off;