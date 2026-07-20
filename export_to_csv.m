function export_to_csv(vector, filename)
    % Ensure the input is a 1xN vector
    if ~isvector(vector)
        error('Input must be a 1xN vector.');
    end

    % Convert to column vector (CSV format is typically column-oriented)
    vector = vector(:);

    % Write to CSV file
    writematrix(vector, filename);

    fprintf('Vector successfully exported to %s\n', filename);
end

% % Example usage:
% data = rand(1, 10);  % Example 1xN vector
% export_to_csv(data, 'output.csv');
