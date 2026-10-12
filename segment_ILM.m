function [Layer_ILM, h1] = segment_ILM(I_crop, MODEL, embeddings_org, sy, sx, plotoption)
    h1 = [];
    Mask_ILM = ~segmentObjectsFromEmbeddings(MODEL, embeddings_org, [sy, sx], ...
    "ForegroundPoints",[sx/2 20], ...
    "BackgroundPoints", [[1;sx;50], [1;1;1]]); % gets point in the two corners at the top, changed to be just one point in the middle
    % Initial foreground was [821 22]
    Mask_ILM = imopen(Mask_ILM, strel('disk', 20));

    [~,Y] = meshgrid(1:sx,1:sy);
    Layer_ILM = zeros(sx,1);
    for ii = 1 : sx
        Layer_ILM(ii) = min(Y(Mask_ILM(:,ii)==1,ii));
    end
    
    % Clean smoothing using movmean
    Layer_ILM = movmean(Layer_ILM, 25, 'omitnan');
    
    % --- FOOLPROOF EDGE CAPPING ---
    % 1. Left Edge: Prevent sudden jumps at the start
    left_stable = Layer_ILM(35);
    for x = 1:30
        if abs(Layer_ILM(x) - left_stable) > 15
            Layer_ILM(x) = left_stable;
        end
    end
    
    % 2. Right Edge: Prevent the line from shooting up into the top corner
    right_stable = Layer_ILM(sx - 35);
    for x = (sx - 30):sx
        % If the line goes higher up (smaller y-value) than the stable interior, force it flat
        if Layer_ILM(x) < right_stable - 8
            Layer_ILM(x) = right_stable;
        end
    end
    
    if plotoption
        h1 = figure;imagesc(I_crop);colormap gray
        hold on;
        plot(1:sx, Layer_ILM,'r.')
    end