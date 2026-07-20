% 1. Data Selection
expID = 'L1'; 
mouseData = all_results.(expID);
numTemporal = length(mouseData.spatial(1).temporal);

% 2. NUCLEAR RESET
close all; 
set(0, 'DefaultFigureRenderer', 'painters'); 
fig = figure('Color', 'w', 'Position', [100 100 1100 700]);

% 3. MANUALLY SET AXES POSITION (Room for legend)
ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.1, 0.15, 0.55, 0.75]);
hold(ax, 'on');

% 4. Colors and Labels
spatial_colors = [0.85 0.1 0.1; 1 0.5 0; 0.9 0.85 0.1; 0.15 0.65 0.15; 0 0.45 0.75];
labels = {'90-100% (Center)', '80-90%', '70-80%', '60-70%', '50-60% (Periphery)'};

h = gobjects(1, 5);
for p = 1:5
    gains = [mouseData.spatial(p).temporal.gain];
    h(p) = plot(ax, 1:numTemporal, gains, '-o', ...
        'Color', spatial_colors(p,:), 'LineWidth', 3, ...
        'MarkerSize', 10, 'MarkerFaceColor', spatial_colors(p,:));
end

% 5. Format WITHOUT using 'yline'
grid(ax, 'on');
set(ax, 'FontSize', 14, 'XTick', 1:numTemporal);
xlabel(ax, 'Time Bin (10-Trial Blocks)', 'FontSize', 16, 'FontWeight', 'bold');
ylabel(ax, 'Gain (Post/Pre)', 'FontSize', 16, 'FontWeight', 'bold');
title(ax, ['Spatial Percentile Analysis: ' expID], 'FontSize', 18);

% Alternative to yline:
line([0.5, numTemporal+0.5], [1, 1], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 2);
text(0.6, 1.05, 'Baseline', 'FontSize', 14, 'FontWeight', 'bold');

% 6. THE LEGEND
lgd = legend(h, labels, 'Location', 'northeastoutside');
set(lgd, 'FontSize', 18, 'FontWeight', 'bold');

drawnow;