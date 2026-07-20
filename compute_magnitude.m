function magnitude_trace = compute_magnitude(accel_data)
    % Ensure the input is an N-by-3 matrix
    if size(accel_data, 2) ~= 3
        error('Input must be an N-by-3 matrix representing X, Y, Z acceleration data.');
    end
    
    % Compute the magnitude for each row
    magnitude_trace = sqrt(sum(accel_data.^2, 2));
end

% % Example usage:
% accel_data = [0.5, 0.3, 0.7; 
%               0.1, 0.1, 0.2; 
%               0.4, 0.4, 0.4];  % Example N-by-3 accelerometer data
% 
% magnitude = compute_magnitude(accel_data);
% disp(magnitude);
