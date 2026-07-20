%% TARGET-CENTRIC WAVEFORM CHECK: Pre-FUS vs Bin 1 vs Bin 3
expID = 'L9'; % Animal to inspect

if ~isfield(target_results, expID)
    error('Experiment %s not found in target_results. Did you run the extraction script?', expID);
end

% 1. Standardized Spatial Colors (Post-FUS)
% Red is still the "Focus", Blue is the "Periphery" (1.25mm away)
spatial_colors = [
    0.85, 0.10, 0.10;  % 0-250um (Red)
    1.00, 0.50, 0.00;  % 250-500um (Orange)
    0.90, 0.85, 0.10;  % 500-750um (Yellow)
    0.10, 0.70, 0.20;  % 750-1000um (Green)
    0.00, 0.45, 0.75]; % 1000-1250um (Blue)

% 2. Grayscale Baseline Gradient (Pre-FUS)
gray_shades = [0, 0, 0; 0.2, 0.2, 0.2; 0.4, 0.4, 0.4; 0.6, 0.6, 0.6; 0.75, 0.75, 0.75];

% UPDATED LABELS for distance brackets
labels = {'0-250 \mum', '250-500 \mum', '500-750 \mum', '750-1000 \mum', '1000-1250 \mum'};

figure('Color', 'w', 'Name', ['Target-Centric Sanity: ' expID], 'Position', [100 100 1250 800]);
hold on;

h_pre = gobjects(1,5); h_b1 = gobjects(1,5);
for p = 1:5
    % --- PRE-FUS (Grayscale Gradient) ---
    tr_pre = target_results.(expID).spatial(p).pre_avg_trace;
    h_pre(p) = plot(tr_pre, '-', 'Color', gray_shades(p,:), 'LineWidth', 2.0); 
    
    % --- BIN 1 (Colored Solid) ---
    tr1 = target_results.(expID).spatial(p).temporal(1).avg_trace;
    h_b1(p) = plot(tr1, '-', 'Color', spatial_colors(p,:), 'LineWidth', 3.5);
    
    % --- BIN 3 (Colored Dashed) ---
    if length(target_results.(expID).spatial(p).temporal) >= 3
        tr3 = target_results.(expID).spatial(p).temporal(3).avg_trace;
        plot(tr3, '--', 'Color', spatial_colors(p,:), 'LineWidth', 2.5);
    end
end

% Stimulus Guide
line([55 55], [-0.05 1], 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 2);
text(56, -0.01, 'Stim Onset', 'FontSize', 12, 'FontWeight', 'bold');

% Formatting
grid on;
set(gca, 'FontSize', 14, 'LineWidth', 1.5);
xlabel('Frame Number', 'FontWeight', 'bold');
ylabel('dF/F (Baseline Corrected)', 'FontWeight', 'bold');
title(['Target-Centric Integrity: Focus (Red) to Periphery (Blue) - ' expID], 'FontSize', 18);

% Legend
lgd = legend(h_b1, labels, 'Location', 'northeastoutside');
title(lgd, 'Distance from Focus');

% Grayscale Logic Labels
text(1.02, 0.4, 'Pre-FUS Baseline:', 'Units', 'normalized', 'FontWeight', 'bold');
text(1.02, 0.37, 'Black (Focus) \rightarrow Light Gray (1.25mm)', 'Units', 'normalized', 'FontSize', 11);

% Scale
all_traces = [target_results.(expID).spatial(1).temporal(1).avg_trace];
ylim([-0.02, max(all_traces)*1.4]);
xlim([40 105]);