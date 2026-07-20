%% FUNCTIONAL TO SPATIAL LOOKUP: PC1 PERCENTILE RADII (STRICT MATCH)
% -------------------------------------------------------------------------
% 1. Loads the Excel Experiment Summary to get the exact list of animals.
% 2. Allows exclusion of specific "bad" experiments to match functional data.
% 3. Calculates the center of mass based on the Top 10% peak.
% 4. Finds the average distance (um) to the outer perimeter of each bracket.
% -------------------------------------------------------------------------

% 1. Configuration & Spatial Conversion
filename = 'Experiment summary.xlsx';
bad_experiments = {'H3'}; % <--- Put the exact same exclusions here as your stats script
px_to_um = 1 / 0.3082; 

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

%% 2. Load Experiment Summary (Matches your exact pipeline)
fprintf('\nLoading Experiment Summary to strict-match animals...\n');
rawTable = readtable(filename, 'VariableNamingRule', 'preserve', 'ReadVariableNames', false);
allFirstCol = cellstr(string(rawTable{:,1}));
c1_idx = find(strcmp(allFirstCol, 'C1'), 1);
expSummary = rawTable(c1_idx:end, 1:8); 
expSummary.Properties.VariableNames = {'ExperimentType', 'MouseNumber', 'Date', ...
    'FolderPath', 'PreSet1', 'PreSet2', 'PreSet3', 'PostTotal'};

% Filter the list to get valid experiments
valid_exps = {};
for r = 1:height(expSummary)
    expID = expSummary.ExperimentType{r};
    numPre = expSummary.PreSet1(r);
    
    % Skip if no pre-trials, or if it's in the bad_experiments list
    if isnan(numPre) || numPre == 0 || ismember(expID, bad_experiments)
        continue;
    end
    valid_exps{end+1} = expID;
end

num_exps = length(valid_exps);
fprintf('>>> Proceeding with %d strictly matched, valid experiments.\n', num_exps);

bracket_radii_um = nan(num_brackets, num_exps);

%% 3. Calculate Spatial Radii
for r = 1:num_exps
    expID = valid_exps{r};
    var_name = sprintf('PC1_%s_norm_upscaled', expID);
    
    % Check if it actually exists in the workspace
    if ~evalin('base', sprintf('exist(''%s'', ''var'')', var_name))
        fprintf('  [!] Warning: %s missing from workspace. Skipping.\n', var_name);
        continue;
    end
    
    img = evalin('base', var_name);
    
    % 3a. Define the "Center of Mass" using the Top 10% bracket (Peak PC1)
    top_mask = img > 0.9;
    [y_top, x_top] = find(top_mask);
    
    if isempty(x_top)
        fprintf('  [!] Warning: %s has no pixels > 0.9. Skipping.\n', var_name);
        continue;
    end
    
    com_x = mean(x_top);
    com_y = mean(y_top);
    
    % 3b. Find distance to the outer edge of each bracket
    for p = 1:num_brackets
        lower_bound = percentile_bins(p, 1);
        solid_mask = img > lower_bound;
        
        perim_mask = bwperim(solid_mask);
        [y_perim, x_perim] = find(perim_mask);
        
        if isempty(x_perim)
            continue; 
        end
        
        dists_px = sqrt((x_perim - com_x).^2 + (y_perim - com_y).^2);
        
        avg_dist_px = mean(dists_px);
        bracket_radii_um(p, r) = avg_dist_px * px_to_um;
    end
end

%% 4. Aggregate Statistics
mean_radii = nanmean(bracket_radii_um, 2);
std_radii  = nanstd(bracket_radii_um, 0, 2);

fprintf('\n======================================================\n');
fprintf(' SPATIAL LOOKUP: Average Radius from PC1 Center\n');
fprintf('======================================================\n');
for p = 1:num_brackets
    fprintf('%-10s : %6.1f +/- %5.1f um (SD)\n', bracket_labels{p}, mean_radii(p), std_radii(p));
end
fprintf('======================================================\n');

%% 5. Plot the Spatial Lookup Dashboard
figLookup = figure(830); clf;
set(figLookup, 'Color', 'w', 'Position', [200 200 900 600]);
hold on; grid on;

errorbar(1:num_brackets, mean_radii, std_radii, ...
    '-o', 'Color', [0.2 0.2 0.2], 'LineWidth', 2.5, ...
    'MarkerSize', 10, 'MarkerFaceColor', [0.8 0.2 0.2], 'MarkerEdgeColor', 'k');

title('Spatial Translation of Functional PC1 Brackets', 'FontSize', 18, 'FontWeight', 'bold');
ylabel('Average Distance from PC1 Center (\mum)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Functional PC1 Percentile Bracket', 'FontSize', 14, 'FontWeight', 'bold');

set(gca, 'XTick', 1:num_brackets, 'XTickLabel', bracket_labels, 'FontSize', 12, 'FontWeight', 'bold');
xtickangle(30);

xlim([0.5, num_brackets + 0.5]);
ylim([0, max(mean_radii + std_radii) * 1.1]); 

for p = 1:num_brackets
    if ~isnan(mean_radii(p))
        text(p, mean_radii(p) + std_radii(p) + 30, sprintf('%.0f \\mum', mean_radii(p)), ...
            'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
end

hold off;