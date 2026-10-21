function [I_crop_orig, I_crop_aligned, embeddings_aligned, sy, sx, angle_deg, I_true_raw, geom] = preprocess_OCT(folderPath, fileName, MODEL, isLeftEye)
    if nargin < 4, isLeftEye = false; end
    fullImagePath = fullfile(folderPath, fileName);
    I_raw = imread(fullImagePath);
    
    if size(I_raw, 3) == 3, I = rgb2gray(I_raw); else, I = I_raw; end
    
    if isLeftEye
        I = flip(I, 2);
        disp('Flipped OS (Left Eye) image horizontally.');
    end
    
    % SAVE THE TRULY RAW PIXELS BEFORE ANY RESIZING!
    I_true_raw = double(I); 
    
    target_sy = 992; target_sx = 1536;
    [current_sy, current_sx] = size(I);
    
    % Store geometry so we can reverse the stretch later
    geom = struct('orig_sy', current_sy, 'orig_sx', current_sx, 'target_sy', target_sy, 'target_sx', target_sx);
    
    if current_sx ~= target_sx || current_sy ~= target_sy
        disp(['Stretched image detected. Resizing to ', num2str(target_sx), 'x', num2str(target_sy)]);
        I = imresize(I, [target_sy, target_sx]); 
    end
    I = double(I);
    
    H = 15; Im = medfilt2(I, [H H]); s2 = size(I, 2); ILM_rough = zeros(s2, 1);
    for ii = 1 : s2
        dIm = abs(diff(Im(:, ii))); ind = find(dIm > mean(dIm) + 3*std(dIm));
        if ~isempty(ind), ILM_rough(ii) = ind(1); else, ILM_rough(ii) = NaN; end
    end
    
    x = 1:s2; valid = ~isnan(ILM_rough); p = polyfit(x(valid), ILM_rough(valid)', 1);
    angle_deg = atand(p(1));
    
    I_orig = I;
    I_aligned = imrotate(I, angle_deg, 'bicubic', 'crop');
    
    [sy, sx] = size(I_aligned);
    Margin = round((sx*(1-6/9))/2);
    geom.Margin = Margin; % Store horizontal crop margin
    
    I_orig    = I_orig(:, Margin + 1 : sx - Margin);
    I_aligned = I_aligned(:, Margin + 1 : sx - Margin);
    [sy, sx] = size(I_aligned);
    
    T = multithresh(I_aligned, 3); Labels = imquantize(I_aligned, T);
    BW = zeros(size(I_aligned)); ind = Labels==3 | Labels==4; BW(ind) = 1;
    BW = imopen(imfill(BW,'holes'), strel('disk', 3)); 
    
    [~, Y] = meshgrid(1:sx, 1:sy); Y_min = min(Y(BW==1)); Y_max = max(Y(BW==1));
    crop_top = max(1, Y_min - 10);
    geom.crop_top = crop_top; % Store vertical crop boundaries
    geom.Y_max = Y_max;
    
    I_crop_aligned = I_aligned(crop_top:Y_max, :);
    I_crop_orig    = I_orig(crop_top:Y_max, :);
    [sy, sx] = size(I_crop_aligned);
    
    embeddings_aligned = extractEmbeddings(MODEL, I_crop_aligned);
end