function convertSVStoTIFF_Tiled(inputFile, outputFile, tileSize)
    % convertSVStoTIFF_Tiled - Converts an .svs file to a tiled .tiff file.
    %
    % Syntax:
    %   convertSVStoTIFF_Tiled(inputFile, outputFile, tileSize)
    %
    % Inputs:
    %   inputFile  - String, path to the input .svs file.
    %   outputFile - String, path to save the output .tiff file.
    %   tileSize   - Integer, size of each tile (e.g., 1024 for 1024x1024 tiles).
    %
    % This function processes the .svs file in blocks to handle large images.
    
    % Validate inputs
    if ~isfile(inputFile)
        error('Input file not found: %s', inputFile);
    end
    
    if nargin < 3
        tileSize = 1024; % Default tile size
    end

    % Read image size
    info = imfinfo(inputFile);
    imgWidth = info.Width;
    imgHeight = info.Height;

    % Open a Tiff object for writing
    tiffObj = Tiff(outputFile, 'w');
    
    % Define TIFF tags for tiled TIFF
    tiffTags = struct( ...
        'ImageLength', imgHeight, ...
        'ImageWidth', imgWidth, ...
        'Photometric', Tiff.Photometric.RGB, ...
        'BitsPerSample', 8, ...
        'SamplesPerPixel', 3, ...
        'PlanarConfiguration', Tiff.PlanarConfiguration.Chunky, ...
        'TileWidth', tileSize, ...
        'TileLength', tileSize, ...
        'Compression', Tiff.Compression.None);
    
    % Write TIFF header tags
    fields = fieldnames(tiffTags);
    for k = 1:numel(fields)
        tiffObj.setTag(fields{k}, tiffTags.(fields{k}));
    end
    
    % Process image in tiles
    numTilesX = ceil(imgWidth / tileSize);
    numTilesY = ceil(imgHeight / tileSize);
    tileIndex = 1; % Initialize tile index
    
    for tileY = 1:numTilesY
        for tileX = 1:numTilesX
            % Define region of interest (ROI)
            xStart = (tileX - 1) * tileSize + 1;
            xEnd = min(tileX * tileSize, imgWidth);
            yStart = (tileY - 1) * tileSize + 1;
            yEnd = min(tileY * tileSize, imgHeight);
            
            % Read tile
            tile = imread(inputFile, 'PixelRegion', {[yStart, yEnd], [xStart, xEnd]});
            
            % Check tile dimensions and pad if necessary
            tileHeight = size(tile, 1);
            tileWidth = size(tile, 2);
            if tileHeight < tileSize || tileWidth < tileSize
                paddedTile = padarray(tile, [tileSize - tileHeight, tileSize - tileWidth], 0, 'post');
            else
                paddedTile = tile;
            end
            
            % Write tile
            try
                tiffObj.writeEncodedTile(tileIndex, paddedTile);
            catch ME
                warning('Failed to write tile #%d: %s', tileIndex, ME.message);
            end
            
            tileIndex = tileIndex + 1; % Increment tile index
        end
    end
    
    % Close Tiff object
    tiffObj.close();
    fprintf('Successfully converted %s to %s\n', inputFile, outputFile);
end
