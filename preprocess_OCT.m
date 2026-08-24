function [I_crop_orig, I_crop_aligned, embeddings_aligned, sy, sx, angle_deg] = preprocess_OCT(folderPath, fileName, MODEL)
    fullImagePath = fullfile(folderPath, fileName);
    I = rgb2gray(imread(fullImagePath)); % this is a 9mm scan 

    % Standardize Image Size
    target_sy = 992;
    target_sx = 1536;
    [current_sy, current_sx] = size(I);
    
    % If the image doesn't match the standard, resize it
    if current_sx ~= target_sx || current_sy ~= target_sy
        disp(['Stretched image detected. Resizing from ', num2str(current_sx), 'x', num2str(current_sy), ...
              ' to ', num2str(target_sx), 'x', num2str(target_sy)]);
        I = imresize(I, [target_sy, target_sx]); 
    end

    I = double(I);
    
    % Find estimate of ILM
    H = 15;
    Im = medfilt2(I, [H H]);
    s2 = size(I, 2);
    ILM_rough = zeros(s2, 1);
    
    for ii = 1 : s2
        dIm = abs(diff(Im(:, ii)));
        ind = find(dIm > mean(dIm) + 3*std(dIm));
        if ~isempty(ind)
            ILM_rough(ii) = ind(1);
        else
            ILM_rough(ii) = NaN;
        end
    end
    
    % Calculate the tilt angle
    x = 1:s2;
    valid = ~isnan(ILM_rough);
    p = polyfit(x(valid), ILM_rough(valid)', 1);
    angle_deg = atand(p(1));
    disp(['Pre-crop tilt detected: ', num2str(angle_deg), ' degrees.']);
    
    % Rotate the image to flatten it
    I_orig = I;
    I_aligned = imrotate(I, angle_deg, 'bicubic', 'crop');
    
    % crop horizontally to a central 6mm scan 
    [sy, sx] = size(I_aligned);
    Margin = round((sx*(1-6/9))/2);
    
    I_orig    = I_orig(:, Margin + 1 : sx - Margin);
    I_aligned = I_aligned(:, Margin + 1 : sx - Margin);
    
    % Update sx to the new 6mm width
    [sy, sx] = size(I_aligned);

    % Vertical crop before SAM
    T = multithresh(I_aligned, 3);
    Labels = imquantize(I_aligned, T);
    BW = zeros(size(I_aligned));
    ind  = Labels==3 | Labels==4;
    BW(ind) = 1;
    BW = imopen(imfill(BW,'holes'),strel('disk',3)); 
    
    [~,Y] = meshgrid(1:sx, 1:sy);
    Y_min = min(Y(BW==1));
    Y_max = max(Y(BW==1));
    crop_top = max(1, Y_min-10);
    
    % Apply vertical crop
    I_crop_aligned = I_aligned(crop_top:Y_max, :);
    I_crop_orig    = I_orig(crop_top:Y_max, :);
    [sy, sx] = size(I_crop_aligned);
    
    embeddings_aligned = extractEmbeddings(MODEL, I_crop_aligned);
end