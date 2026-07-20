function [peak_values, consensus_frame] = extract_primary_peak(all_trial_traces, stim_frame, fs)
% EXTRACT_PRIMARY_PEAK Isolates the hard-wired A1 response and ignores late waves.
%
% Inputs:
%   all_trial_traces : Matrix (Trials x Frames)
%   stim_frame       : Frame number where auditory stimulus starts
%   fs               : Sampling rate (Hz) to define biological window
%
% Outputs:
%   peak_values     : Column vector of peak dF/F values for each trial
%   consensus_frame : The frame number used for extraction

    %% 1. Define Primary Window (Biological Constraint)
    % A1 responses typically peak 50ms-250ms post-stimulus.
    % We search in a tight window to avoid anesthesia-induced late waves.
    search_start = stim_frame + 1;
    search_end   = stim_frame + round(0.5 * fs); % Search within 500ms of stim
    
    % Ensure we don't exceed trace length
    search_end = min(search_end, size(all_trial_traces, 2));
    primary_window = search_start:search_end;

    %% 2. Compute Median Trace & Find Consensus
    % Median ignores trial-specific outliers (like random slow-wave spikes)
    median_trace = median(all_trial_traces, 1);
    
    [~, rel_idx] = max(median_trace(primary_window));
    consensus_frame = rel_idx + primary_window(1) - 1;

    %% 3. Extract Trial Values (3-frame integration)
    % We average 1 frame before/after the peak to stabilize against shot noise
    win_start = max(1, consensus_frame - 1);
    win_end   = min(size(all_trial_traces, 2), consensus_frame + 1);
    
    num_trials = size(all_trial_traces, 1);
    peak_values = mean(all_trial_traces(:, win_start:win_end), 2);
    
    % Display finding
    fprintf('Primary peak locked at Frame %d (approx %.2f ms post-stim)\n', ...
            consensus_frame, (consensus_frame - stim_frame) * (1000/fs));
end