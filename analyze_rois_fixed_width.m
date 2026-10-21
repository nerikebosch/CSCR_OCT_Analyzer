function [STATS_Full_fw, STATS_Right_fw, STATS_Left_fw] = analyze_rois_fixed_width(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1, I_true_raw, geom)
    STATS_Full_fw = []; STATS_Right_fw = []; STATS_Left_fw = [];    
    
    % --- FIXED WIDTH PARAMETERS ---
    roi_half_width = 120; % Width of ROI in pixels
    safe_margin = 50;     % Margin away from the exact hole edge
    vert_margin = 2;      % Margin away from horizontal layer boundaries
    
    if is_hole_found
        hole_columns = any(Mask_Hole, 1);
        if any(hole_columns)
            hole_left_edge = find(hole_columns, 1, 'first');
            hole_right_edge = find(hole_columns, 1, 'last');
        else
            hole_left_edge = round(sx / 2) - 10;
            hole_right_edge = round(sx / 2) + 10;
        end
    else
        % Virtual Central Split for healthy eyes
        hole_left_edge = round(sx / 2) - 10;
        hole_right_edge = round(sx / 2) + 10;
    end
    
    %% 5 Left-Side ROIs (Anchored to Hole)
    x_left_end   = max(1, hole_left_edge - safe_margin);
    x_left_start = max(1, x_left_end - roi_half_width + 1);
    
    Mask_ROI_L1 = false(sy, sx); Mask_ROI_L2 = false(sy, sx); Mask_ROI_L3 = false(sy, sx);
    Mask_ROI_L4 = false(sy, sx); Mask_ROI_L5 = false(sy, sx);
    
    for x = x_left_start : x_left_end
        y_ilm = round(Layer_ILM(x)); y_b1 = round(Layer_Blue1(x)); y_b2 = round(Layer_Blue2(x));
        y_b3 = round(Layer_Blue3(x)); y_b4 = round(Layer_Blue4(x)); y_yel = round(Layer_Inner_Bot(x)); y_mag = round(Layer_RPE_bot(x));
        
        if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin), Mask_ROI_L1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true; end
        if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin), Mask_ROI_L2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true; end
        if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin), Mask_ROI_L3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true; end
        if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin), Mask_ROI_L4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true; end
        if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin), Mask_ROI_L5((y_yel + vert_margin):(y_mag - vert_margin), x) = true; end
    end
    
    %% 5 Right-Side ROIs (Anchored to Hole)
    x_right_start = min(sx, hole_right_edge + safe_margin);
    x_right_end   = min(sx, x_right_start + roi_half_width - 1);
    
    Mask_ROI_R1 = false(sy, sx); Mask_ROI_R2 = false(sy, sx); Mask_ROI_R3 = false(sy, sx);
    Mask_ROI_R4 = false(sy, sx); Mask_ROI_R5 = false(sy, sx);
    
    for x = x_right_start : x_right_end
        y_ilm = round(Layer_ILM(x)); y_b1 = round(Layer_Blue1(x)); y_b2 = round(Layer_Blue2(x));
        y_b3 = round(Layer_Blue3(x)); y_b4 = round(Layer_Blue4(x)); y_yel = round(Layer_Inner_Bot(x)); y_mag = round(Layer_RPE_bot(x));
        
        if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin), Mask_ROI_R1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true; end
        if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin), Mask_ROI_R2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true; end
        if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin), Mask_ROI_R3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true; end
        if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin), Mask_ROI_R4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true; end
        if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin), Mask_ROI_R5((y_yel + vert_margin):(y_mag - vert_margin), x) = true; end
    end

    %% VISUALIZATION 
    Mask_All_Left = Mask_ROI_L1 | Mask_ROI_L2 | Mask_ROI_L3 | Mask_ROI_L4 | Mask_ROI_L5;
    Mask_All_Right = Mask_ROI_R1 | Mask_ROI_R2 | Mask_ROI_R3 | Mask_ROI_R4 | Mask_ROI_R5;
    Mask_All_FW = Mask_All_Left | Mask_All_Right;
    figure; imagesc(I_crop_aligned); colormap gray; hold on;
    title(sprintf('Fixed-Width Perilesional ROIs (Width: %d px)', roi_half_width));
    plot(1:sx, Layer_ILM, 'r-', 'LineWidth', 1);
    plot(1:sx, Layer_Inner_Bot, 'y-', 'LineWidth', 1);
    plot(1:sx, Layer_RPE_bot, 'm-', 'LineWidth', 1);
    
    % Cyan overlay for fixed-width visualization
    cyan_overlay = cat(3, zeros(sy,sx), ones(sy,sx), ones(sy,sx));
    h_overlay = imagesc(cyan_overlay);
    set(h_overlay, 'AlphaData', Mask_All_FW * 0.4);
    hold off;

    %% Calculate Statistics
    masks_left = {Mask_ROI_L1, Mask_ROI_L2, Mask_ROI_L3, Mask_ROI_L4, Mask_ROI_L5};
    roi_fields = {'L1', 'L2', 'L3', 'L4', 'L5'};
    STATS_Left_fw = struct();
    for i = 1:5
        Final_Mask = transform_mask_to_raw(masks_left{i}, angle_deg, geom);
        ROI_raw = double(I_true_raw(Final_Mask)); 
        
        if ~isempty(ROI_raw)
            ROI_transformed = (10.^(ROI_raw/255) - 1) / 9; 
            STATS_Left_fw.(roi_fields{i}) = speckle_stats(ROI_transformed, ROI_raw);
        else
            STATS_Left_fw.(roi_fields{i}) = []; 
        end
    end
    
    masks_right = {Mask_ROI_R1, Mask_ROI_R2, Mask_ROI_R3, Mask_ROI_R4, Mask_ROI_R5};
    roi_fields_right = {'R1', 'R2', 'R3', 'R4', 'R5'};
    STATS_Right_fw = struct();
    for i = 1:5
        Final_Mask_R = transform_mask_to_raw(masks_right{i}, angle_deg, geom);
        ROI_raw_R = double(I_true_raw(Final_Mask_R)); 
        
        if ~isempty(ROI_raw_R)
            ROI_transformed_R = (10.^(ROI_raw_R/255) - 1) / 9; 
            STATS_Right_fw.(roi_fields_right{i}) = speckle_stats(ROI_transformed_R, ROI_raw_R);
        else
            STATS_Right_fw.(roi_fields_right{i}) = []; 
        end
    end
end

%% HELPER FUNCTION: Maps the AI mask back to the unstretched raw dimensions
function True_Mask = transform_mask_to_raw(Mask, angle_deg, geom)
    % 1. Rotate back to unaligned state
    M_rot = imrotate(Mask, -angle_deg, 'nearest', 'crop');
    
    % 2. Undo vertical crop (pad top and bottom)
    pad_top = geom.crop_top - 1;
    pad_bottom = geom.target_sy - geom.Y_max;
    M_unpad_v = padarray(M_rot, [pad_top, 0], 0, 'pre');
    M_unpad_v = padarray(M_unpad_v, [pad_bottom, 0], 0, 'post');
    
    % 3. Undo horizontal crop (pad left and right)
    M_unpad_full = padarray(M_unpad_v, [0, geom.Margin], 0, 'both');
    
    % 4. Shrink/Expand back to true original dimensions using 'nearest' so it stays a 0/1 mask
    True_Mask = imresize(M_unpad_full, [geom.orig_sy, geom.orig_sx], 'nearest');
end