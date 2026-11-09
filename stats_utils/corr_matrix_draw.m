function nVisits = corr_matrix_draw(ax, X, labels, nMorph, method, cmap, opts)
% CORR_MATRIX_DRAW Draws one correlation matrix (across visits) with significance marks.
%   * p < 0.05   ** survives FDR (q < 0.05, unique pairs)   box = also |r| >= r_min (80% power)
%   opts fields (optional): ShowX, ShowY (tick labels, default true), FontSize (6), MarkSize (5)
    if nargin < 7, opts = struct(); end
    if ~isfield(opts, 'ShowX'), opts.ShowX = true; end
    if ~isfield(opts, 'ShowY'), opts.ShowY = true; end
    if ~isfield(opts, 'FontSize'), opts.FontSize = 6; end
    if ~isfield(opts, 'MarkSize'), opts.MarkSize = 5; end
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

    % Minimum |r| for 80% power at alpha = 0.05, per pair's own n
    valid = double(~isnan(X));
    Npair = valid' * valid;
    Zsum = -norminv(0.05/2) - norminv(0.2);
    rMin = tanh(Zsum ./ sqrt(max(Npair - 3, eps)));

    imagesc(ax, R, 'AlphaData', ~isnan(R));
    set(ax, 'Color', [0.9 0.9 0.9]);
    colormap(ax, cmap);
    clim(ax, [-1 1]);
    axis(ax, 'image');
    hold(ax, 'on');

    plot(ax, [nMorph nMorph] + 0.5, [0.5 n + 0.5], 'k-', 'LineWidth', 1);
    plot(ax, [0.5 n + 0.5], [nMorph nMorph] + 0.5, 'k-', 'LineWidth', 1);

    offDiag = (1:n)' ~= (1:n);
    [ri, ci] = find(P < 0.05 & offDiag);
    for s = 1:numel(ri)
        mark = '*';
        if Q(ri(s), ci(s)) < 0.05, mark = '**'; end
        text(ax, ci(s), ri(s), mark, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', opts.MarkSize, 'FontWeight', 'bold', 'Color', 'k');
        if abs(R(ri(s), ci(s))) >= rMin(ri(s), ci(s))
            rectangle(ax, 'Position', [ci(s) - 0.45, ri(s) - 0.45, 0.9, 0.9], ...
                      'EdgeColor', 'k', 'LineWidth', 0.6);
        end
    end
    hold(ax, 'off');

    set(ax, 'XTick', 1:n, 'YTick', 1:n, 'TickLabelInterpreter', 'none', 'FontSize', opts.FontSize, ...
        'TickLength', [0 0], 'XColor', 'k', 'YColor', 'k');
    if opts.ShowX, set(ax, 'XTickLabel', labels, 'XTickLabelRotation', 90); else, set(ax, 'XTickLabel', {}); end
    if opts.ShowY, set(ax, 'YTickLabel', labels); else, set(ax, 'YTickLabel', {}); end

    nVisits = sum(any(~isnan(X), 2));
end
