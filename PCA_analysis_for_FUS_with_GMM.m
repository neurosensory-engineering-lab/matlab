
function [PC1, PC2, PC3, score] = PCA_analysis_for_FUS_with_GMM(all_trials, num_pre_trials, num_post_trials, excluded_trials, initial_stim_frame, max_analysis_frame)
% ----- Downsample and Linearize ----- %
% "all_trials" is a 4D image stack where all trials -- including both pre-FUS and
% post-FUS -- are appended to one huge stack, essentially as if you hit
% record and never stopped until the end of the experiment. 

% "excluded_trials" is a list of trials that are outliers either because of
% experimental issue (e.g. trigger not activating, perturbed state of anesthesia,
% etc.)
% "initia

% NOTE: The scatterplotting at the end assumes that there are 10 pre-FUS
% and 10 post-FUS trials. Doesn't have to be that way for the PCA analysis
% and plotting the PCs, but for the scatterplotting for subsequent scatter
% analysis, this matters because the function is currently set up to do the
% coloring based on 10 pre/ 10 post. If this is not what you did in the
% experiment, you can either put together "m" such that it only contains 10
% of the pre and 10 of the post, or you can edit the code in the last
% section ("Scatter Plotting the PCA data").

% In this approach (following Makino et al., Neuron 2017), individual
% pixels are considered variables and each frame is a "trial," idea being
% that there are spatially-defined patterns of activity, and at each
% timepoint, different aspects of the map are superimposed. A presumably
% apparent example might be the barrel cortex, where the different PCA
% might correpond to different barrels.
% JANF 2024

% Parameters for memory optimization
downsample_factor = 0.25; % Downsample to 25% of original size
chunk_size = 50; % Process data in chunks of 50 frames to save memory
dim1 = size(all_trials, 1);
dim2 = size(all_trials, 2);
num_frames = size(all_trials, 4);
new_dim1 = round(dim1 * downsample_factor);
new_dim2 = round(dim2 * downsample_factor);

% Preallocate reduced data matrix
reduced_dimension_data = zeros(new_dim1 * new_dim2, num_frames, 'single');

% ----- Process Frames in Chunks ----- %
for chunk_start = 1:chunk_size:num_frames
    chunk_end = min(chunk_start + chunk_size - 1, num_frames);
    fprintf('Processing frames %d to %d...\n', chunk_start, chunk_end);

    % Load and downsample current chunk of frames
    resized_chunk = zeros(new_dim1, new_dim2, chunk_end - chunk_start + 1, 'single');
    for frame = chunk_start:chunk_end
        im_temp = single(all_trials(:, :, 1, frame));
        resized_chunk(:, :, frame - chunk_start + 1) = imresize(im_temp, downsample_factor);
    end

    % Linearize each frame and store in reduced_dimension_data
    for i = 1:size(resized_chunk, 3)
        frame_data = resized_chunk(:, :, i);
        reduced_dimension_data(:, chunk_start + i - 1) = frame_data(:);
    end
end

% Normalize data
reduced_dimension_data = reduced_dimension_data - min(reduced_dimension_data(:));
reduced_dimension_data = reduced_dimension_data ./ max(reduced_dimension_data(:));
reduced_dimension_data = reduced_dimension_data * 255;


%% Reduce dimensionality with PCA

% We'll use PCA to reveal the most representative spatial patterns.

[coeff,score,latent,tsquared,explained,mu] = pca(reduced_dimension_data');


%Plot the first two of these
PC1 = zeros(new_dim1, new_dim2);
PC2 = zeros(new_dim1, new_dim2);
PC3 = zeros(new_dim1, new_dim2);
for i = 1:new_dim1
    for j = 1:new_dim2
        PC1(i, j) = coeff((i-1)*new_dim2 + j, 1);
        PC2(i, j) = coeff((i-1)*new_dim2 + j, 2);
        PC3(i, j) = coeff((i-1)*new_dim2 + j, 3);
    end
end


% Show the top 3 PCs

% Plot PC1
subplot(1, 3, 1); % 1 row, 3 columns, first plot
imagesc(PC1);
axis square; % Ensures square aspect ratio
title('PC1', 'FontSize', 16); % Title with font size 16
colorbar; % Optional: Add a colorbar if needed

% Plot PC2
subplot(1, 3, 2); % Second plot
imagesc(PC2);
axis square; % Ensures square aspect ratio
title('PC2', 'FontSize', 16); % Title with font size 16
colorbar; % Optional: Add a colorbar if needed

% Plot PC3
subplot(1, 3, 3); % Third plot
imagesc(PC3);
axis square; % Ensures square aspect ratio
title('PC3', 'FontSize', 16); % Title with font size 16
colorbar; % Optional: Add a colorbar if needed

% Adjust spacing between subplots for better visualization
set(gcf, 'Position', [100, 100, 1200, 400]); % Adjust figure size

% %% (Separate but useful analysis) Use those PCs to mask the data and view region-averaged dF/F based on the PCs. Use a threshold of 0.8 for example. 
% % Note you'll need the function roi_plot.m
% % Normalize the PCs so that you can do a thresholding based on a 0 to 1
% % scale.
% PC1_norm = PC1./max(max(PC1));
% PC2_norm = PC2./max(max(PC2));
% PC3_norm = PC3./max(max(PC3));
% 
% % This should show you all the trials separated by dotted lines. 
% % Using 0.8 as threshold just cuz.
% roi_plot(resized_movie,PC1_norm>0.8);
% hold on
% roi_plot(resized_movie,PC2_norm>0.8);
% roi_plot(resized_movie,PC3_norm>0.8);


%% Plot how much of each PC explains the variance (basically shows you how many of the top PCs contain meaningful info)
% Matlab stores the individual component variances in 'latent', so we can
% plot the amount of variance explained by pc as a function of pc.
% Essentially, a Scree plot.  It is evident that just the first 2 should
% sum up the vast majority of variance, so going forward we'll do analysis
% with just those two.

figure, plot(latent)
title('Principal component variances')
xlim([0,10]) % Really less than top 10 will be relevant


%% Scatter Plotting the PCA data - three PCs, 2D plots comparing them

% Initialize constants
total_num_trials = num_pre_trials + num_post_trials; % Total trials (first 10 pre-FUS, last 11 post-FUS)

valid_trials = setdiff(1:total_num_trials, excluded_trials); % Remaining valid trials
% initial_stim_frame = 55; % Starting frame for analysis
evoked_response_range = initial_stim_frame:max_analysis_frame; % Range of frames considered
frames_per_trial = length(evoked_response_range); % Number of responsive frames per trial

% Define colormaps for reversed shades: dark to light
blue_map = linspace(0.1, 1, num_pre_trials);  % num_pre_trials number of shades of blue (dark to light)
orange_map = linspace(0.5, 1, num_post_trials); % num_post_trials shades of orange (dark to light)

% Create figure with tiled layout
figure;
t = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact'); % 2x2 grid layout

% Define axes for plots
ax1 = nexttile(t, 1);
ax2 = nexttile(t, 2);
ax3 = nexttile(t, 3);

% Loop through trials and plot individual frame points
for trial = valid_trials
    % Define frame range specific to this trial
    frame_start = (trial - 1) * 100 + initial_stim_frame; % Starting frame in `score`
    frame_end = frame_start + frames_per_trial - 1; % Ending frame in `score`

    % Ensure frame range is within bounds of score matrix
    if frame_end > size(score, 1)
        error('Frame range exceeds dimensions of the score matrix.');
    end

    % Define the actual frame range for plotting
    frame_range = frame_start:frame_end;

% Determine color based on trial number (dark to light blue or orange)
if trial <= num_pre_trials  % Pre-FUS trials
    % Get progressively lighter blue for pre-FUS
    blue_val = blue_map(trial);
    color = [blue_val, blue_val, 1]; % RGB for varying blue shades
elseif trial > num_pre_trials && trial <= num_pre_trials + num_post_trials  % Specified range of post-FUS trials
    % Get progressively lighter orange for post-FUS
    post_index = trial - num_pre_trials; % Index relative to post trials
    orange_val = orange_map(post_index);
    color = [orange_val, orange_val * 0.5, 0]; % RGB for varying orange shades (dark to light orange)
% else
%     % Optional handling for trials outside the specified range, if needed
%     color = [0.5, 0.5, 0.5]; % Example: default to gray
end

    % Plot each frame within the evoked response range
    for frame = frame_range
        % Extract the PCA scores for the current frame and trial
        frame_scores = score(frame, :);

        % Plot PC1 vs PC2GMM
        scatter(ax1, frame_scores(1), frame_scores(2), 30, color, 'filled'); % Larger dots
        hold(ax1, 'on');
        axis(ax1, 'square');

        % Plot PC1 vs PC3
        scatter(ax2, frame_scores(1), frame_scores(3), 30, color, 'filled'); % Larger dots
        hold(ax2, 'on');
        axis(ax2, 'square');

        % Plot PC2 vs PC3
        scatter(ax3, frame_scores(2), frame_scores(3), 30, color, 'filled'); % Larger dots
        hold(ax3, 'on');
        axis(ax3, 'square');
% pause
% disp('press any key')
    end
end

% Add labels to the plots
xlabel(ax1, 'PC1');
ylabel(ax1, 'PC2');

xlabel(ax2, 'PC1');
ylabel(ax2, 'PC3');

xlabel(ax3, 'PC2');
ylabel(ax3, 'PC3');

% Set the axis limits based on the data range to prevent rescaling
x_range = [min(score(:, 1)), max(score(:, 1))];  % X axis range based on PC1
y_range = [min(score(:, 2)), max(score(:, 2))];  % Y axis range based on PC2
z_range = [min(score(:, 3)), max(score(:, 3))];  % Z axis range based on PC3

xlim(ax1, x_range);
ylim(ax1, y_range);
xlim(ax2, x_range);
ylim(ax2, z_range);
xlim(ax3, y_range);
ylim(ax3, z_range);

valid_scores = score;

%% Scatter Plotting the PCA data - Averaged per Trial
% Initialize constants for averaging
trial_averages = zeros(total_num_trials, 3); % To store averaged PC scores per trial
valid_trials = setdiff(1:total_num_trials, excluded_trials); % Remaining valid trials
trial_colors = zeros(total_num_trials, 3); % To store color per trial

% Compute average PC scores for each trial
for trial = valid_trials
    % Define frame range specific to this trial
    frame_start = (trial - 1) * 100 + initial_stim_frame; % Starting frame in `score`
    frame_end = frame_start + frames_per_trial - 1; % Ending frame in `score`
    frame_range = frame_start:frame_end;

    % Average scores over the frame range
    trial_averages(trial, :) = mean(score(frame_range, 1:3), 1);

    % Assign color based on trial type (pre-FUS or post-FUS)
    if trial <= num_pre_trials
        trial_colors(trial, :) = [0, 0, 1]; % Blue for pre-FUS
    else
        trial_colors(trial, :) = [1, 0, 0]; % Red for post-FUS
    end
end

% Create figure with tiled layout for averaged scatter plots
figure;
t_avg = tiledlayout(1, 3, 'TileSpacing', 'Compact', 'Padding', 'Compact');

% PC1 vs PC2
ax1_avg = nexttile(t_avg, 1);
scatter(ax1_avg, trial_averages(valid_trials, 1), trial_averages(valid_trials, 2), ...
    50, trial_colors(valid_trials, :), 'filled');
xlabel(ax1_avg, 'PC1');
ylabel(ax1_avg, 'PC2');
title(ax1_avg, 'PC1 vs PC2');
axis(ax1_avg, 'square');

% PC1 vs PC3
ax2_avg = nexttile(t_avg, 2);
scatter(ax2_avg, trial_averages(valid_trials, 1), trial_averages(valid_trials, 3), ...
    50, trial_colors(valid_trials, :), 'filled');
xlabel(ax2_avg, 'PC1');
ylabel(ax2_avg, 'PC3');
title(ax2_avg, 'PC1 vs PC3');
axis(ax2_avg, 'square');

% PC2 vs PC3
ax3_avg = nexttile(t_avg, 3);
scatter(ax3_avg, trial_averages(valid_trials, 2), trial_averages(valid_trials, 3), ...
    50, trial_colors(valid_trials, :), 'filled');
xlabel(ax3_avg, 'PC2');
ylabel(ax3_avg, 'PC3');
title(ax3_avg, 'PC2 vs PC3');
axis(ax3_avg, 'square');

% %% Perform GMM Clustering (Flexible Clustering)
% num_clusters = 2; % Specify 2 clusters
% gm = fitgmdist(valid_scores(:, 1:3), num_clusters); % Fit GMM with 2 components
% cluster_indices = cluster(gm, valid_scores(:, 1:3)); % Predict clusters
% 
% %% Define Distinct Colors for GMM Clusters
% gmm_cluster_colors = [1, 0, 0; 0, 1, 0]; % Red and Green for Cluster 1 and Cluster 2
% 
% %% Create 2x2 Scatterplot Figure
% figure;
% t = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact'); % 2x2 layout
% 
% % PC1 vs PC2
% ax1 = nexttile(t, 1);
% hold(ax1, 'on');
% xlabel(ax1, 'PC1');
% ylabel(ax1, 'PC2');
% title(ax1, 'PC1 vs PC2');
% 
% % PC1 vs PC3
% ax2 = nexttile(t, 2);
% hold(ax2, 'on');
% xlabel(ax2, 'PC1');
% ylabel(ax2, 'PC3');
% title(ax2, 'PC1 vs PC3');
% 
% % PC2 vs PC3
% ax3 = nexttile(t, 3);
% hold(ax3, 'on');
% xlabel(ax3, 'PC2');
% ylabel(ax3, 'PC3');
% title(ax3, 'PC2 vs PC3');
% 
% % Scatter Plot Points (Colored by GMM Clusters)
% 
% for trial_idx = 1:size(valid_scores, 1)
%     % Scatter points for each trial based on GMM cluster
%     point_color = gmm_cluster_colors(cluster_indices(trial_idx), :);
% 
%     scatter(ax1, valid_scores(trial_idx, 1), valid_scores(trial_idx, 2), 30, ...
%             point_color, 'filled');
%     scatter(ax2, valid_scores(trial_idx, 1), valid_scores(trial_idx, 3), 30, ...
%             point_color, 'filled');
%     scatter(ax3, valid_scores(trial_idx, 2), valid_scores(trial_idx, 3), 30, ...
%             point_color, 'filled');
% end
% 
% %% Add 3D Scatterplot
% ax4 = nexttile(t, 4);
% scatter3(ax4, valid_scores(:, 1), valid_scores(:, 2), valid_scores(:, 3), 30, ...
%          cluster_indices, 'filled');
% xlabel(ax4, 'PC1');
% ylabel(ax4, 'PC2');
% zlabel(ax4, 'PC3');
% title(ax4, '3D Scatterplot of PCA');
% 
% 
% 
%     %% Perform GMM Clustering on Averaged per Trial Data
% 
% %% Perform GMM Clustering on Averaged per Trial Data
% rng(total_num_trials*3); % Set a fixed random seed
% num_clusters = 2; % Specify 2 clusters
% size(valid_trials)
% disp('press any key')
% pause
% trial_averages(valid_trials, 1:3)
% disp('press ay key')
% pause
% 
% gm = fitgmdist(trial_averages(valid_trials, 1:3), num_clusters);
% cluster_indices = cluster(gm, trial_averages(valid_trials, 1:3));
% 
% 
%     % num_clusters = 2; % Specify 2 clusters
%     % gm = fitgmdist(trial_averages(valid_trials, 1:3), num_clusters);
%     % cluster_indices = cluster(gm, trial_averages(valid_trials, 1:3));
% 
%     %% Define Distinct Colors for GMM Clusters
%     gmm_cluster_colors = [1, 0, 0; 0, 1, 0]; % Red and Green for Cluster 1 and Cluster 2

    % %% Create 2x2 Scatterplot Figure for Averaged per Trial Data
    % figure;
    % t = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact');
    % 
    % % PC1 vs PC2
    % ax1 = nexttile(t, 1);
    % hold(ax1, 'on');
    % xlabel(ax1, 'PC1');
    % ylabel(ax1, 'PC2');
    % title(ax1, 'PC1 vs PC2 (Averaged per Trial)');
    % 
    % % PC1 vs PC3
    % ax2 = nexttile(t, 2);
    % hold(ax2, 'on');
    % xlabel(ax2, 'PC1');
    % ylabel(ax2, 'PC3');
    % title(ax2, 'PC1 vs PC3 (Averaged per Trial)');
    % 
    % % PC2 vs PC3
    % ax3 = nexttile(t, 3);
    % hold(ax3, 'on');
    % xlabel(ax3, 'PC2');
    % ylabel(ax3, 'PC3');
    % title(ax3, 'PC2 vs PC3 (Averaged per Trial)');
    % 
    % % Scatter Plot Points (Colored by GMM Clusters)
    % for trial_idx = 1:length(valid_trials)
    %     point_color = gmm_cluster_colors(cluster_indices(trial_idx), :);
    %     scatter(ax1, trial_averages(valid_trials(trial_idx), 1), trial_averages(valid_trials(trial_idx), 2), 50, point_color, 'filled');
    %     scatter(ax2, trial_averages(valid_trials(trial_idx), 1), trial_averages(valid_trials(trial_idx), 3), 50, point_color, 'filled');
    %     scatter(ax3, trial_averages(valid_trials(trial_idx), 2), trial_averages(valid_trials(trial_idx), 3), 50, point_color, 'filled');
    % end
    % 
    % % 3D Scatterplot
    % ax4 = nexttile(t, 4);
    % scatter3(ax4, trial_averages(valid_trials, 1), trial_averages(valid_trials, 2), trial_averages(valid_trials, 3), 50, cluster_indices, 'filled');
    % xlabel(ax4, 'PC1');
    % ylabel(ax4, 'PC2');
    % zlabel(ax4, 'PC3');
    % title(ax4, '3D Scatterplot of PCA (Averaged per Trial)');

%% Calculate Davies-Bouldin Index for pre- and post-FUS data
pre_fus_data = trial_averages(1:num_pre_trials, 1:3);
post_fus_data = trial_averages(num_pre_trials+1:end, 1:3);

% Combine pre- and post-FUS data
combined_data = [pre_fus_data; post_fus_data];

% Create labels for pre- and post-FUS data
labels = [ones(num_pre_trials, 1); 2*ones(num_post_trials, 1)];

% Calculate Davies-Bouldin Index
db_index_pre_post = davies_bouldin_index(combined_data, labels);
fprintf('Davies-Bouldin Index (Pre vs Post FUS): %.4f\n', db_index_pre_post);

    
    % %% Calculate Davies-Bouldin Index
    % db_index = davies_bouldin_index(trial_averages(valid_trials, 1:3), cluster_indices);
    % fprintf('Davies-Bouldin Index: %.4f\n', db_index);
end

function db_index = davies_bouldin_index(X, labels)
    k = max(labels);
    centroids = zeros(k, size(X, 2));
    for i = 1:k
        centroids(i, :) = mean(X(labels == i, :));
    end
    
    S = zeros(1, k);
    for i = 1:k
        cluster_points = X(labels == i, :);
        S(i) = mean(sqrt(sum((cluster_points - centroids(i, :)).^2, 2)));
    end
    
    R = zeros(k);
    for i = 1:k
        for j = i+1:k
            M = norm(centroids(i, :) - centroids(j, :));
            R(i, j) = (S(i) + S(j)) / M;
            R(j, i) = R(i, j);
        end
    end
    
    db_index = mean(max(R));
end
