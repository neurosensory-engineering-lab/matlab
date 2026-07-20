%% SINGLE-TRIAL QC VISUALIZER (PRE & POST | RAW vs DETRENDED)
% 1. TARGET CONFIGURATION (Change these to explore!)
target_exp   = 'H1';             % Which experiment? (e.g., 'H1', 'L2', 'C3')
target_phase = 'Post';            % Set to 'Pre' or 'Post'
target_bin   = 1;                % Which post-FUS bin? (Ignored if target_phase is 'Pre')
target_mask  = 5;                % Which PC1 Bracket? (1 = Top 10%, 5 = 50-60%)

% 2. QC Parameters
baseline_idx = 50:55; 
resp_win = 56:100; 
fs = 18.57; drift_sec = 10; drift_window = round(drift_sec * fs);
detrendTrace = @(raw) raw - conv(raw, ones(drift_window,1)/drift_window, 'same');
THRESH_SD = 0.5;        
FINAL_Z   = 5.0;  
bracket_labels = {'Top 10%', '80-90%', '70-80%', '60-70%', '50-60%'};

%% 3. EXTRACT DATA DIRECTLY FROM STRUCT
if ~exist('all_results', 'var'), error('all_results struct is missing!'); end

try
    if strcmpi(target_phase, 'Pre')
        raw_traces = all_results.(target_exp).spatial(target_mask).pre_raw_traces;
        m_keep     = all_results.(target_exp).spatial(target_mask).pre_m_keep;
        startT = 1; title_str = sprintf('%s | PRE-FUS BASELINE | %s | Raw vs Detrended', target_exp, bracket_labels{target_mask});
    else
        raw_traces = all_results.(target_exp).spatial(target_mask).temporal(target_bin).post_raw_traces;
        m_keep     = all_results.(target_exp).spatial(target_mask).temporal(target_bin).m_keep;
        startT = (target_bin - 1) * 10 + 1;
        title_str = sprintf('%s | POST-FUS Bin %d | %s | Raw vs Detrended', target_exp, target_bin, bracket_labels{target_mask});
    end
catch
    error('Data not found. Did this experiment finish extracting?');
end

num_trials = size(raw_traces, 2); nImg = size(raw_traces, 1);

%% 4. PLOT DASHBOARD
figV = figure(815); clf; set(figV, 'Color', 'w', 'Position', [50 50 1600 800]);
tlo = tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
title(tlo, title_str, 'FontSize', 20, 'FontWeight', 'bold');

for t = 1:num_trials
    ax = nexttile; hold on;
    
    % Raw Trace
    raw_tr = raw_traces(:, t);
    raw_tr_zeroed = raw_tr - mean(raw_tr(baseline_idx)); 
    
    % Detrended Trace
    tr = detrendTrace(raw_tr);
    tr = tr - mean(tr(baseline_idx)); 
    
    % Metrics
    sd_base = std(tr(baseline_idx)); 
    p_resp = max(tr(resp_win));
    z_score = p_resp / (sd_base + eps);
    passed = m_keep(t);
    
    % Highlights
    fill([baseline_idx(1) baseline_idx(end) baseline_idx(end) baseline_idx(1)], [-10 -10 10 10], [0.9 0.9 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off'); 
    fill([resp_win(1) resp_win(end) resp_win(end) resp_win(1)], [-10 -10 10 10], [1.0 0.95 0.8], 'EdgeColor', 'none', 'HandleVisibility', 'off'); 
    
    % --- PLOT BOTH WITH DISTINCT STYLES ---
    plot(raw_tr_zeroed, 'Color', [0.4 0.7 1.0], 'LineWidth', 4, 'DisplayName', 'Raw Data (Thick Blue)'); 
    
    if passed
        plot(tr, 'k--', 'LineWidth', 2, 'DisplayName', 'QC Filtered (Dashed)');
        title_color = [0.1 0.6 0.1]; status_str = 'ACCEPTED';
    else
        plot(tr, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 2, 'DisplayName', 'QC Filtered (Fail)'); 
        title_color = [0.8 0.1 0.1]; status_str = 'REJECTED';
    end
    
    plot(resp_win, repmat(p_resp, length(resp_win), 1), '--r', 'LineWidth', 1, 'HandleVisibility', 'off');
    if t == 1, legend('Location', 'best', 'FontSize', 9); end
    
    title(sprintf('Trial %d: %s\nSD = %.2f | Z = %.1f', startT + t - 1, status_str, sd_base, z_score), 'Color', title_color, 'FontSize', 11);
    xlim([1 nImg]); ylim([min([-0.5, min(tr)-0.2]), max([2.0, max(tr)+0.5])]); grid on;
end