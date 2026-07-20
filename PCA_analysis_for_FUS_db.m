function [PC1, PC2, PC3, score] = PCA_analysis_for_FUS_db(all_trials, num_pre_trials, num_post_trials, excluded_trials, initial_stim_frame, max_analysis_frame)
    % [Previous code remains unchanged up to the "Scatter Plotting the PCA data - Averaged per Trial" section]

    %% Scatter Plotting the PCA data - Averaged per Trial
    % Initialize constants for averaging
    total_num_trials = num_pre_trials + num_post_trials;
    trial_averages = zeros(total_num_trials, 3); % To store averaged PC scores per trial
    valid_trials = setdiff(1:total_num_trials, excluded_trials); % Remaining valid trials
    trial_colors = zeros(total_num_trials, 3); % To store color per trial

    % Compute average PC scores for each trial
    for trial = valid_trials
        % Define frame range specific to this trial
        frame_start = (trial - 1) * 100 + initial_stim_frame; % Starting frame in score
        frame_end = frame_start + (max_analysis_frame - initial_stim_frame); % Ending frame in score
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

    %% Perform GMM Clustering on Averaged per Trial Data
    num_clusters = 2; % Specify 2 clusters
    gm = fitgmdist(trial_averages(valid_trials, 1:3), num_clusters);
    cluster_indices = cluster(gm, trial_averages(valid_trials, 1:3));

    %% Define Distinct Colors for GMM Clusters
    gmm_cluster_colors = [1, 0, 0; 0, 1, 0]; % Red and Green for Cluster 1 and Cluster 2

    %% Create 2x2 Scatterplot Figure for Averaged per Trial Data
    figure;
    t = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact');

    % PC1 vs PC2
    ax1 = nexttile(t, 1);
    hold(ax1, 'on');
    xlabel(ax1, 'PC1');
    ylabel(ax1, 'PC2');
    title(ax1, 'PC1 vs PC2 (Averaged per Trial)');

    % PC1 vs PC3
    ax2 = nexttile(t, 2);
    hold(ax2, 'on');
    xlabel(ax2, 'PC1');
    ylabel(ax2, 'PC3');
    title(ax2, 'PC1 vs PC3 (Averaged per Trial)');

    % PC2 vs PC3
    ax3 = nexttile(t, 3);
    hold(ax3, 'on');
    xlabel(ax3, 'PC2');
    ylabel(ax3, 'PC3');
    title(ax3, 'PC2 vs PC3 (Averaged per Trial)');

    % Scatter Plot Points (Colored by GMM Clusters)
    for trial_idx = 1:length(valid_trials)
        point_color = gmm_cluster_colors(cluster_indices(trial_idx), :);
        scatter(ax1, trial_averages(valid_trials(trial_idx), 1), trial_averages(valid_trials(trial_idx), 2), 50, point_color, 'filled');
        scatter(ax2, trial_averages(valid_trials(trial_idx), 1), trial_averages(valid_trials(trial_idx), 3), 50, point_color, 'filled');
        scatter(ax3, trial_averages(valid_trials(trial_idx), 2), trial_averages(valid_trials(trial_idx), 3), 50, point_color, 'filled');
    end

    % 3D Scatterplot
    ax4 = nexttile(t, 4);
    scatter3(ax4, trial_averages(valid_trials, 1), trial_averages(valid_trials, 2), trial_averages(valid_trials, 3), 50, cluster_indices, 'filled');
    xlabel(ax4, 'PC1');
    ylabel(ax4, 'PC2');
    zlabel(ax4, 'PC3');
    title(ax4, '3D Scatterplot of PCA (Averaged per Trial)');

    %% Calculate Davies-Bouldin Index
    db_index = davies_bouldin_index(trial_averages(valid_trials, 1:3), cluster_indices);
    fprintf('Davies-Bouldin Index: %.4f\n', db_index);
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
