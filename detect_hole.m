function [is_hole_found, Mask_Hole, MaxPH, indMaxPH] = detect_hole(I_crop, MODEL, embeddings_org, sy, sx, Layer_ILM, plotoption, h1)
    
    % stretch the image vertically
    stretch_factor = 2;
    sy_stretch = round(sy * stretch_factor);
    
    % Resize the image
    I_crop_stretch = imresize(I_crop, [sy_stretch, sx], 'bicubic');

    NumTh = 3;
    T1 = multithresh(uint8(I_crop_stretch),NumTh);
    labels = imquantize(uint8(I_crop_stretch),T1);
    
    Bw2 = zeros(sy_stretch, sx); 
    
    if NumTh == 2
        ind2 = labels == 2;
        ind3 = labels == 3;
        indCom = or(ind2,ind3);
        Bw2(indCom) = 1;
    else
        ind1 = labels == 2;
        ind2 = labels == 3;
        ind3 = labels == 4;
        indCom = or(ind2,ind3);
        Bw2(ind1) = 0;
        Bw2(indCom) = 1;
    end
    
    h2 = figure; imagesc(labels); 
    title("Labels of the stretched image")
    
    Bw2 = imclose(Bw2, strel('disk', 1));
    BW2filled = imfill(Bw2,'holes');
    
    % Create U-masks
    UmaskL = zeros(sy_stretch, sx);
    UmaskL(:,[1 end]) = 1;
    UmaskL(end,:) = 1;
    
    UmaskU = zeros(sy_stretch, sx);
    UmaskU(:,[1 end]) = 1;
    UmaskU(1,:) = 1;
    
    BW2L = ~imfill(or(BW2filled,UmaskL),'holes');
    BW2U = ~imfill(or(BW2filled,UmaskU),'holes');
    BW2LU = or(BW2L,BW2U);
    Bw3 = ~or(Bw2,BW2LU);
    
    % clean the Umasks
    Bw3(1,:) = 0;
    Bw3(end,:) = 0;
    Bw3(:,1) = 0;
    Bw3(:,end) = 0;
    
    Bw3 = imopen(Bw3, strel('disk', 4));
    
    % check whether the potential hole is on the sides of the picture
    left_margin = round(sx * 0.35);
    right_margin = round(sx * 0.25);
    Bw3(:, 1:left_margin) = 0; 
    Bw3(:, end-right_margin:end) = 0;
    
    h4 = figure; imagesc(Bw3); colormap gray;
    title("Stretched Image after using imopen")
    
    % Check for holes using the stretched region properties
    stats = regionprops(logical(Bw3), 'Area', 'Centroid', 'BoundingBox', 'PixelIdxList', 'Solidity');
    
    is_hole_found = false;
    target_hole_idx = [];
    max_area = 0;
    
    for k = 1:length(stats)
        if stats(k).Area > 500 * stretch_factor 
            
            % Check intensity
            pixel_indices = stats(k).PixelIdxList;
            label1_count = sum(labels(pixel_indices) == 1);
            dark_ratio = label1_count / stats(k).Area;
            
            % Check the shape
            bbox = stats(k).BoundingBox; 
            width = bbox(3);
            height = bbox(4);
            is_not_thin  = (height / width) < 4.0;
            is_solid = stats(k).Solidity > 0.30;
            
            if dark_ratio > 0.20 && is_not_thin && is_solid
                if stats(k).Area > max_area
                    max_area = stats(k).Area;
                    target_hole_idx = k;
                    is_hole_found = true;
                end
            end
        end
    end
    
    % Initialize the original-sized mask
    Mask_Hole = false(sy, sx);
    
    if is_hole_found
        disp('Hole found')
        
        target_hole = stats(target_hole_idx);
        hole_centroid_stretch = target_hole.Centroid; 
        bbox_stretch = target_hole.BoundingBox;
        
        % Plot the centroid on the original image
        figure(h1);
        plot(hole_centroid_stretch(1), hole_centroid_stretch(2) / stretch_factor, 'r*', 'MarkerSize', 10);
    
        % SAM needs the new mathematical data for the stretched image
        disp('Extracting embeddings for stretched image...')
        embeddings_stretch = extractEmbeddings(MODEL, I_crop_stretch);
        
        % Run SAM on the stretched image
        Mask_Hole_stretch = segmentObjectsFromEmbeddings(MODEL, embeddings_stretch, [sy_stretch, sx], ...
            "BoundingBox", bbox_stretch); 
    
        Mask_Hole_stretch = bwareafilt(Mask_Hole_stretch, 1);
        
        % resize the mask to original size
        Mask_Hole = imresize(Mask_Hole_stretch, [sy, sx], 'nearest');
        
        h5 = figure; imagesc(Mask_Hole); colormap gray;
        title("SAM image of the hole (Restored to Original Size)");
    
        % Find the lowest point of the hole on the mask
        posterior_hole = nan(sx,1);
        for ii = 1 : sx
            col_top = Mask_Hole(:,ii);
            ind  = find(col_top==1);
            if ~isempty(ind)
                posterior_hole(ii) = ind(end);
            end
        end
        [MaxPH, indMaxPH] = max(posterior_hole);
    
    else
        disp('No hole')
        % --- Processing type I (No hole found) ---
        
        center_start = round(sx * 0.3);
        center_end = round(sx * 0.7);
        [ilm_max_y, local_ind] = max(Layer_ILM(center_start:center_end));
        indMaxPH = center_start + local_ind - 1; 
        
        search_start = min(sy - 10, round(ilm_max_y) + 30); 
        profile = double(I_crop(search_start:end, indMaxPH));
        
        [~, peak_idx] = max(profile);
        rpe_y = search_start + peak_idx - 1;
        
        MaxPH = max(1, rpe_y - 15);
    end