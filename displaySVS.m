function displaySVS(filename)
    % displaySVS - Reads and displays a .svs file in MATLAB.
    %
    % Syntax:
    %   displaySVS(filename)
    %
    % Inputs:
    %   filename - String, the path to the .svs file.
    %
    % This function reads a .svs image file and displays the base layer
    % (highest resolution) of the image.

    % Check if the file exists
    if ~isfile(filename)
        error('File not found: %s', filename);
    end

    try
        % Read the .svs image
        svsImage = imread(filename);
        
        % Display the image
        figure;
        imshow(svsImage, []);
        title(['Displaying: ', filename], 'Interpreter', 'none');
    catch ME
        % Handle potential errors gracefully
        switch ME.identifier
            case 'MATLAB:imagesci:imread:unsupportedFormat'
                error('The file format is not supported by imread.');
            otherwise
                rethrow(ME);
        end
    end
end
