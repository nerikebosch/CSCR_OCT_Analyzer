function [STATS_Full, STATS_Right, STATS_Left] = ...
        analyze_rois(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1);
    STATS_Full = [];
    STATS_Right = [];
    STATS_Left = [];    

    %% 5 Left-Side ROIs
    
    if is_hole_found
        % Find where the hole starts on the left side
        hole_columns = any(Mask_Hole, 1);
        hole_left_edge = find(hole_columns, 1, 'first');
        
        % Margins to protect the data
        safe_margin = 50; % Horizontal margin to stay clear of the hole
        vert_margin = 2; % Vertical margin to exclude the bright boundary lines
        
        % Left ROI boundaries
        x_left_start = 1; 
        x_left_end   = max(1, hole_left_edge - safe_margin);
        
        % Initialize 5 separate masks for the left side
        Mask_ROI_L1 = false(sy, sx);
        Mask_ROI_L2 = false(sy, sx);
        Mask_ROI_L3 = false(sy, sx);
        Mask_ROI_L4 = false(sy, sx);
        Mask_ROI_L5 = false(sy, sx);
        
        for x = x_left_start : x_left_end
            y_ilm = round(Layer_ILM(x));
            y_b1  = round(Layer_Blue1(x));
            y_b2  = round(Layer_Blue2(x));
            y_b3  = round(Layer_Blue3(x));
            y_b4  = round(Layer_Blue4(x));
            y_yel = round(Layer_Inner_Bot(x));
            y_mag = round(Layer_RPE_bot(x));
            
            % L1: ILM to Blue 1
            if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin)
                Mask_ROI_L1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true;
            end
            
            % L2: Blue 1 to Blue 2
            if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin)
                Mask_ROI_L2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true;
            end
            
            % L3: Blue 2 to Blue 3
            if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin)
                Mask_ROI_L3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true;
            end
            
            % L4: Blue 3 to Blue 4
            if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin)
                Mask_ROI_L4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true;
            end
            
            % L5: Yellow to Magenta
            if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin)
                Mask_ROI_L5((y_yel + vert_margin):(y_mag - vert_margin), x) = true;
            end
        end
        
        % Visualize the ROIs
        Mask_All_Left = Mask_ROI_L1 | Mask_ROI_L2 | Mask_ROI_L3 | Mask_ROI_L4 | Mask_ROI_L5;
        
        h10 = figure; imagesc(I_crop_aligned); colormap gray; hold on;
        title('5 Left-Side ROIs');
        plot(1:sx, Layer_ILM, 'r-', 'LineWidth', 1);
        plot(1:sx, Layer_Inner_Bot, 'y-', 'LineWidth', 1);
        plot(1:sx, Layer_RPE_bot, 'm-', 'LineWidth', 1);
        
        yellow_overlay = cat(3, ones(sy,sx), ones(sy,sx), zeros(sy,sx));
        h_overlay = imagesc(yellow_overlay);
        set(h_overlay, 'AlphaData', Mask_All_Left * 0.35);
        
        %% Statistics
        
        masks_left = {Mask_ROI_L1, Mask_ROI_L2, Mask_ROI_L3, Mask_ROI_L4, Mask_ROI_L5};
        roi_fields = {'L1', 'L2', 'L3', 'L4', 'L5'};
                 
        STATS_Left = struct();
                 
        for i = 1:5
            Tilted_Mask = imrotate(masks_left{i}, -angle_deg, 'nearest', 'crop');
            ROI_raw = double(I_crop_orig(Tilted_Mask)); 
            
            if ~isempty(ROI_raw)
                ROI_transformed = (10.^(ROI_raw/255) - 1) / 9; 
                current_stats = speckle_stats(ROI_transformed, ROI_raw);
                STATS_Left.(roi_fields{i}) = current_stats;
                
            else
                STATS_Left.(roi_fields{i}) = []; % Assign empty if no pixels
            end
        end
    
        disp('--- Left Side CR ---');
        if ~isempty(STATS_Left.L1), disp(STATS_Left.L1.CR); end
        if ~isempty(STATS_Left.L2), disp(STATS_Left.L2.CR); end
        if ~isempty(STATS_Left.L3), disp(STATS_Left.L3.CR); end
        if ~isempty(STATS_Left.L4), disp(STATS_Left.L4.CR); end
        if ~isempty(STATS_Left.L5), disp(STATS_Left.L5.CR); end
     
    
    %% 5 Right-Side ROIs
        % Find where the hole ends on the right side
        % (hole_columns is already defined in the left-side code)
        hole_right_edge = find(hole_columns, 1, 'last');
        
        % Right ROI boundaries
        x_right_start = min(sx, hole_right_edge + safe_margin);
        x_right_end   = sx;
        
        % Initialize 5 separate masks for the right side
        Mask_ROI_R1 = false(sy, sx);
        Mask_ROI_R2 = false(sy, sx);
        Mask_ROI_R3 = false(sy, sx);
        Mask_ROI_R4 = false(sy, sx);
        Mask_ROI_R5 = false(sy, sx);
        
        for x = x_right_start : x_right_end
            y_ilm = round(Layer_ILM(x));
            y_b1  = round(Layer_Blue1(x));
            y_b2  = round(Layer_Blue2(x));
            y_b3  = round(Layer_Blue3(x));
            y_b4  = round(Layer_Blue4(x));
            y_yel = round(Layer_Inner_Bot(x));
            y_mag = round(Layer_RPE_bot(x));
            
            % R1: ILM to Blue 1
            if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin)
                Mask_ROI_R1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true;
            end
            
            % R2: Blue 1 to Blue 2
            if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin)
                Mask_ROI_R2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true;
            end
            
            % R3: Blue 2 to Blue 3
            if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin)
                Mask_ROI_R3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true;
            end
            
            % R4: Blue 3 to Blue 4
            if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin)
                Mask_ROI_R4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true;
            end
            
            % R5: Yellow to Magenta
            if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin)
                Mask_ROI_R5((y_yel + vert_margin):(y_mag - vert_margin), x) = true;
            end
        end
        
        % Visualize the right-side ROIs on the same figure (h10)
        Mask_All_Right = Mask_ROI_R1 | Mask_ROI_R2 | Mask_ROI_R3 | Mask_ROI_R4 | Mask_ROI_R5;
        
        figure(h10);
        hold on;
        % Using the same yellow overlay color for visual symmetry
        yellow_overlay_right = cat(3, ones(sy,sx), ones(sy,sx), zeros(sy,sx));
        h_overlay_right = imagesc(yellow_overlay_right);
        set(h_overlay_right, 'AlphaData', Mask_All_Right * 0.35);
        
        %% Statistics - Right Side
        masks_right = {Mask_ROI_R1, Mask_ROI_R2, Mask_ROI_R3, Mask_ROI_R4, Mask_ROI_R5};
        roi_fields_right = {'R1', 'R2', 'R3', 'R4', 'R5'};
                 
        STATS_Right = struct();
                 
        for i = 1:5
            Tilted_Mask = imrotate(masks_right{i}, -angle_deg, 'nearest', 'crop');
            ROI_raw_R = double(I_crop_orig(Tilted_Mask)); 
            
            if ~isempty(ROI_raw_R)
                ROI_transformed_R = (10.^(ROI_raw_R/255) - 1) / 9; 
                current_stats_R = speckle_stats(ROI_transformed_R, ROI_raw_R);
                STATS_Right.(roi_fields_right{i}) = current_stats_R;
            else
                STATS_Right.(roi_fields_right{i}) = []; % Assign empty if no pixels are valid
            end
        end
        
        % Display Right Side results
        disp('--- Right Side CR ---');
        if ~isempty(STATS_Right.R1), disp(STATS_Right.R1.CR); end
        if ~isempty(STATS_Right.R2), disp(STATS_Right.R2.CR); end
        if ~isempty(STATS_Right.R3), disp(STATS_Right.R3.CR); end
        if ~isempty(STATS_Right.R4), disp(STATS_Right.R4.CR); end
        if ~isempty(STATS_Right.R5), disp(STATS_Right.R5.CR); end
    else
        % no hole found
        
        % Margins to protect the data from scan edge artifacts and boundary lines
        edge_margin = 50; 
        vert_margin = 2; 
        
        % Full width boundaries
        x_start = max(1, edge_margin);
        x_end   = min(sx, sx - edge_margin);
        
        % Initialize 5 separate masks for the full continuous width
        Mask_ROI_1 = false(sy, sx);
        Mask_ROI_2 = false(sy, sx);
        Mask_ROI_3 = false(sy, sx);
        Mask_ROI_4 = false(sy, sx);
        Mask_ROI_5 = false(sy, sx);
        
        for x = x_start : x_end
            y_ilm = round(Layer_ILM(x));
            y_b1  = round(Layer_Blue1(x));
            y_b2  = round(Layer_Blue2(x));
            y_b3  = round(Layer_Blue3(x));
            y_b4  = round(Layer_Blue4(x));
            y_yel = round(Layer_Inner_Bot(x));
            y_mag = round(Layer_RPE_bot(x));
            
            % Layer 1: ILM to Blue 1
            if ~isnan(y_ilm) && ~isnan(y_b1) && (y_b1 - y_ilm > 2 * vert_margin)
                Mask_ROI_1((y_ilm + vert_margin):(y_b1 - vert_margin), x) = true;
            end
            
            % Layer 2: Blue 1 to Blue 2
            if ~isnan(y_b1) && ~isnan(y_b2) && (y_b2 - y_b1 > 2 * vert_margin)
                Mask_ROI_2((y_b1 + vert_margin):(y_b2 - vert_margin), x) = true;
            end
            
            % Layer 3: Blue 2 to Blue 3
            if ~isnan(y_b2) && ~isnan(y_b3) && (y_b3 - y_b2 > 2 * vert_margin)
                Mask_ROI_3((y_b2 + vert_margin):(y_b3 - vert_margin), x) = true;
            end
            
            % Layer 4: Blue 3 to Blue 4
            if ~isnan(y_b3) && ~isnan(y_b4) && (y_b4 - y_b3 > 2 * vert_margin)
                Mask_ROI_4((y_b3 + vert_margin):(y_b4 - vert_margin), x) = true;
            end
            
            % Layer 5: Yellow to Magenta
            if ~isnan(y_yel) && ~isnan(y_mag) && (y_mag - y_yel > 2 * vert_margin)
                Mask_ROI_5((y_yel + vert_margin):(y_mag - vert_margin), x) = true;
            end
        end
        
        % Visualize the full-width ROIs
        Mask_All_Full = Mask_ROI_1 | Mask_ROI_2 | Mask_ROI_3 | Mask_ROI_4 | Mask_ROI_5;
        
        h11 = figure; imagesc(I_crop_aligned); colormap gray; hold on;
        title('5 Full-Width ROIs (No Hole)');
        plot(1:sx, Layer_ILM, 'r-', 'LineWidth', 1);
        plot(1:sx, Layer_Inner_Bot, 'y-', 'LineWidth', 1);
        plot(1:sx, Layer_RPE_bot, 'm-', 'LineWidth', 1);
        
        yellow_overlay_full = cat(3, ones(sy,sx), ones(sy,sx), zeros(sy,sx));
        h_overlay_full = imagesc(yellow_overlay_full);
        set(h_overlay_full, 'AlphaData', Mask_All_Full * 0.35);
        
        %% Statistics - Full Width
        masks_full = {Mask_ROI_1, Mask_ROI_2, Mask_ROI_3, Mask_ROI_4, Mask_ROI_5};
        roi_fields_full = {'Layer1', 'Layer2', 'Layer3', 'Layer4', 'Layer5'};
                 
        STATS_Full = struct();
                 
        for i = 1:5
            Tilted_Mask = imrotate(masks_full{i}, -angle_deg, 'nearest', 'crop');
            ROI_raw_F = double(I_crop_orig(Tilted_Mask)); 
            
            if ~isempty(ROI_raw_F)
                ROI_transformed_F = (10.^(ROI_raw_F/255) - 1) / 9; 
                current_stats_F = speckle_stats(ROI_transformed_F, ROI_raw_F);
                STATS_Full.(roi_fields_full{i}) = current_stats_F;
            else
                STATS_Full.(roi_fields_full{i}) = []; % Assign empty if no pixels are valid
            end
        end
        
        % Display Full Width results
        disp('--- Full Width CR ---');
        if ~isempty(STATS_Full.Layer1), disp(STATS_Full.Layer1.CR); end
        if ~isempty(STATS_Full.Layer2), disp(STATS_Full.Layer2.CR); end
        if ~isempty(STATS_Full.Layer3), disp(STATS_Full.Layer3.CR); end
        if ~isempty(STATS_Full.Layer4), disp(STATS_Full.Layer4.CR); end
        if ~isempty(STATS_Full.Layer5), disp(STATS_Full.Layer5.CR); end
    end