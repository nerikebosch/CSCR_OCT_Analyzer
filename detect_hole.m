function [is_hole_found, Mask_Hole, MaxPH, indMaxPH, is_real_hole] = detect_hole(I_crop, MODEL, embeddings_org, sy, sx, Layer_ILM, plotoption, h1)
% is_real_hole is false when no fluid pocket was detected; is_hole_found is then
% still forced to true (with a virtual central strip as Mask_Hole) so ROIs can be built.
    
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
    
    % The fluid pocket lies near the fovea, so a candidate is only accepted when its
    % centroid is between 35 % and 75 % of the width (dark regions at the sides are
    % ignored). The side columns are NOT erased: erasing them cut the bounding box
    % given to SAM, so pockets reaching past these limits were segmented too small.
    centre_lo = round(sx * 0.35);
    centre_hi = sx - round(sx * 0.25);

    % Attempt 1: closing radius 1, dark ratio > 0.20 (original settings).
    % Attempt 2, only if nothing was found: closing radius 3 seals small gaps in the
    % tissue boundary through which a pocket can leak into the background; it needs a
    % stricter dark ratio (> 0.50) so the darker foveal centre of a dry eye is not taken.
    attempts = [1 0.20; 3 0.50];
    Bw2_tissue = Bw2;
    for a = 1:size(attempts, 1)
        Bw2 = imclose(Bw2_tissue, strel('disk', attempts(a, 1)));
        min_dark = attempts(a, 2);
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
                in_centre = stats(k).Centroid(1) >= centre_lo && stats(k).Centroid(1) <= centre_hi;

                if dark_ratio > min_dark && is_not_thin && is_solid && in_centre
                    if stats(k).Area > max_area
                        max_area = stats(k).Area;
                        target_hole_idx = k;
                        is_hole_found = true;
                    end
                end
            end
        end
        if is_hole_found, break; end
    end

    h4 = figure; imagesc(Bw3); colormap gray;
    title("Stretched Image after using imopen")
    
    % Remember whether a real hole was found (is_hole_found is forced true below if not)
    is_real_hole = is_hole_found;

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
    
        % SAM often misses the thin tapering ends of the pocket. Add the detected
        % candidate itself (a dark region fully enclosed by tissue) to the SAM mask.
        Cand_stretch = false(sy_stretch, sx);
        Cand_stretch(target_hole.PixelIdxList) = true;
        Mask_Hole_stretch = imfill(Mask_Hole_stretch | Cand_stretch, 'holes');
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
        disp('No hole found - creating robust virtual central split for symmetrical ROIs')
        
        % Find the natural foveal center safely
        center_start = round(sx * 0.3);
        center_end = round(sx * 0.7);
        
        % Check if Layer_ILM is valid in this region
        valid_ilm = Layer_ILM(center_start:center_end);
        valid_ilm(isnan(valid_ilm) | valid_ilm <= 0) = [];
        
        if ~isempty(valid_ilm)
            [~, local_ind] = max(Layer_ILM(center_start:center_end));
            indMaxPH = center_start + local_ind - 1;
        else
            % Fallback to exact middle of the image if edge slice is truncated
            indMaxPH = round(sx / 2);
        end
        
        % Ensure indMaxPH is safely away from the extreme edges (at least 25% inward)
        min_allowed = round(sx * 0.25);
        max_allowed = round(sx * 0.75);
        if indMaxPH < min_allowed || indMaxPH > max_allowed
            indMaxPH = round(sx / 2);
        end
        
        % Create a safe virtual central exclusion zone (20 pixels wide)
        hole_width = 20;
        start_col = max(1, indMaxPH - round(hole_width / 2));
        end_col = min(sx, indMaxPH + round(hole_width / 2));
        
        Mask_Hole = false(sy, sx);
        Mask_Hole(:, start_col:end_col) = true;
        
        MaxPH = round(sy / 2); 
        
        % Force flag to true so it always generates Left and Right ROIs
        is_hole_found = true; 
    end