function T = dark_threshold(I_work, Layer_ILM)
% DARK_THRESHOLD Grey level below which a pixel is as dark as the vitreous.
%   T = dark_threshold(I_work, Layer_ILM)
%   Subretinal fluid and the vitreous are both optically clear, so ROI pixels no
%   brighter than the vitreous are treated as fluid-like (quality check DarkFrac).
%   T = 95th percentile of the vitreous pixels (rows above ILM - 3 px) of the
%   working image. Falls back to the first Otsu threshold if too few are found.
    [sy, sx] = size(I_work);
    vit = false(sy, sx);
    for x = 1:sx
        r = round(Layer_ILM(x)) - 3;
        if ~isnan(r) && r >= 1, vit(1:min(r, sy), x) = true; end
    end
    vals = double(I_work(vit));
    if numel(vals) >= 500
        T = prctile(vals, 95);
    else
        T_otsu = multithresh(uint8(I_work), 3);
        T = double(T_otsu(1));
    end
end
