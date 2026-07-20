function Final_Gain_Forecast = predictFUSGainMap(real_map, pc_percentile_bins, empirical_gain_vector, empirical_distance_mm, FUS_Dose_Mode, anisotropy_weight, pixel_pitch_um)
% PREDICTFUSGAINMAP Warped 2D Anisotropic Spatial Gain Predictor Engine
%
% Syntax:
%   Final_Gain_Forecast = predictFUSGainMap(real_map, [], empirical_gain_vector, [], FUS_Dose_Mode, anisotropy_weight, pixel_pitch_um)
%
% Inputs:
%   real_map              - 2D double/single matrix of the upscaled PC1 reference anatomy.
%   pc_percentile_bins    - (Leave as [] for Auto-Generation of midpoints [0.95 down to 0.15])
%   empirical_gain_vector - 1D vector containing raw experimental scalar gain values matching the bins
%   empirical_distance_mm - (Leave as [] for Automated Spatial Center-of-Mass Tracking)
%   FUS_Dose_Mode         - String: 'Excitatory' or 'Suppressive'
%   anisotropy_weight     - Gradient scaling parameter. (If left as [], defaults to a sensible 2.0)
%   pixel_pitch_um        - Camera spatial tracking resolution (micrometers per pixel, e.g., 1 / 0.3082)
%
% Outputs:
%   Final_Gain_Forecast   - 2D warped matrix of predicted spatial FUS gain changes

    %% 1. PIPELINE INITIALIZATION & NORMALIZATION
    fprintf('\n[Predictive Engine] Initializing Anisotropic Propagation Pipeline...\n');
    
    % Min-max normalization of the input reference anatomy to lock it into a 0-1 boundary
    real_map = double(real_map);
    real_map_norm = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);
    [rows, cols] = size(real_map_norm);
    
    % Convert camera pixel tracking step directly to millimeters
    spatial_scale_px = pixel_pitch_um / 1000; 
    
    % Handle Optional Anisotropy Weight baseline fallback
    if nargin < 6 || isempty(anisotropy_weight)
        anisotropy_weight = 2.0; % Sensible a priori default choice for smooth spatial boundaries
    end
    
    % Hardcoded quadratic order for smooth spatial parabolic decay fitting
    poly_order = 2; 

    %% 2. AUTOMATED CONFIGURATION & PHYSICAL GEOMETRY SOLVER
    % Define the 9 strict spatial brackets matching your lookup/stats pipeline
    percentile_bins = [0.9, 1.0; 
                       0.8, 0.9; 
                       0.7, 0.8; 
                       0.6, 0.7; 
                       0.5, 0.6;
                       0.4, 0.5;
                       0.3, 0.4;
                       0.2, 0.3;
                       0.1, 0.2]; 
    num_brackets = size(percentile_bins, 1);

    % Auto-populate pc_percentile_bins center values if left empty
    if isempty(pc_percentile_bins)
        pc_percentile_bins = mean(percentile_bins, 2)'; % Results in: [0.95, 0.85, ..., 0.15]
    end

    %% 3. CENTROID DEVIATION & IMAGE TENSOR GRADIENTS
    % Target origin estimation using top 10% Center of Mass intensity weighting
    top_10_thresh = prctile(real_map_norm(:), 90);
    binary_target_zone = real_map_norm >= top_10_thresh;
    
    [Y_idx, X_idx] = find(binary_target_zone);
    zone_intensities = real_map_norm(binary_target_zone);
    total_mass = sum(zone_intensities);
    
    X_com = sum(X_idx .* zone_intensities) / total_mass;
    Y_com = sum(Y_idx .* zone_intensities) / total_mass;

    % Auto-calculate empirical_distance_mm using the input map centroid if left empty
    if isempty(empirical_distance_mm)
        fprintf('[Predictive Engine] Auto-solving physical distance vector from map spatial brackets...\n');
        empirical_distance_mm = nan(1, num_brackets);
        
        for p = 1:num_brackets
            lower_bound = percentile_bins(p, 1);
            solid_mask = real_map_norm > lower_bound;
            
            perim_mask = bwperim(solid_mask);
            [y_perim, x_perim] = find(perim_mask);
            
            if isempty(x_perim)
                continue; 
            end
            
            % Euclidean distance (in mm) from centroid focus to the boundary perimeter
            dists_px = sqrt((x_perim - X_com).^2 + (y_perim - Y_com).^2);
            empirical_distance_mm(p) = mean(dists_px) * spatial_scale_px;
        end
        
        % Extrapolate any missing trailing background edges safely
        if any(isnan(empirical_distance_mm))
            v_idx = ~isnan(empirical_distance_mm);
            empirical_distance_mm = interp1(find(v_idx), empirical_distance_mm(v_idx), 1:num_brackets, 'linear', 'extrap');
        end
        fprintf('  -> Auto-derived Distances (mm): '); disp(empirical_distance_mm);
    end

    %% 4. AUTOMATED POLYNOMIAL FIT PROCESSING
    % Sort vectors by distance ascending to ensure strict curve fitting behavior
    [x_fit, sort_idx] = sort(empirical_distance_mm);
    y_fit = empirical_gain_vector(sort_idx);
    
    gain_poly_coefficients = polyfit(x_fit, y_fit, poly_order);
    max_calibrated_distance = max(x_fit);
    
    % Compute horizontal/vertical spatial directional tensors
    [G_x, G_y] = imgradientxy(real_map_norm, 'CentralDifference');
    [G_mag, Theta_deg] = imgradient(G_x, G_y);
    Theta = Theta_deg * (pi / 180);

    %% 5. ANISOTROPIC PROPAGATION MECHANISM (METRIC TENSOR WARPING)
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    dX = X_grid - X_com;
    dY = Y_grid - Y_com;
    d_euclidean = sqrt(dX.^2 + dY.^2);
    
    phi_displacement = atan2(dY, dX);
    delta_angle = phi_displacement - Theta;
    
    % Scale structural gradients to preserve user knob intuition
    G_mag_norm = G_mag / (max(G_mag(:)) + eps);
    
    % Direct Distance Warping Tensor: Compresses effective distance along high-gradient boundaries
    distance_warping_tensor = 1 ./ (1 + anisotropy_weight * G_mag_norm .* (cos(delta_angle).^2));
    d_warped_effective = (d_euclidean * spatial_scale_px) .* distance_warping_tensor;
    
    % Project fitted polynomial model over the deformed coordinates
    Predicted_Gain_Map = polyval(gain_poly_coefficients, d_warped_effective);
    
    %% 6. BOUNDARY SAFEGUARDS & GATING
    % Zero out any pixel shooting past our experimental calibration curve window
    out_of_bounds_mask = d_warped_effective > max_calibrated_distance;
    Predicted_Gain_Map(out_of_bounds_mask) = 0;
    
    % Gate outer edges using the actual underlying map footprint cutoff
    active_footprint_mask = real_map_norm > 0.05;
    Predicted_Gain_Map = Predicted_Gain_Map .* active_footprint_mask;
    Predicted_Gain_Map(Predicted_Gain_Map < 0) = 0;

    %% 7. DOSE SCALING & BIAS-FREE DIVERGENT COLOR INTERPOLATION
    cmap_resolution = 256;
    white_to_color = [linspace(1, 1, cmap_resolution/2)', linspace(1, 0, cmap_resolution/2)', linspace(1, 0, cmap_resolution/2)'];
    
    if strcmpi(FUS_Dose_Mode, 'suppressive')
        Dose_Scaler = -1.0;
        custom_cmap = white_to_color(:, [2,3,1]); % Custom White-to-Blue mapping sequence
        display_title = 'Predicted Gain Footprint: SUPPRESSIVE (-1 * \Delta)';
    else
        Dose_Scaler = 1.0;
        custom_cmap = white_to_color;             % Custom White-to-Red mapping sequence
        display_title = 'Predicted Gain Footprint: EXCITATORY (+1 * \Delta)';
    end
    Final_Gain_Forecast = Predicted_Gain_Map * Dose_Scaler;

    %% 8. PRODUCTION VISUALIZATION SUITE
    figSim = figure('Name', 'Surgical Planning System Output', 'NumberTitle', 'off'); clf;
    set(figSim, 'Color', 'w', 'Position', [50, 50, 1600, 850]);
    
    % --- SUBPLOT 1: DIAGNOSTIC INPUT POLYNOMIAL CHECK ---
    subplot(2, 3, 1);
    plot(empirical_distance_mm, empirical_gain_vector, 'ro', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', 'Empirical Points'); hold on;
    x_plot_vec = linspace(min(x_fit), max(x_fit), 200);
    y_plot_vec = polyval(gain_poly_coefficients, x_plot_vec);
    plot(x_plot_vec, y_plot_vec, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Quadratic Fit Model');
    grid on; set(gca, 'LineWidth', 1.2, 'FontSize', 11);
    xlabel('Distance from Target Focus Center (mm)'); ylabel('Empirical Gain Delta');
    title('1. Curve-Fit Analysis Engine'); legend('Location', 'best');
    
    % --- SUBPLOT 2: DISTANCE TRANSLATION LOOKUP ---
    subplot(2, 3, 4);
    plot(pc_percentile_bins, empirical_distance_mm, 'm-s', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    grid on; set(gca, 'LineWidth', 1.2, 'FontSize', 11);
    xlabel('PC1 Percentile Bin (%)'); ylabel('Mean Measured Distance (mm)');
    title('2. Spatial Mapping Calibration Vector');
    
    % --- SUBPLOT 3: ORIGINAL TARGETED MAP INPUT CONTEXT ---
    subplot(2, 3, [2, 5]);
    imagesc(real_map); hold on;
    colormap(gca, 'gray'); colorbar; axis image;
    contour(binary_target_zone, [0.5, 0.5], 'Color', [0, 0.7, 1], 'LineWidth', 2);
    plot(X_com, Y_com, 'rx', 'MarkerSize', 14, 'LineWidth', 3);
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X Vector (px)'); ylabel('Cortical Y Vector (px)');
    title('3. Input Reference Topography Map (PC1)');
    
    % --- SUBPLOT 4: FINAL WARPED BIOLOGICAL FOOTPRINT FORECAST ---
    subplot(2, 3, [3, 6]);
    if Dose_Scaler < 0
        imagesc(Final_Gain_Forecast, [min(Final_Gain_Forecast(:))-eps, 0]);
    else
        imagesc(Final_Gain_Forecast, [0, max(Final_Gain_Forecast(:))+eps]);
    end
    hold on; colormap(gca, custom_cmap); colorbar; axis image;
    contour(Final_Gain_Forecast, 8, 'LineColor', [0.2, 0.2, 0.2, 0.4], 'LineWidth', 1.1);
    plot(X_com, Y_com, 'kx', 'MarkerSize', 14, 'LineWidth', 3);
    set(gca, 'LineWidth', 1.2, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Cortical X Vector (px)'); ylabel('Cortical Y Vector (px)');
    title(['4. ' display_title]);
    
    fprintf('[Predictive Engine] Map generation completed successfully.\n');
end