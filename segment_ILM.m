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
    
    % filter to smooth the line
    Layer_ILM = smoothdata(Layer_ILM, 'sgolay', 45);
    
    if plotoption
        h1 = figure;imagesc(I_crop);colormap gray
        hold on;
        plot(1:sx, Layer_ILM,'r.')
    end