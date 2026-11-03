function export_corr_matrices(options)
% EXPORT_CORR_MATRICES Saves the per-ROI correlation matrices as figures for the thesis.
%
%   export_corr_matrices()            Spearman, legacy ROIs, saved in ./figures
%   export_corr_matrices(options)     with fields (all optional):
%       Method   - 'Spearman' (default) or 'Pearson'
%       RoiMode  - 'legacy' (default) or 'fw' (fixed-width ROIs)
%       Layers   - layer numbers to show, default 1:5
%       OutDir   - output folder, default 'figures'
%
%   Makes two figures, both with rows = eye (OD, OS) and columns = layer:
%       1) Right ROIs  ->  corr_matrix_Right_<method>_<mode>.png/.pdf
%       2) Left ROIs   ->  corr_matrix_Left_<method>_<mode>.png/.pdf
%
%   Same as the dashboard's Correlation Matrix tab: correlation across visits
%   (one value per visit = median of its scans), FDR over the unique pairs.
%   * p < 0.05   ** survives FDR (q < 0.05)   box = also |r| >= r_min (80% power)

    if nargin < 1, options = struct(); end
    if ~isfield(options, 'Method'),  options.Method  = 'Spearman'; end
    if ~isfield(options, 'RoiMode'), options.RoiMode = 'legacy'; end
    if ~isfield(options, 'Layers'),  options.Layers  = 1:5; end
    if ~isfield(options, 'OutDir'),  options.OutDir  = 'figures'; end

    SummaryData = db_manager('get_summary');
    if isempty(SummaryData), error('The database has no summary data.'); end
    if ~isfolder(options.OutDir), mkdir(options.OutDir); end

    sfx = ''; if strcmp(options.RoiMode, 'fw'), sfx = '_fw'; end
    modeName = 'Legacy ROI'; if strcmp(options.RoiMode, 'fw'), modeName = 'Fixed-width ROI'; end
    eyes = {'OD', 'OS'};
    eyeNames = {'OD (diseased)', 'OS (fellow)'};

    nC = 128; cBlue = [0.2 0.4 0.75]; cRed = [0.8 0.25 0.2];
    corrCmap = [interp1([0 1], [cBlue; 1 1 1], linspace(0, 1, nC)); ...
                interp1([0 1], [1 1 1; cRed], linspace(0, 1, nC))];

    sides = {'Right', 'Left'};
    for s = 1:numel(sides)
        side = sides{s};
        nL = numel(options.Layers);

        fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [1 1 17*nL + 4 36], ...
                     'Name', sprintf('%s ROIs', side));
        tl = tiledlayout(fig, 2, nL, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('%s ROIs  |  %s correlation across visits  |  %s', side, options.Method, modeName), ...
              'FontWeight', 'bold', 'Color', 'k');
        subtitle(tl, ['* p < 0.05     ** survives FDR (q < 0.05)     box = also |r| \geq r_{min} ' ...
                      '(80% power, \alpha = 0.05)     black lines separate morphology + thickness from speckle statistics'], ...
                 'Color', 'k');

        for e = 1:2
            for li = 1:nL
                ax = nexttile(tl);
                roi = sprintf('%s_L%d', side, options.Layers(li));
                [X, labels, nMorph] = build_matrix(SummaryData, eyes{e}, roi, sfx);
                nVisits = draw_matrix(ax, X, labels, nMorph, options.Method, corrCmap, true, true);
                title(ax, sprintf('%s  L%d  (n = %d)', eyeNames{e}, options.Layers(li), nVisits), ...
                      'FontWeight', 'bold', 'FontSize', 9, 'Color', 'k');
            end
        end
        cb = colorbar(ax);
        cb.Layout.Tile = 'east';
        cb.Label.String = sprintf('%s correlation', options.Method);
        cb.Color = 'k';

        baseName = fullfile(options.OutDir, sprintf('corr_matrix_%s_%s_%s', side, options.Method, options.RoiMode));
        exportgraphics(fig, [baseName '.png'], 'Resolution', 300);
        exportgraphics(fig, [baseName '.pdf'], 'ContentType', 'vector');
        fprintf('Saved %s.png / .pdf\n', baseName);
    end
end

%% Same variables as the dashboard; kept fixed (NaN if missing) so all tiles share labels
function [X, labels, nMorph] = build_matrix(SummaryData, eyeSide, roi, sfx)
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

function nVisits = draw_matrix(ax, X, labels, nMorph, method, cmap, showX, showY)
    n = numel(labels);

    % Constant or near-empty variables have no correlation: shown as blank cells
    bad = sum(~isnan(X), 1) < 3 | ~(std(X, 0, 1, 'omitnan') > 0);
    X(:, bad) = NaN;

    [R, P] = corr(X, 'Type', method, 'Rows', 'pairwise');
    R(bad, :) = NaN; R(:, bad) = NaN; P(bad, :) = NaN; P(:, bad) = NaN;

    upperTri = triu(true(n), 1);
    Q = nan(n);
    Q(upperTri) = fdr_bh(P(upperTri));
    Q = min(Q, Q');

    % Minimum |r| for 80% power at alpha = 0.05, per pair's own n (inverse of sample_size_corr)
    valid = double(~isnan(X));
    Npair = valid' * valid;
    Zsum = -norminv(0.05/2) - norminv(0.2);
    rMin = tanh(Zsum ./ sqrt(max(Npair - 3, eps)));

    imagesc(ax, R, 'AlphaData', ~isnan(R));
    set(ax, 'Color', [0.9 0.9 0.9]);        % blank cells in light grey
    colormap(ax, cmap);
    clim(ax, [-1 1]);
    axis(ax, 'image');
    hold(ax, 'on');

    plot(ax, [nMorph nMorph] + 0.5, [0.5 n + 0.5], 'k-', 'LineWidth', 1.5);
    plot(ax, [0.5 n + 0.5], [nMorph nMorph] + 0.5, 'k-', 'LineWidth', 1.5);

    offDiag = (1:n)' ~= (1:n);
    [ri, ci] = find(P < 0.05 & offDiag);
    for s = 1:numel(ri)
        mark = '*';
        if Q(ri(s), ci(s)) < 0.05, mark = '**'; end
        text(ax, ci(s), ri(s), mark, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 5, 'FontWeight', 'bold');
        if abs(R(ri(s), ci(s))) >= rMin(ri(s), ci(s))
            rectangle(ax, 'Position', [ci(s) - 0.45, ri(s) - 0.45, 0.9, 0.9], ...
                      'EdgeColor', 'k', 'LineWidth', 0.8);
        end
    end
    hold(ax, 'off');

    set(ax, 'XTick', 1:n, 'YTick', 1:n, 'TickLabelInterpreter', 'none', 'FontSize', 6, 'TickLength', [0 0], ...
        'XColor', 'k', 'YColor', 'k');
    if showX, set(ax, 'XTickLabel', labels, 'XTickLabelRotation', 90); else, set(ax, 'XTickLabel', {}); end
    if showY, set(ax, 'YTickLabel', labels); else, set(ax, 'YTickLabel', {}); end

    nVisits = sum(any(~isnan(X), 2));
end

function q = fdr_bh(p)
    % Benjamini-Hochberg adjusted p-values (q); NaN entries are ignored
    q = nan(size(p));
    idx = find(~isnan(p));
    if isempty(idx), return; end
    [ps, ord] = sort(p(idx));
    ps = ps(:);
    nT = numel(ps);
    qs = ps .* nT ./ (1:nT)';
    qs = min(1, flipud(cummin(flipud(qs))));
    q(idx(ord)) = qs;
end
