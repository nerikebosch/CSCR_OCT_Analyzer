function [X, labels, nMorph] = corr_matrix_build(SummaryData, eyeSide, roi, sfx)
% CORR_MATRIX_BUILD Variables of one ROI correlation matrix (same list as the dashboard).
%   eyeSide - 'OD' or 'OS';  roi - e.g. 'Right_L4';  sfx - '' (legacy) or '_fw'
%   The list is fixed (missing columns become NaN) so all matrices share the same labels.
%   nMorph = number of leading morphology + thickness variables.
    vn = SummaryData.Properties.VariableNames;
    cols = {}; labels = {};

    cols{end+1} = sprintf('CentralThickness_%s', eyeSide); labels{end+1} = 'Central Thickness';
    holeFeats = {'Area', 'Width', 'Height', 'MeanHeight', 'Perimeter', 'EquivDiam', 'Circularity', ...
                 'Solidity', 'Extent', 'Eccentricity', 'AspectRatio', 'MeanIntensity', 'CR'};
    for h = 1:numel(holeFeats)
        cols{end+1} = sprintf('Median_%s_Hole_%s', eyeSide, holeFeats{h}); %#ok<AGROW>
        labels{end+1} = ['Hole ' holeFeats{h}]; %#ok<AGROW>
    end
    nMorph = numel(cols);

    dist_names = {'Gamma', 'Nakagami', 'Rayleigh', 'Weibull', 'Lognormal', 'Exponential', 'Burr', 'K-Distribution'};
    dist_tags = {'GAM', 'NK', 'RAY', 'WBL', 'LN', 'EXP', 'BURR', 'K'};
    dist_params = {{'A','B'}, {'mu','om'}, {'B'}, {'A','B'}, {'mu','sig'}, {'mu'}, {'A','B'}, {'A','B'}};

    cols{end+1} = sprintf('Median_%s_%s%s', eyeSide, roi, sfx);         labels{end+1} = 'CR';
    cols{end+1} = sprintf('Median_%s_%s_Densito%s', eyeSide, roi, sfx); labels{end+1} = 'Densitometry';
    for k = 1:8
        for p = 1:numel(dist_params{k})
            cols{end+1} = sprintf('Median_%s_%s_%s_%s%s', eyeSide, roi, dist_tags{k}, dist_params{k}{p}, sfx); %#ok<AGROW>
            labels{end+1} = sprintf('%s %s', dist_names{k}, dist_params{k}{p}); %#ok<AGROW>
        end
    end

    X = nan(height(SummaryData), numel(cols));
    for c = 1:numel(cols)
        if ismember(cols{c}, vn)
            v = double(SummaryData.(cols{c}));
            v(imag(v) ~= 0) = NaN;
            X(:, c) = real(v);
        end
    end
end
