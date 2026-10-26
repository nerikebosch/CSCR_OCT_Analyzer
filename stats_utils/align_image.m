function [I_crop_aligned, angle_deg] = align_image(I_crop_orig, Layer_ILM_orig, sx)
    % Fit a straight line to the ILM to find the slope
    x = 1:sx;
    valid = ~isnan(Layer_ILM_orig);
    p = polyfit(x(valid), Layer_ILM_orig(valid)', 1);
    
    % Convert slope to degrees
    slope = p(1);
    angle_deg = atand(slope); 
    
    % Rotate the image to make it flat
    I_crop_aligned = imrotate(I_crop_orig, angle_deg, 'bicubic', 'crop');
    
    % fill the black areas with noise
    
    % Create a mask to track the padded areas.
    mask = ones(size(I_crop_orig));
    rotated_mask = imrotate(mask, angle_deg, 'nearest', 'crop');
    padding_mask = (rotated_mask == 0); 
    
    bg_sample = double(I_crop_orig(1:20, :));
    bg_mean = mean(bg_sample(:), 'omitnan');
    bg_std  = std(bg_sample(:), 'omitnan');
    
    % Generate a matrix of noise based on stats
    synthetic_noise = bg_mean + bg_std * randn(size(I_crop_aligned));
    
    if isinteger(I_crop_orig)
        synthetic_noise = cast(synthetic_noise, class(I_crop_orig));
    end
    
    % Inject the synthetic noise into the padded black corners
    I_crop_aligned(padding_mask) = synthetic_noise(padding_mask);
    
    disp(['Tilt detected: ', num2str(angle_deg), ' degrees.']);
end