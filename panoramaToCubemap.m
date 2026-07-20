function panoramaToCubemap(panoramaFile, faceSize, outputDir)
    % panoramaToCubemap Converts a 360° panorama image into a cubemap in cross layout
    %
    % Inputs:
    %   panoramaFile - Path to the panoramic image file (equirectangular)
    %   faceSize - Resolution of each cubemap face (e.g., 512 for 512x512)
    %   outputDir - Directory to save the cubemap faces as a cross layout image
    %
    % Output:
    %   Generates a single image with a cross layout of the cubemap faces

    % Load the panorama image
    panorama = imread(panoramaFile);
    [height, width, channels] = size(panorama);

    % Check if the image has an alpha channel, and discard it if so
    if channels == 4
        panorama = panorama(:, :, 1:3);  % Keep only RGB channels
    end

    % Log panorama dimensions
    fprintf('Original panorama size: %d x %d\n', width, height);

    % Check and correct aspect ratio (should be close to 2:1)
    if width / height ~= 2
        fprintf('Panorama has incorrect aspect ratio: %.6f. Attempting fix.\n', width / height);
        
        if height > width
            % If the height is greater than the width, rotate the image
            panorama = imrotate(panorama, 90);  % Rotate 90 degrees
            [height, width, ~] = size(panorama);  % Update dimensions after rotation
            fprintf('Rotated image to correct aspect ratio: %d x %d\n', width, height);
        elseif width / height > 2
            % If the aspect ratio is too wide (more than 2:1), crop it to 2:1
            panorama = panorama(:, 1:round(height * 2), :);  % Crop the right side
            [height, width, ~] = size(panorama);  % Update dimensions after cropping
            fprintf('Cropped image to correct aspect ratio: %d x %d\n', width, height);
        end
    end

    % Resize the panorama to the expected dimensions (1368x684)
    if width ~= 1368 || height ~= 684
        panorama = imresize(panorama, [684, 1368]);
        [height, width, ~] = size(panorama);
        fprintf('Resized image to: %dx%d\n', width, height);
    end

    % Debugging: Output panorama size after resizing
    fprintf('Panorama resized to: %dx%d\n', width, height);

    % Allocate space for the final cross layout image (RGB, 3 channels)
    layoutWidth = 4 * faceSize;  % 4 faces horizontally
    layoutHeight = 3 * faceSize; % 3 faces vertically
    cubemapImage = uint8(zeros(layoutHeight, layoutWidth, 3));  % 3 for RGB channels

    % Define face positions in the cross layout (adjusted)
    facePositions = {
        'left',   [1, 1, faceSize, faceSize];                  % Left face
        'front',  [1, faceSize+1, faceSize, faceSize];         % Front face
        'right',  [1, 2*faceSize+1, faceSize, faceSize];       % Right face
        'back',   [1, 3*faceSize+1, faceSize, faceSize];       % Back face
        'top',    [faceSize+1, 1, faceSize, faceSize];          % Top face
        'bottom', [faceSize+1, faceSize+1, faceSize, faceSize]; % Bottom face
    };

    % Loop over each face in the cross layout
    for i = 1:6
        faceName = facePositions{i, 1};
        pos = facePositions{i, 2};

        % Debugging: Output the face position and name
        fprintf('\nProcessing face: %s\n', faceName);
        fprintf('Face Position: [%d, %d, %d, %d]\n', pos(1), pos(2), pos(3), pos(4));

        % Calculate the corresponding panorama indices for each face
        switch faceName
            case 'left'
                fprintf('Extracting left face...\n');
                % Left face: Extract the leftmost part of the image
                faceImage = panorama(:, 1:faceSize, :);

            case 'front'
                fprintf('Extracting front face...\n');
                % Front face: Extract the middle part of the image
                faceImage = panorama(:, faceSize+1:2*faceSize, :);

            case 'right'
                fprintf('Extracting right face...\n');
                % Right face: Extract the right part of the image
                % Ensure indices don't exceed panorama width
                endIndex = min(3 * faceSize, width);  % Ensure the end index doesn't exceed image width
                faceImage = panorama(:, 2*faceSize+1:endIndex, :);
                fprintf('Right face extracted with size: %d x %d\n', size(faceImage, 1), size(faceImage, 2));

            case 'back'
                fprintf('Extracting back face...\n');
                % Back face: Extract the right-most part of the image
                % Add debugging to see indices
                startIndex = 3 * faceSize + 1;
                endIndex = min(4 * faceSize, width); % Adjust to ensure we don't exceed width
                fprintf('Back face startIndex: %d, endIndex: %d\n', startIndex, endIndex);

                % Check if the indices exceed panorama dimensions
                if startIndex <= width && endIndex <= width
                    faceImage = panorama(:, startIndex:endIndex, :);
                    fprintf('Back face extracted with size: %d x %d\n', size(faceImage, 1), size(faceImage, 2));
                else
                    fprintf('Error: Back face indices exceed panorama width! Start: %d, End: %d\n', startIndex, endIndex);
                    continue;
                end

            case 'top'
                fprintf('Extracting top face...\n');
                % Top face: Extract the upper part of the image (ensuring it fits the width)
                faceImage = panorama(1:faceSize, 1:faceSize, :);

            case 'bottom'
                fprintf('Extracting bottom face...\n');
                % Bottom face: Extract the lower part of the image
                % Ensure we don't exceed the height of the panorama
                faceImage = panorama(faceSize+1:min(2*faceSize, height), 1:faceSize, :);
        end

        % Debugging: Output extracted face size
        [fh, fw, ~] = size(faceImage);
        fprintf('%s face extracted with size: %d x %d\n', faceName, fh, fw);

        % Ensure the face image has the correct dimensions
        if fh ~= faceSize || fw ~= faceSize
            fprintf('%s face resized from %d x %d to %d x %d\n', faceName, fh, fw, faceSize, faceSize);
            faceImage = imresize(faceImage, [faceSize, faceSize]);  % Resize if necessary
        end

        % Ensure the face image is 3 channels (RGB)
        if size(faceImage, 3) == 4
            faceImage = faceImage(:, :, 1:3);  % Discard alpha channel if present
        end

        % Check if the placement is within cubemap boundaries before assignment
        cubemapHeight = size(cubemapImage, 1);
        cubemapWidth = size(cubemapImage, 2);
        if pos(1)+pos(3)-1 > cubemapHeight || pos(2)+pos(4)-1 > cubemapWidth
            error('Face position exceeds cubemap boundaries! Position: [%d, %d], Size: [%d, %d]', pos(1), pos(2), pos(3), pos(4));
        end

        % Place the extracted face into the cubemap layout
        cubemapImage(pos(1):pos(1)+faceSize-1, pos(2):pos(2)+faceSize-1, :) = faceImage;

        % Superimpose the face label onto the face
        labelPosition = [round(pos(1) + faceSize / 2), round(pos(2) + faceSize / 2)];
        cubemapImage = insertText(cubemapImage, labelPosition, faceName, 'FontSize', 24, 'BoxColor', 'black', 'TextColor', 'white');
    end

    % Save the resulting cubemap
    imwrite(cubemapImage, fullfile(outputDir, 'cubemap_cross_layout_with_labels.png'));
    fprintf('Cubemap saved to: %s\n', fullfile(outputDir, 'cubemap_cross_layout_with_labels.png'));
end
