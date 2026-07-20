function [alpha, summary] = getAlphaFromPC1(PC1_image)
% ========================================================================
% Purpose: Extract the optimal anisotropy weight (alpha) purely from a 
%          2D PC1 image matrix using its intrinsic geometry and gradients.
%
% Input:   PC1_image - A 2D numerical matrix of your experimental data
%
% Outputs: alpha     - The data-driven anisotropy weight (scalar)
%          summary   - A struct containing the underlying geometric metrics
% ========================================================================

    % 1. Normalize image between 0 and 1 to standardize gradient calculations
    real_map = double(PC1_image);
    real_map = (real_map - min(real_map(:))) / (max(real_map(:)) - min(real_map(:)) + eps);

    % 2. Compute spatial derivatives using standard pixel spacing
    [G_x, G_y] = imgradientxy(real_map, 'CentralDifference');
    [G_mag, ~] = imgradient(G_x, G_y);

    % 3. Generate a 10th percentile boundary fence to isolate the map shape
    map_boundary_thresh = prctile(real_map(:), 5); 
    binary_map_mask = real_map >= map_boundary_thresh;
    [Y_mask, X_mask] = find(binary_map_mask);

    % 4. Locate Center of Mass (CoM) to act as the coordinate origin
    zone_intensities = real_map(binary_map_mask);
    total_mass = sum(zone_intensities);
    X_com = sum(X_mask .* zone_intensities) / total_mass;
    Y_com = sum(Y_mask .* zone_intensities) / total_mass;

    % 5. Compute Spatial Covariance of the mask coordinates relative to CoM
    spatial_coordinates = [X_mask - X_com, Y_mask - Y_com];
    spatial_covariance = cov(spatial_coordinates);

    % 6. Extract Eigenvalues to define the major and minor axes of the shape
    eigenvalues = eig(spatial_covariance);
    lambda_PC1 = sqrt(max(eigenvalues) / min(eigenvalues));

    % 7. Calculate the baseline mean gradient magnitude along the boundary
    mean_boundary_gradient = mean(G_mag(binary_map_mask));

    % 8. Analytically derive the data-driven Alpha
    alpha = (lambda_PC1 - 1) / (mean_boundary_gradient + eps);

    % 9. Pack auxiliary data into a summary struct for reference
    summary.Target_Center_CoM = [X_com, Y_com];
    summary.Aspect_Ratio = lambda_PC1;
    summary.Mean_Gradient = mean_boundary_gradient;
    summary.Threshold_Used = map_boundary_thresh;

    % 10. Print the final result directly to the command window
    fprintf('>> Analysis Complete. Derived Alpha: %.4f (Aspect Ratio: %.2f:1)\n', alpha, lambda_PC1);
end