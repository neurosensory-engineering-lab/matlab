function exportLevel0FromSVS(inputFile, outputFile)
    % Export only the Level 0 (full-resolution) image from an SVS file to a BigTIFF file.
    %
    % Parameters:
    %   inputFile (string): Path to the .svs file
    %   outputFile (string): Path to the output .bigtiff file

    % Validate input and output paths
    if ~isfile(inputFile)
        error('The input file does not exist.');
    end
    
    % Read Level 0 full-resolution image
    try
        % Load information about the SVS file
        info = imfinfo(inputFile);
        
        % Ensure the file contains at least one image (Level 0)
        if isempty(info)
            error('No image data found in the SVS file.');
        end
        
        % Access Level 0 image (first image in the file)
        % Level 0 is usually the first in the pyramid, as per SVS structure
        level0Image = imread(inputFile, 'Index', 1);
        
        % Create a BigTIFF file (using the Tiff class)
        t = Tiff(outputFile, 'w');
        
        % Set TIFF tags (ensure BigTIFF compatibility)
        tagstruct.ImageLength = size(level0Image, 1);
        tagstruct.ImageWidth = size(level0Image, 2);
        tagstruct.SampleFormat = 1; % 1 corresponds to Unsigned Integer (UInt8)
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 8; % Adjust if needed based on your image format
        tagstruct.SamplesPerPixel = 1; % Set to 3 for RGB images
        tagstruct.Compression = Tiff.Compression.None; % Adjust compression type if necessary
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        
        % Set the tag structure
        t.setTag(tagstruct);
        
        % Write the image data to the BigTIFF file
        t.write(level0Image);
        
        % Close the BigTIFF file
        t.close();
        
        fprintf('Level 0 image successfully exported to BigTIFF: %s\n', outputFile);
        
    catch ME
        error('Error processing SVS file: %s', ME.message);
    end
end
