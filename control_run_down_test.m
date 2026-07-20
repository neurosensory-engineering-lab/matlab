%% CONTROL TREND & TRIPLE GALLERY: HERTZ-BASED DETRENDING (V4.7)
% Goal: Use fs to define a consistent drift-removal window across experiments.

%% 1. CONFIGURATION
fs = 18.57;            % <--- SET THIS: Your actual sampling frequency (Hz)
drift_sec = 6;      % <--- SET THIS: Duration of the trend window (seconds)
THRESH_SD = 0.02;   
FINAL_Z   = 1;    
CONTROLS  = {'C1', 'C2', 'C3'}; 

% Convert seconds to frames for the moving average
drift_window = round(drift_sec * fs); 

if ~exist('target_results', 'var')
    load('FUS_WideField_TargetResults_FullTraces.mat');
end

% Figure Setup
figTrend = figure(401); clf; set(figTrend, 'Color', 'w', 'Position', [50 100 500 500]);
figExcl  = figure(402); clf; set(figExcl, 'Color', 'w', 'Position', [560 100 1300 500]);

axNoise = subplot(1,3,1, 'Parent', figExcl); hold(axNoise, 'on'); grid(axNoise, 'on');
axResp  = subplot(1,3,2, 'Parent', figExcl); hold(axResp, 'on'); grid(axResp, 'on');
axKept  = subplot(1,3,3, 'Parent', figExcl); hold(axKept, 'on'); grid(axKept, 'on');

colors = lines(length(CONTROLS));
baseline_idx = 1:55; tone_onset = 55;

%% 2. PROCESSING LOOP
counts = struct('volatile', 0, 'nonresp', 0, 'kept', 0);

for i = 1:length(CONTROLS)
    id = CONTROLS{i};
    pre_raw = target_results.(id).spatial(1).pre_raw_traces;
    post_bins = target_results.(id).spatial(1).temporal;
    post_raw = [];
    for b = 1:length(post_bins), post_raw = [post_raw, post_bins(b).all_traces]; end
    all_raw_traces = [pre_raw, post_raw];
    
    t_idx = []; p_amp = [];
    
    for t = 1:size(all_raw_traces, 2)
        raw_tr = all_raw_traces(:, t);
        
        % --- FREQUENCY-AWARE DETRENDING ---
        % Moving average acts as a Low-Pass filter to estimate the trend
        % We use conv to ensure this works without the Signal Processing Toolbox
        kernel = ones(drift_window, 1) / drift_window;
        trend = conv(raw_tr, kernel, 'same'); 
        
        % Fix the edges (conv with 'same' pads with zeros, which ruins edges)
        trend(1:round(drift_window/2)) = trend(round(drift_window/2)+1);
        trend(end-round(drift_window/2):end) = trend(end-round(drift_window/2)-1);
        
        % Subtract trend (High-Pass effect)
        tr = raw_tr - trend;
        
        % Re-zero to pre-stimulus mean
        tr = tr - mean(tr(baseline_idx));
        
        % QC Calculations
        sd_base = std(tr(baseline_idx));
        mu_base = mean(tr(baseline_idx));
        peak_val = max(tr(tone_onset+1:end));
        z_score = (peak_val - mu_base) / (sd_base + eps);
        
        if sd_base > THRESH_SD
            plot(axNoise, tr, 'Color', [0.85 0.33 0.10 0.1], 'LineWidth', 0.5);
            counts.volatile = counts.volatile + 1;
        elseif z_score < FINAL_Z
            plot(axResp, tr, 'Color', [0.93 0.69 0.13 0.15], 'LineWidth', 0.5);
            counts.nonresp = counts.nonresp + 1;
        else
            plot(axKept, tr, 'Color', [0.47 0.67 0.19 0.2], 'LineWidth', 0.5);
            t_idx(end+1) = t;
            p_amp(end+1) = peak_val;
            counts.kept = counts.kept + 1;
        end
    end
    
    figure(figTrend); hold on;
    p_h(i) = plot(t_idx, p_amp, '-o', 'Color', colors(i,:), ...
        'MarkerFaceColor', colors(i,:), 'LineWidth', 1.2, 'DisplayName', id);
end

%% 3. STYLING
all_axes = [axNoise, axResp, axKept];
titles = {'1. VOLATILE', '2. NON-RESP', '3. INCLUDED (HP-Filt)'};
panel_colors = {[0.85 0.33 0.1], [0.93 0.69 0.13], [0.47 0.67 0.19]};

for j = 1:3
    set(all_axes(j), 'YLim', [-0.05 0.4], 'XLim', [1 110]);
    title(all_axes(j), titles{j}, 'Color', panel_colors{j});
    line(all_axes(j), [55 55], [-1 1], 'Color', 'k', 'LineStyle', '--');
end

figure(figTrend); grid on;
title(['Peak Habituation Trend (fs = ' num2str(fs) 'Hz)']);
ylabel('Detrended Peak dF/F'); xlabel('Trial Number');
legend(p_h, 'Location', 'northeast');