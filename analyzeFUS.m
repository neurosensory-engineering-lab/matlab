function analyzeFUS(full_dataset, pre_FUS_trials, post_FUS_trials, window_start_frame, window_end_frame)
    % Analyze FUS effects using PCA on trial-specific data with memory optimization and visualization
    % No outlier handling is applied in this version.
    %
    % Inputs:
    %   full_dataset: 4D matrix (height x width x 1 x total_frames)
    %   pre_FUS_trials: Number of pre-FUS trials
    %   post_FUS_trials: Number of post-FUS trials
    %   window_start_frame: Start frame of the relevant window (inclusive)
    %   window_end_frame: End frame of the relevant window (inclusive)

    % Parameters
    [frame_size, ~, ~, total_frames] = size(full_dataset);
    frames_per_trial = total_frames / (pre_FUS_trials + post_FUS_trials);
    num_trials = pre_FUS_trials + post_FUS_trials;

    % Validate inputs
    if frames_per_trial ~= floor(frames_per_trial)
        error('Total frames do not evenly divide into trials.');
    end
    if window_end_frame > frames_per_trial || window_start_frame < 1
        error('Window frames exceed trial frame range.');
    end

    % Select the relevant window of frames
    relevant_frames = window_start_frame:window_end_frame;
    num_relevant_frames = length(relevant_frames);

    % Pre-allocate memory for trial data
    disp('Step 1: Extracting relevant frames and reshaping data...');
    trial_data = zeros(num_trials, frame_size * frame_size, 'single');
    
    for trial_idx = 1:num_trials
        trial_start_frame = (trial_idx - 1) * frames_per_trial + 1;
        trial_end_frame = trial_idx * frames_per_trial;
        
        % Extract relevant frames for the current trial
        trial_frames = full_dataset(:, :, :, trial_start_frame:trial_end_frame);
        trial_frames_relevant = trial_frames(:, :, :, relevant_frames);
        
        % Reshape frames for each trial to 2D: pixels x frames
        reshaped_frames = reshape(trial_frames_relevant, [], num_relevant_frames);
        
        % Take the mean of the frames (across the time axis) for each trial
        trial_data(trial_idx, :) = mean(reshaped_frames, 2)';
        
        % Progress update
        if mod(trial_idx, 1) == 0
            disp(['    Processed trial ' num2str(trial_idx) '/' num2str(num_trials) ...
                ' (' num2str((trial_idx / num_trials) * 100, '%.2f') '% complete).']);
        end
    end

    % Normalize the trial data (z-score)
    disp('Step 2: Normalizing data using z-score...');
    trial_data_z = zscore(trial_data, 0, 'all');
    disp('    Normalization complete.');

    % Normalize each row to have the same overall intensity (mean intensity)
    disp('Step 3: Normalizing intensity across trials...');
    row_means = mean(trial_data_z, 2); % Compute mean for each trial (row)
    trial_data_z = trial_data_z - row_means; % Subtract mean from each trial to center it at 0
    row_norm_factors = max(abs(trial_data_z), [], 2); % Get the max absolute value per trial
    trial_data_z = trial_data_z ./ row_norm_factors; % Normalize each trial by its max intensity
    disp('    Intensity normalization complete.');

    % Display normalized data
    figure, imagesc(trial_data_z);
    colorbar;
    title('Normalized Trial Data');

    % Perform PCA
    disp('Step 4: Performing PCA...');
    [coeff, score, latent] = pca(trial_data_z);
    disp('    PCA complete.');

    % Visualize PCA results
    disp('Step 5: Visualizing results...');
    pre_trials = 1:pre_FUS_trials;         % Indices for pre-FUS trials
    post_trials = pre_FUS_trials+1:num_trials; % Indices for post-FUS trials

    % Scatterplots
    figure;
    subplot(1, 3, 1);
    scatter(score(pre_trials, 1), score(pre_trials, 2), 'b', 'filled'); % Pre-FUS
    hold on;
    scatter(score(post_trials, 1), score(post_trials, 2), 'r', 'filled'); % Post-FUS
    for trial_idx = 1:num_trials
        color = 'b';
        if trial_idx > pre_FUS_trials
            color = 'r';
        end
        text(score(trial_idx, 1), score(trial_idx, 2), num2str(trial_idx), ...
            'FontSize', 14, 'Color', color);
    end
    xlabel('PC1');
    ylabel('PC2');
    title('PC1 vs. PC2');
    legend('Pre-FUS', 'Post-FUS', 'FontSize', 14);

    subplot(1, 3, 2);
    scatter(score(pre_trials, 1), score(pre_trials, 3), 'b', 'filled'); % Pre-FUS
    hold on;
    scatter(score(post_trials, 1), score(post_trials, 3), 'r', 'filled'); % Post-FUS
    for trial_idx = 1:num_trials
        color = 'b';
        if trial_idx > pre_FUS_trials
            color = 'r';
        end
        text(score(trial_idx, 1), score(trial_idx, 3), num2str(trial_idx), ...
            'FontSize', 14, 'Color', color);
    end
    xlabel('PC1');
    ylabel('PC3');
    title('PC1 vs. PC3');

    subplot(1, 3, 3);
    scatter(score(pre_trials, 2), score(pre_trials, 3), 'b', 'filled'); % Pre-FUS
    hold on;
    scatter(score(post_trials, 2), score(post_trials, 3), 'r', 'filled'); % Post-FUS
    for trial_idx = 1:num_trials
        color = 'b';
        if trial_idx > pre_FUS_trials
            color = 'r';
        end
        text(score(trial_idx, 2), score(trial_idx, 3), num2str(trial_idx), ...
            'FontSize', 14, 'Color', color);
    end
    xlabel('PC2');
    ylabel('PC3');
    title('PC2 vs. PC3');
    legend('Pre-FUS', 'Post-FUS', 'FontSize', 14);

    disp('    Visualization complete.');
    disp('Analysis complete!');
end
