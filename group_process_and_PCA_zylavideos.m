function av_dFF_combined = group_process_and_PCA_zylavideos(pre_FUS_basename, post_FUS_basename, ...
    num_pre_FUS_files, num_post_FUS_files, advance_frames, numpix_y, numpix_x, baselineframes, smoothradius, ...
    frame_start, frame_end)

    % Initialize waitbar
    h = waitbar(0, 'Starting video processing...', 'Name', 'Processing Videos');

    %% Step 1: Process Pre-FUS Videos
    disp('Processing pre-FUS videos...');
    av_dFF_pre_FUS = group_process_zylavideos(pre_FUS_basename, num_pre_FUS_files, 0,...
        numpix_y, numpix_x, baselineframes, smoothradius, h, 'Pre-FUS');

    %% Step 2: Process Post-FUS Videos
    disp('Processing post-FUS videos...');
    av_dFF_post_FUS = group_process_zylavideos(post_FUS_basename, num_post_FUS_files, advance_frames,...
        numpix_y, numpix_x, baselineframes, smoothradius, h, 'Post-FUS');

    %% Step 3: Combine Pre- and Post-FUS dFF Data
    disp('Combining pre- and post-FUS dFF data...');
    av_dFF_combined = cat(4, av_dFF_pre_FUS, av_dFF_post_FUS);

    % %% Step 4: PCA Analysis and Visualization with Frame Restriction
    % disp('Starting PCA analysis...');
    % PCA_analysis_with_clustering(av_dFF_combined, h, frame_start, frame_end);
    % 
    % % Close the waitbar
    % close(h);
    % 
    % disp('Processing and analysis completed.');
end

function PCA_analysis_with_clustering(all_trials, h, frame_start, frame_end)
    % Resize and prepare data for PCA
    disp('Resizing and linearizing data...');
    [dim1, dim2, ~, max_frames] = size(all_trials);
    downsized_movie = zeros(dim1 / 4, dim2 / 4, max_frames);

    for frame_idx = 1:max_frames
        waitbar(frame_idx / max_frames, h, sprintf('Downsizing frames for PCA: %d/%d', frame_idx, max_frames));
        downsized_movie(:, :, frame_idx) = imresize(all_trials(:, :, 1, frame_idx), 0.25);
    end

    reshaped_data = reshape(downsized_movie, [], max_frames)';

    % Perform PCA
    disp('Performing PCA...');
    [coeff, score, ~, ~, explained] = pca(reshaped_data);

    % Display PCs
    disp(['Explained variance by first three PCs: ', num2str(sum(explained(1:3))), '%']);
    PC1 = reshape(coeff(:, 1), size(downsized_movie, 1), size(downsized_movie, 2));
    PC2 = reshape(coeff(:, 2), size(downsized_movie, 1), size(downsized_movie, 2));
    PC3 = reshape(coeff(:, 3), size(downsized_movie, 1), size(downsized_movie, 2));

    % Visualize PCs
    figure;
    subplot(1, 3, 1); imagesc(PC1); axis square; title('PC1'); colorbar;
    subplot(1, 3, 2); imagesc(PC2); axis square; title('PC2'); colorbar;
    subplot(1, 3, 3); imagesc(PC3); axis square; title('PC3'); colorbar;

    % GMM Clustering
    disp('Applying GMM clustering...');
    num_clusters = 2;
    gm = fitgmdist(score(:, 1:3), num_clusters);
    cluster_indices = cluster(gm, score(:, 1:3));

    % Define Distinct Colors for GMM Clusters
    gmm_cluster_colors = [1, 0, 0; 0, 1, 0]; % Red and Green for Cluster 1 and Cluster 2

    % Frame restriction and scatter plots
    disp('Generating scatterplots with restricted frame range...');
    valid_trials = 1:size(score, 1); % Adjust based on your data setup
    figure;
    t = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact'); % 2x2 layout

    % PC1 vs PC2
    ax1 = nexttile(t, 1); hold(ax1, 'on');
    title(ax1, 'PC1 vs PC2'); xlabel(ax1, 'PC1'); ylabel(ax1, 'PC2');
    
    % PC1 vs PC3
    ax2 = nexttile(t, 2); hold(ax2, 'on');
    title(ax2, 'PC1 vs PC3'); xlabel(ax2, 'PC1'); ylabel(ax2, 'PC3');
    
    % PC2 vs PC3
    ax3 = nexttile(t, 3); hold(ax3, 'on');
    title(ax3, 'PC2 vs PC3'); xlabel(ax3, 'PC2'); ylabel(ax3, 'PC3');
    
    % 3D Scatter
    ax4 = nexttile(t, 4);
    scatter3(ax4, score(:, 1), score(:, 2), score(:, 3), 30, cluster_indices, 'filled');
    xlabel(ax4, 'PC1');
    ylabel(ax4, 'PC2');
    zlabel(ax4, 'PC3');
    title(ax4, '3D Scatterplot of PCA');

    for trial = valid_trials
        % Scatter points for each trial based on GMM cluster
        point_color = gmm_cluster_colors(cluster_indices(trial), :);

        scatter(ax1, score(trial, 1), score(trial, 2), 30, point_color, 'filled');
        scatter(ax2, score(trial, 1), score(trial, 3), 30, point_color, 'filled');
        scatter(ax3, score(trial, 2), score(trial, 3), 30, point_color, 'filled');
    end

    hold(ax1, 'off');
    hold(ax2, 'off');
    hold(ax3, 'off');
end

function av_dFF_combined = group_process_zylavideos(basename, num_files, advance_frames, numpix_y, numpix_x, baselineframes, smoothradius, h, video_type)
    % Display information about the video type
    disp(['Processing ' video_type ' videos...']);

    av_dFF_combined = []; % Initialize the combined dF/F matrix

    for i = 1:num_files
        % Construct the filename
        filename = [basename int2str(i+advance_frames) '.tif'];
        disp(['Processing: ' filename]);
        
        % Read the TIFF stack
        info = imfinfo(filename);
        num_images = numel(info);
        frames = zeros(numpix_y, numpix_x, 1, num_images);

        % Load the TIFF images into a 4D matrix
        for j = 1:num_images
            frames(:, :, 1, j) = imread(filename, j);
        end

        % Smooth the frames
        sframes = zeros(size(frames));
        for k = 1:num_images
            sframes(:, :, 1, k) = imgaussfilt(frames(:, :, 1, k), smoothradius);
        end

        % Calculate the baseline average frame
        baseline = sum(sframes(:, :, 1, baselineframes), 4) / numel(baselineframes);

        % Compute dF/F
        dFF = zeros(size(frames));
        for m = 1:num_images
            dF = sframes(:, :, 1, m) - baseline;
            dFF(:, :, 1, m) = dF ./ baseline;
        end

        % Combine the current dF/F into the result matrix
        if isempty(av_dFF_combined)
            av_dFF_combined = dFF;
        else
            av_dFF_combined = cat(4, av_dFF_combined, dFF);
        end

        % Clear variables for memory efficiency
        clear frames sframes dFF;
    end

    % % Display the resulting combined dF/F as a montage
    % figure;
    % montage(av_dFF_combined, 'DisplayRange', []);
    % colormap(jet);
    % colorbar;
    % title('Combined dF/F');

end
