function normalized_vector = min_max_normalize(input_vector)
    % Ensure the input is a column vector
    input_vector = input_vector(:);
    
    % Compute the min and max
    min_val = min(input_vector);
    max_val = max(input_vector);
    
    % Apply min-max normalization
    normalized_vector = (input_vector - min_val) / (max_val - min_val);
end

% Example usage:
% vec = [3, 5, 8, 2, 10, 7];  % Example input vector
% normalized_vec = min_max_normalize(vec);
% disp(normalized_vec);
