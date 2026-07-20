%% FINAL WAVEFORM COMPARISON: Grayscale Pre-FUS vs Bin 1 vs Bin 3
expID = 'H4'; % Animal to inspect

if ~isfield(all_results, expID)
    error('Experiment %s not found in results.', expID);
end

% 1. Standardized Spatial Colors (Post-FUS)
spatial_colors = [
    0.85, 0.10, 0.10;  % 90-100% (Red)
    1.00, 0.50, 0.00;  % 80-90%  (Orange)
    0.90, 0.85, 0.10;  % 70-80%  (Yellow)
    0.10, 0.70, 0.20;  % 60-70%  (Green)
    0.00, 0.45, 0.75]; % 50-60%  (Blue)

% 2. Grayscale Baseline Gradient (Pre-FUS)
% From Black (0) to Light Gray (0.7)
gray_shades = [0, 0, 0; 0.2, 0.2, 0.2; 0.4, 0.4, 0.4; 0.6, 0.6, 0.6; 0.75, 0.75, 0.75];

labels = {'90-100%', '80-90%', '70-80%', '60-70%', '50-60%'};

figure('Color', 'w', 'Name', ['Democratic Waveform Check: ' expID], 'Position', [100 100 1250 800]);
hold on;

h_pre = gobjects(1,5); h_b1 = gobjects(1,5);
for p = 1:5
    % --- PRE-FUS (Grayscale Gradient) ---
    tr_pre = all_results.(expID).spatial(p).pre_avg_trace;
    h_pre(p) = plot(tr_pre, '-', 'Color', gray_shades(p,:), 'LineWidth', 2.0); 
    
    % --- BIN 1 (Colored Solid) ---
    tr1 = all_results.(expID).spatial(p).temporal(1).avg_trace;
    h_b1(p) = plot(tr1, '-', 'Color', spatial_colors(p,:), 'LineWidth', 3.5);
    
    % --- BIN 3 (Colored Dashed) ---
    if length(all_results.(expID).spatial(p).temporal) >= 3
        tr3 = all_results.(expID).spatial(p).temporal(3).avg_trace;
        plot(tr3, '--', 'Color', spatial_colors(p,:), 'LineWidth', 2.5);
    end
end

% Manual Line for Stim Onset (No xline)
line([55 55], [-0.05 1], 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 2);
text(56, -0.01, 'Stim Onset', 'FontSize', 12, 'FontWeight', 'bold');

% Formatting
grid on;
set(gca, 'FontSize', 14, 'LineWidth', 1.5);
xlabel('Frame Number', 'FontWeight', 'bold');
ylabel('dF/F (Baseline Corrected)', 'FontWeight', 'bold');
title(['Integrity Check: Pre-FUS (Grays) vs Bin 1 (-) vs Bin 3 (--) for ' expID], 'FontSize', 18);

% Dual Legend Logic: We create two columns of info manually or one organized legend
% Here we show the Percentile Ranges in color
lgd = legend(h_b1, labels, 'Location', 'northeastoutside');
title(lgd, 'Spatial Ranges');

% Add floating labels for the grayscale logic
text(1.02, 0.4, 'Pre-FUS Baseline:', 'Units', 'normalized', 'FontWeight', 'bold');
text(1.02, 0.37, 'Black (Center) \rightarrow Light Gray (Periphery)', 'Units', 'normalized', 'FontSize', 11);

% Scale and Focus
all_traces = [all_results.(expID).spatial(1).temporal(1).avg_trace];
ylim([-0.05, max(all_traces)*1.4]);
xlim([40 105]);