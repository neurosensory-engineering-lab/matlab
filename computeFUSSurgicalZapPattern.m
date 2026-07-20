function [Optimal_Zap_Pattern, Candidate_Grid, Final_Gain_Forecast] = computeFUSSurgicalZapPattern(real_map, pc_percentile_bins, empirical_gain_vector, empirical_distance_microns, anisotropy_weight, pixel_pitch_um, target_gain_factor, effect_width_um)
% computeFUSSurgicalZapPattern - Single-Spot Point-Constrained Gain Targeting Suite
%
% PURPOSE:
%   Determines the optimal stereotactic coordinate(s) for a Focused Ultrasound (FUS) 
%   sonication spot to achieve a localized, user-defined target gain factor precisely 
%   at a designated tissue coordinate. This engine accounts for space-variant 
%   anisotropic tissue stretching and gradient path distortions by simulating forward 
%   projections from every point across the full Field of View (FOV).
%
% ALGORITHM METHODOLOGY & FIELD OF VIEW CONSTRAINTS:
%   Instead of applying global image deconvolution—which is highly sensitive to 
%   image boundaries and introduces severe off-target collateral suppression artifacts 
%   when the acoustic footprint's radius spans a large fraction of the FOV—this engine 
%   redefines the task as an elegant, point-constrained optimization problem. It maps the 
%   absolute sensitivity of a single arbitrary tissue element to every possible beam 
%   coordinate, uncovering a "Safe Solution Arc" of degenerate, equivalent treatment coordinates.
%
% ARBITRARY TARGET ADAPTABILITY NOTE:
%   By default, this script automatically extracts and targets the Intensity-Weighted 
%   Center of Mass (COM) of the top 10% highest functional cortical intensities (PC1). 
%   However, the architecture is fully modular; users can easily bypass the automated 
%   Section 2 COM extraction and manually assign 'x_com_int' and 'y_com_int' to any 
%   arbitrary, user-defined stereotactic point of interest within the matrix.
%
% INPUTS:
%   real_map                 - 2D matrix representing the raw cortical intensity/functional map
%   pc_percentile_bins       - Placeholder array for backwards compatibility (can be passed as [])
%   empirical_gain_vector    - Vector of experimentally observed gain values
%   empirical_distance_microns - Vector of corresponding calibration distances from focal center (um)
%   anisotropy_weight        - Scalar weight regulating the impact of local tissue gradients [0-1]
%   pixel_pitch_um           - Spatial calibration factor converting pixels to micrometers (um/px)
%   target_gain_factor       - Desired gain value to force at the targeted point of interest
%   effect_width_um          - Full-width characteristic scale of the sonication profile (um)
%
% OUTPUTS:
%   Optimal_Zap_Pattern      - Vector of weights corresponding to chosen treatment sites
%   Candidate_Grid           - [N x 2] Matrix containing the full set of optimal coordinates [X, Y]
%   Final_Gain_Forecast      - 2D matrix showing the simulated forward tissue state for the chosen spot
%
% AUTHORSHIP & RESEARCH LAB USAGE:
%   Optimized for publication and cross-lab sharing. Fully compatible with MATLAB R2016b+.

    %% =========================================================================
    %% 1. SYSTEM INITIALIZATION & TELEMETRY
    %% =========================================================================
    fprintf('\n==================================================\n');
    fprintf('   FUS POINT-CONSTRAINED SCAN SWEEP ENGINE        \n');
    fprintf('==================================================\n');

    % Input arguments validation and defaults handling
    if nargin < 3, error('CRITICAL: Minimum 3 inputs required (real_map, empirical_gain_vector, empirical_distance_microns).'); end
    if nargin < 5 || isempty(anisotropy_weight), anisotropy_weight = 0.8; end
    if nargin < 6 || isempty(pixel_pitch_um), pixel_pitch_um = 1 / 0.3082; end 
    if nargin < 7 || isempty(target_gain_factor), target_gain_factor = 0.90; end
    if nargin < 8 || isempty(effect_width_um), effect_width_um = 1000; end

    % Standardize data types and scale image map to unit range
    real_map = double(real_map);
    real_map_norm = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);
    [rows, cols] = size(real_map_norm);

    %% =========================================================================
    %% 2. TARGET COORDINATE EXTRACTION (Default: PC1 COM / Adaptable to Any Point)
    %% =========================================================================
    % Isolate top 10% high-intensity region to define the functional cortical target
    top_10_thresh = prctile(real_map_norm(:), 90);
    binary_target_zone = real_map_norm >= top_10_thresh;
    [Y_idx, X_idx] = find(binary_target_zone);
    zone_intensities = real_map_norm(binary_target_zone);
    
    % Compute the Intensity-Weighted Center of Mass (COM) as the default objective point
    total_mass = sum(zone_intensities);
    X_com = sum(X_idx .* zone_intensities) / total_mass;
    Y_com = sum(Y_idx .* zone_intensities) / total_mass;
    
    % Cast to discrete pixel coordinates to establish a static sensor element
    % USER-NOTE: To target an arbitrary coordinate instead of the COM, simply override 
    % these variables here (e.g., x_com_int = target_x_pixel; y_com_int = target_y_pixel;)
    x_com_int = round(X_com);
    y_com_int = round(Y_com);
    
    fprintf('[Centroid] Target Sensor Coordinate locked at: X = %d px, Y = %d px\n', x_com_int, y_com_int);

    %% =========================================================================
    %% 3. PHYSICAL 1D PARAMETER REGRESSION (Empirical Calibration)
    %% =========================================================================
    % Sort raw empirical data tracking beam distance profiles
    raw_dist = empirical_distance_microns(:); 
    raw_gain = empirical_gain_vector(:);
    [x_fit, sort_idx] = sort(raw_dist); y_fit = raw_gain(sort_idx);
    x_fit(1) = 0; max_input_dist = max(x_fit);

    % Custom parameterization function for an annular suppression trough:
    % p(1) = Baseline Gain, p(2) = Dip Depth, p(3) = Radial Shift (Peak), p(4) = Shape Factor
    alpha_trough_model = @(p, x) p(1) - abs(p(2)) * ((x ./ max(50, p(3))).^p(4)) .* exp(1 - (x ./ max(50, p(3))).^p(4));
    
    % Unconstrained Nelder-Mead Optimization to calibrate acoustic model parameters
    best_p0 = [max(y_fit), max(y_fit)-min(y_fit), x_fit(find(y_fit==min(y_fit),1)), 1.5];
    opt_options = optimset('MaxFunEvals', 20000, 'MaxIter', 20000, 'Display', 'off');
    optimized_params = fminsearch(@(p) sum((y_fit - alpha_trough_model(p, x_fit)).^2), best_p0, opt_options);
    
    baseline_gain_val = optimized_params(1);
    dip_magnitude = abs(optimized_params(2)); 
    optimal_radius_px = optimized_params(3) / pixel_pitch_um;
    
    fprintf('[Fit 1D] Target Trough Value to hit: %.3f at a distance of %.1f px\n', ...
        baseline_gain_val - dip_magnitude, optimal_radius_px);

    %% =========================================================================
    %% 4. COMPUTE BASELINE ANISOTROPIC TISSUE GRADIENTS
    %% =========================================================================
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    smoothed_reference = imgaussfilt(real_map_norm, 5.0);
    
    % Compute directional spatial derivatives using central differences
    [G_x, G_y] = imgradientxy(smoothed_reference, 'CentralDifference');
    [G_mag, Theta_deg] = imgradient(G_x, G_y);
    Theta = Theta_deg * (pi / 180); % Convert angles to radians

    % Perform non-linear percentile rank normalization on gradient magnitudes
    [~, sort_gradient_idx] = sort(G_mag(:));
    ranks = zeros(size(G_mag)); ranks(sort_gradient_idx) = (1:numel(G_mag)) / numel(G_mag);
    G_mag_rank = reshape(ranks, size(G_mag));
    G_mag_rank(real_map_norm < 0.05) = 0; % Mask out noise outside the tissue boundaries
    active_footprint_mask = real_map_norm > 0.02;

    %% =========================================================================
    %% 5. TOTAL FIELD-OF-VIEW TARGETING SWEEP (Sensitivity Matrix Generation)
    %% =========================================================================
    % Pre-allocate diagnostic structures to map the parameter space
    COM_Gain_Error_Map = inf(rows, cols);
    COM_Simulated_Gain_Map = baseline_gain_val * ones(rows, cols);
    
    % Downsample coordinate space scanning stride to achieve near real-time performance
    stride = 6; 
    sweep_y = 15:stride:(rows-15);
    sweep_x = 15:stride:(cols-15);
    
    fprintf('[Sweeper] Scanning %d full-field candidate focal points...\n', numel(sweep_y)*numel(sweep_x));
    
    % Establish optimized downsampled calculation matrices for speed
    ds_f = 4;
    eval_rows = 1:ds_f:rows; eval_cols = 1:ds_f:cols;
    [X_ev, Y_ev] = meshgrid(eval_cols, eval_rows);
    G_mag_ev = G_mag_rank(eval_rows, eval_cols);
    Theta_ev = Theta(eval_rows, eval_cols);

    % Expose every pixel coordinate to a "What If?" forward projection trial
    for yi = 1:numel(sweep_y)
        cy = sweep_y(yi);
        for xi = 1:numel(sweep_x)
            cx = sweep_x(xi);
            
            % Localized Anisotropic coordinate warping relative to current test origin (cx, cy)
            dX = X_ev - cx; dY = Y_ev - cy;
            phi = atan2(dY, dX);
            dist_warped = sqrt(dX.^2 + dY.^2) .* (1 ./ (1 + anisotropy_weight * G_mag_ev .* (cos(phi - Theta_ev).^2)));
            dist_microns_ev = imgaussfilt(dist_warped, 7.5 / ds_f) * pixel_pitch_um;
            
            % Compute the resulting acoustic negative change profile
            local_change = -abs(dip_magnitude) * ((dist_microns_ev ./ max(50, optimized_params(3))).^optimized_params(4)) .* exp(1 - (dist_microns_ev ./ max(50, optimized_params(3))).^optimized_params(4));
            local_change(dist_microns_ev > max_input_dist) = 0;
            
            % Extract the exact gain value projected directly onto our static target coordinate
            gain_at_com = baseline_gain_val + interp2(X_ev, Y_ev, local_change, x_com_int, y_com_int, 'linear', 0);
            
            % Document state variables relative to target point
            COM_Gain_Error_Map(cy, cx) = abs(gain_at_com - target_gain_factor);
            COM_Simulated_Gain_Map(cy, cx) = gain_at_com;
        end
    end

    %% =========================================================================
    %% 6. ISOLATE SOLUTION SPACE (Extraction of Degenerate Arcs)
    %% =========================================================================
    % Interpolate downsampled grid calculations smoothly back up to full image dimensions
    [X_sparse, Y_sparse] = meshgrid(sweep_x, sweep_y);
    Sparse_Errors = COM_Gain_Error_Map(sweep_y, sweep_x);
    Full_Error_Canvas = interp2(X_sparse, Y_sparse, Sparse_Errors, X_grid, Y_grid, 'linear', inf);
    
    % Identify the absolute minimum error discovered in the search domain
    min_error_found = min(Full_Error_Canvas(:));
    
    % Isolate all coordinates that track within an acceptable threshold of the optimal solution
    error_tolerance = max(0.002, min_error_found * 1.15); 
    solution_mask = Full_Error_Canvas <= error_tolerance;
    solution_mask(~active_footprint_mask) = 0; % Restrict target positions to valid neural tissue
    
    [sol_y, sol_x] = find(solution_mask);
    Candidate_Grid = [sol_x, sol_y];
    
    % Fallback routine if physical boundary conditions completely block target matching
    if isempty(Candidate_Grid)
        fprintf('[Warning] Absolute target unachievable. Defaulting to minimal error location.\n');
        [~, absolute_min_idx] = min(Full_Error_Canvas(:));
        [fallback_y, fallback_x] = ind2sub([rows, cols], absolute_min_idx);
        Candidate_Grid = [fallback_x, fallback_y];
    end
    
    Optimal_Zap_Pattern = ones(size(Candidate_Grid, 1), 1);
    fprintf('[Optimizer] Optimization locked! Found %d equivalent target options.\n', size(Candidate_Grid, 1));
    fprintf('[Optimizer] Minimum achieved difference from target: %.4f\n', min_error_found);
    fprintf('==================================================\n\n');

    %% =========================================================================
    %% 7. SYNTHESIZE PREDICTED SYSTEM FORECAST FOR VISUALIZATION
    %% =========================================================================
    % Extract the first primary member of the optimal solution set to project forward physics
    best_cx = Candidate_Grid(1, 1); best_cy = Candidate_Grid(1, 2);
    
    dX = X_ev - best_cx; dY = Y_ev - best_cy;
    phi = atan2(dY, dX);
    dist_warped = sqrt(dX.^2 + dY.^2) .* (1 ./ (1 + anisotropy_weight * G_mag_ev .* (cos(phi - Theta_ev).^2)));
    dist_microns_ev = imgaussfilt(dist_warped, 7.5 / ds_f) * pixel_pitch_um;
    
    local_change = -abs(dip_magnitude) * ((dist_microns_ev ./ max(50, optimized_params(3))).^optimized_params(4)) .* exp(1 - (dist_microns_ev ./ max(50, optimized_params(3))).^optimized_params(4));
    local_change(dist_microns_ev > max_input_dist) = 0;
    
    Final_Gain_Forecast = baseline_gain_val * ones(rows, cols) + interp2(X_ev, Y_ev, local_change, X_grid, Y_grid, 'linear', 0);
    Final_Gain_Forecast(~active_footprint_mask) = 0;

    %% =========================================================================
    %% 8. REPORT CONSTRAINED ARCHITECTURAL PLOTS (EQUALIZED SPATIAL DIMENSIONS)
    %% =========================================================================
    figSurg = figure('Name', 'Point-Constrained Single-Spot Multi-Solution Analysis', 'NumberTitle', 'off'); clf;
    set(figSurg, 'Color', 'w', 'Position', [10, 200, 1920, 360]);
    
    % Allocate an array to store axes handles for post-render normalization
    ax_handles = zeros(1, 6);
    
    % Panel 1: Empirical 1D Calibration Verification
    ax_handles(1) = subplot(1, 6, 1); 
    x_plot_space = linspace(0, max_input_dist*1.2, 200);
    plot(x_plot_space, alpha_trough_model(optimized_params, x_plot_space), 'b-', 'LineWidth', 2.5); hold on;
    plot(raw_dist, raw_gain, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5); grid on;
    line([0, max_input_dist*1.2], [target_gain_factor, target_gain_factor], 'Color', 'k', 'LineStyle', '--');
    title('1. 1D Target Profile'); xlabel('Distance (\mu m)'); ylabel('Gain');
    
    % Panel 2: Cortical Structure Reference Mapping
    ax_handles(2) = subplot(1, 6, 2); imagesc(real_map); hold on; colormap(gca, 'parula'); axis image; 
    plot(x_com_int, y_com_int, 'rx', 'LineWidth', 3, 'MarkerSize', 12); 
    plot(x_com_int, y_com_int, 'ro', 'LineWidth', 1.5, 'MarkerSize', 14); 
    title('2. Cortical Structure (Target X)');
    
    % Panel 3: Full Field Sensitivity Map of Resulting Gain Delivered to Target Element
    ax_handles(3) = subplot(1, 6, 3);
    Sparse_Gains = COM_Simulated_Gain_Map(sweep_y, sweep_x);
    Full_Gain_Map = interp2(X_sparse, Y_sparse, Sparse_Gains, X_grid, Y_grid, 'linear', baseline_gain_val);
    imagesc(Full_Gain_Map); colormap(gca, 'jet'); axis image; hold on;
    plot(x_com_int, y_com_int, 'kx', 'LineWidth', 3, 'MarkerSize', 12); % Objective coordinate crosshair
    colorbar('Location', 'eastoutside');
    title('3. Resulting Gain at Target');
    
    % Panel 4: Absolute Error Map at Target Coordinate
    ax_handles(4) = subplot(1, 6, 4); imagesc(Full_Error_Canvas, [0, 0.15]); colormap(gca, 'hot'); axis image; hold on;
    plot(x_com_int, y_com_int, 'cx', 'LineWidth', 3, 'MarkerSize', 12); % Objective coordinate crosshair
    colorbar('Location', 'eastoutside');
    title('4. Target Absolute Error Map');
    
    % Panel 5: Safe Solution Arc Isolate Plot (Green Degenerate Arcs)
    ax_handles(5) = subplot(1, 6, 5); imagesc(real_map_norm); hold on; colormap(gca, 'bone'); axis image;
    scatter(Candidate_Grid(:,1), Candidate_Grid(:,2), 8, 'g', 'filled'); % Green safety tracks
    plot(best_cx, best_cy, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8); % Chosen execution coordinate
    plot(x_com_int, y_com_int, 'cx', 'LineWidth', 3, 'MarkerSize', 12); % Objective coordinate crosshair
    line([best_cx, x_com_int], [best_cy, y_com_int], 'Color', 'r', 'LineStyle', ':', 'LineWidth', 2); % Trajectory vector line
    title('5. Safe Solution Arc');
    
    % Panel 6: Forward Physics Model Verification Result
    ax_handles(6) = subplot(1, 6, 6); imagesc(Final_Gain_Forecast, [target_gain_factor*0.85, baseline_gain_val*1.02]); hold on; colormap(gca, 'parula'); axis image;
    contour(Final_Gain_Forecast, [target_gain_factor target_gain_factor], 'LineColor', [0.2 0.2 0.2], 'LineWidth', 1.5);
    plot(x_com_int, y_com_int, 'kx', 'LineWidth', 3, 'MarkerSize', 12); % Objective crosshair locked in ditch center
    plot(best_cx, best_cy, 'ro', 'LineWidth', 2, 'MarkerSize', 8); % Sonicated center point marker
    colorbar('Location', 'eastoutside');
    title('6. Selected Spot Result');

    %% =========================================================================
    %% POST-RENDER AXES EQUALIZATION LOOP (FOR ENFORCING PERFECTION IN LAYOUT)
    %% =========================================================================
    drawnow; % Force MATLAB to render elements and lock baseline geometries
    
    % Define rigorous, normalized layout parameters
    start_x  = 0.04;  % Leftmost margin edge
    width_x  = 0.125; % Strictly controlled fixed axis width
    height_y = 0.72;  % Fixed vertical axis height
    start_y  = 0.16;  % Centered vertical placement baseline
    gap_x    = 0.035; % Step interval spacer between adjacent plots
    
    for idx = 1:6
        % Calculate identical absolute bounds for every single subplot panel
        target_pos = [start_x + (idx-1)*(width_x + gap_x), start_y, width_x, height_y];
        set(ax_handles(idx), 'Position', target_pos);
    end
end