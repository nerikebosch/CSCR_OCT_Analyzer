function make_results_figures(options)
% MAKE_RESULTS_FIGURES Figures for the Results chapter, comparing OD (affected) and OS (fellow eye).
%
%   make_results_figures()          fixed-width ROIs, Spearman, saved in ./figs/results
%   make_results_figures(options)   with fields (all optional):
%       RoiMode      - 'fw' (default, fixed-width ROIs) or 'legacy'
%       Method       - 'Spearman' (default) or 'Pearson'
%       DetailLayers - layers that get their own correlation page, default [4 5]
%       OutDir       - output folder, default 'figs/results'
%
%   Every figure is sized for an A4 text width (16-17 cm) and saved as .png (300 dpi) and .pdf (vector).
%
%   3.1 Temporal evolution
%     res_morphology                OD fluid area / height / width / shape over the follow-up
%     res_wilcoxon_table.tex        LaTeX table of OD vs OS differences that survive FDR
%     res_timecourse_CR / _Densito / _NK_mu   central thickness on top, then L1-L5 (rows) x Left/Right ROI (columns),
%                                   OD and OS over the follow-up in the same panel
%     res_od_os_effects             Wilcoxon OD vs OS for every metric and ROI: signed effect size r,
%                                   * p < 0.05, ** survives FDR
%     res_paired_CR / _Densito / _ratios   paired OD-OS values per visit for each ROI
%   3.2 Distribution fitting
%     res_bestfit                   rank of the 8 distributions per ROI (median GoF), OD | OS
%   3.3 Clinical correlations
%     res_corr_overview_Right/Left  5 rows (L1-L5) x 2 columns (OD | OS), one page per ROI side
%     res_corr_L4, res_corr_L5      one page per layer: OD | OS, Right ROI (top) and Left ROI (bottom),
%                                   with readable labels
%     res_clinical                  Spearman rho of CR / densitometry with central thickness and fluid area

    if nargin < 1, options = struct(); end
    if ~isfield(options, 'RoiMode'),      options.RoiMode = 'fw'; end
    if ~isfield(options, 'Method'),       options.Method = 'Spearman'; end
    if ~isfield(options, 'DetailLayers'), options.DetailLayers = [4 5]; end
    if ~isfield(options, 'OutDir'),       options.OutDir = fullfile('figs', 'results'); end

    here = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(here, 'stats_utils')));
    if ~isfolder(options.OutDir), mkdir(options.OutDir); end

    S = db_manager('get_summary');
    if isempty(S), error('The database has no summary data.'); end
    S = sortrows(S, 'VisitDate');

    C = struct();
    C.sfx = ''; if strcmpi(options.RoiMode, 'fw'), C.sfx = '_fw'; end
    C.modeName = 'fixed-width ROIs'; if isempty(C.sfx), C.modeName = 'full-extent ROIs'; end
    C.OD = [0.80 0.25 0.20]; C.OS = [0.20 0.40 0.75];
    nC = 128;
    C.cmap = [interp1([0 1], [C.OS; 1 1 1], linspace(0, 1, nC)); ...
              interp1([0 1], [1 1 1; C.OD], linspace(0, 1, nC))];
    C.method = options.Method;
    C.out = options.OutDir;
    C.days = days(S.VisitDate - S.VisitDate(1));

    W = compute_statistics('wilcoxon', options.RoiMode);

    steps = {@() fig_timecourse(S, W, C, 'CR'), ...
             @() fig_timecourse(S, W, C, 'Densito'), ...
             @() fig_timecourse(S, W, C, 'NK_mu'), ...
             @() fig_morphology(S, C), ...
             @() table_wilcoxon(W, C), ...
             @() fig_effects(W, C), ...
             @() fig_paired(S, W, C, 'CR'), ...
             @() fig_paired(S, W, C, 'Densito'), ...
             @() fig_paired_ratios(S, W, C), ...
             @() fig_bestfit(S, C), ...
             @() fig_corr_overview(S, C), ...
             @() fig_corr_detail(S, C, options.DetailLayers), ...
             @() fig_clinical(S, C)};
    for k = 1:numel(steps)
        try
            steps{k}();
        catch ME
            warning('Results figure %d failed: %s (%s, line %d)', k, ME.message, ME.stack(1).name, ME.stack(1).line);
        end
    end
    fprintf('Results figures saved in %s\n', C.out);
end

%% ========================================================================
%  3.1  Temporal evolution: OD and OS over the follow-up, per layer and ROI side
%  ========================================================================
function fig_timecourse(S, W, C, metric)
    [mName, yLab] = metric_label(metric);
    f = newfig(17, 24);
    tl = tiledlayout(f, 6, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Central thickness spans both columns: clinical context for the rows below
    ax = nexttile(tl, 1, [1 2]); hold(ax, 'on');
    plot(ax, C.days, S.CentralThickness_OD, '-o', 'Color', C.OD, 'MarkerFaceColor', C.OD, 'MarkerSize', 3, 'LineWidth', 1.1);
    plot(ax, C.days, S.CentralThickness_OS, '-s', 'Color', C.OS, 'MarkerFaceColor', C.OS, 'MarkerSize', 3, 'LineWidth', 1.1);
    ylabel(ax, 'CRT (\mum)'); style_ax(ax); xlim(ax, [-10, max(C.days) + 10]);
    legend(ax, {'OD (affected)', 'OS (fellow)'}, 'Location', 'northwest', 'Orientation', 'horizontal', 'Box', 'off');
    title(ax, '(a) Central retinal thickness', 'FontWeight', 'normal');

    sides = {'Left', 'Right'}; letter = 'b';
    for L = 1:5
        axs = gobjects(1, 2); vals = cell(2, 2);
        for s = 1:2
            ax = nexttile(tl); hold(ax, 'on'); axs(s) = ax;
            [od, os] = od_os(S, sides{s}, L, metric, C.sfx);
            vals(s, :) = {od, os};
            plot(ax, C.days, od, '-o', 'Color', C.OD, 'MarkerFaceColor', C.OD, 'MarkerSize', 2.5, 'LineWidth', 1);
            plot(ax, C.days, os, '-s', 'Color', C.OS, 'MarkerFaceColor', C.OS, 'MarkerSize', 2.5, 'LineWidth', 1);
            style_ax(ax); xlim(ax, [-10, max(C.days) + 10]);
            title(ax, sprintf('(%c) %s ROI, L%d   %s', letter, sides{s}, L, wil_tag(W, sides{s}, sprintf('L%d', L), mName)), ...
                  'FontWeight', 'normal');
            letter = letter + 1;
            if s == 1, ylabel(ax, yLab); end
            if L == 5, xlabel(ax, 'Days since first visit'); else, ax.XTickLabel = {}; end
        end
        % Same y-scale for Left and Right ROI of one layer so they can be compared;
        % single extreme outliers are drawn on the axis edge instead of stretching the scale
        set(axs, 'YLim', robust_lim(vertcat(vals{:})));
        for s = 1:2
            mark_clipped(axs(s), C.days, vals{s, 1}, C.OD);
            mark_clipped(axs(s), C.days, vals{s, 2}, C.OS);
        end
    end
    save_fig(f, C, sprintf('res_timecourse_%s', metric));
end

%% Fluid pocket over the follow-up (OD), with central thickness for reference
function fig_morphology(S, C)
    found = col(S, 'Median_OD_Hole_Found') >= 0.5;    % fluid in at least 2 of the 3 B-scans
    f = newfig(17, 15);
    tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax = nexttile(tl); hold(ax, 'on');
    yyaxis(ax, 'left');
    a = col(S, 'Median_OD_Hole_Area');
    plot(ax, C.days, a, '-o', 'Color', C.OD, 'MarkerFaceColor', C.OD, 'MarkerSize', 3, 'LineWidth', 1.1);
    plot(ax, C.days(~found), a(~found), 'o', 'Color', C.OD, 'MarkerFaceColor', 'w', 'MarkerSize', 4);
    ylabel(ax, 'Fluid area (px)'); ax.YColor = C.OD;
    yyaxis(ax, 'right');
    plot(ax, C.days, S.CentralThickness_OD, '--s', 'Color', [0.3 0.3 0.3], 'MarkerSize', 3, 'LineWidth', 1);
    ylabel(ax, 'CRT OD (\mum)'); ax.YColor = [0.3 0.3 0.3];
    [r, p] = rho(a, col(S, 'CentralThickness_OD'), C.method);
    title(ax, sprintf('(a) Fluid area and central thickness (%s \\rho = %.2f, p %s)', C.method, r, fmt_p(p)), ...
          'FontWeight', 'normal');
    style_ax(ax); ax.XTickLabel = {};

    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, C.days, col(S, 'Median_OD_Hole_Height'), '-o', 'Color', C.OD, 'MarkerFaceColor', C.OD, 'MarkerSize', 3, 'LineWidth', 1.1);
    plot(ax, C.days, col(S, 'Median_OD_Hole_Width') / 10, '-^', 'Color', [0.55 0.2 0.5], 'MarkerFaceColor', [0.55 0.2 0.5], 'MarkerSize', 3, 'LineWidth', 1.1);
    ylabel(ax, 'px'); legend(ax, {'Maximum height', 'Width / 10'}, 'Location', 'northwest', 'Box', 'off');
    title(ax, '(b) Fluid height and width', 'FontWeight', 'normal');
    style_ax(ax); ax.XTickLabel = {};

    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, C.days, col(S, 'Median_OD_Hole_Circularity'), '-o', 'Color', [0.2 0.55 0.35], 'MarkerFaceColor', [0.2 0.55 0.35], 'MarkerSize', 3, 'LineWidth', 1.1);
    plot(ax, C.days, col(S, 'Median_OD_Hole_Solidity'), '-s', 'Color', [0.85 0.55 0.1], 'MarkerFaceColor', [0.85 0.55 0.1], 'MarkerSize', 3, 'LineWidth', 1.1);
    ylabel(ax, 'ratio'); ylim(ax, [0 1.05]);
    legend(ax, {'Circularity', 'Solidity'}, 'Location', 'east', 'Box', 'off');
    title(ax, '(c) Fluid shape', 'FontWeight', 'normal');
    style_ax(ax); xlabel(ax, 'Days since first visit');
    set(findall(f, 'Type', 'axes'), 'XLim', [-10, max(C.days) + 10]);
    subtitle(tl, 'Median of the 3 B-scans per visit. Open markers: fluid detected in fewer than 2 of 3 B-scans.', 'FontSize', 7);
    save_fig(f, C, 'res_morphology');
end

%% LaTeX table of the OD vs OS differences that survive FDR (CR, densitometry, ratios, best-fit Nakagami)
function table_wilcoxon(W, C)
    keep = W.Survives_FDR & (ismember(W.Metric, ["CR", "Densitometry", "Nakagami mu", "Nakagami om"]) | ...
                             startsWith(W.Metric, "CR ratio"));
    T = sortrows(W(keep, :), {'Side', 'Layer', 'Metric'});
    fid = fopen(fullfile(C.out, 'res_wilcoxon_table.tex'), 'w');
    c = onCleanup(@() fclose(fid));
    fprintf(fid, '%% Generated by make_results_figures (%s)\n', C.modeName);
    fprintf(fid, '\\begin{table}[htbp]\n  \\centering\\small\n');
    fprintf(fid, '  \\caption{OD vs.\\ OS differences surviving FDR correction (Wilcoxon signed-rank, paired by visit, %s).}\n', C.modeName);
    fprintf(fid, '  \\label{tab:wilcoxon}\n  \\begin{tabular}{@{}lllrrrrr@{}}\n    \\toprule\n');
    fprintf(fid, '    ROI & Layer & Metric & $n$ & Median OD & Median OS & $q$ & $r$ \\\\\n    \\midrule\n');
    for i = 1:height(T)
        m = strrep(strrep(T.Metric(i), 'Nakagami mu', 'Nakagami $m$'), 'Nakagami om', 'Nakagami $\Omega$');
        q = T.q_FDR(i); if q < 0.001, qs = '$<$0.001'; else, qs = sprintf('%.3f', q); end
        fprintf(fid, '    %s & %s & %s & %d & %.3f & %.3f & %s & %.2f \\\\\n', T.Side(i), T.Layer(i), m, ...
                T.N(i), T.Median_OD(i), T.Median_OS(i), qs, T.Effect_r(i));
    end
    fprintf(fid, '    \\bottomrule\n  \\end{tabular}\n\\end{table}\n');
    fprintf('Saved %s\n', fullfile(C.out, 'res_wilcoxon_table.tex'));
end

%% OD vs OS: signed effect size for every metric and ROI
function fig_effects(W, C)
    [rowNames, ~] = metric_rows();
    nR = numel(rowNames);
    sides = {'Left', 'Right'};
    f = newfig(17, 13);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for s = 1:2
        E = nan(nR, 5); Pm = nan(nR, 5); Qm = nan(nR, 5);
        for r = 1:nR
            for L = 1:5
                k = W.Side == sides{s} & W.Layer == sprintf("L%d", L) & W.Metric == rowNames{r};
                if any(k)
                    k = find(k, 1);
                    E(r, L) = sign(W.Median_Diff(k)) * W.Effect_r(k);
                    Pm(r, L) = W.p(k); Qm(r, L) = W.q_FDR(k);
                end
            end
        end
        ax = nexttile(tl);
        imagesc(ax, E, 'AlphaData', ~isnan(E)); set(ax, 'Color', [0.9 0.9 0.9]);
        colormap(ax, C.cmap); clim(ax, [-1 1]); hold(ax, 'on');
        plot(ax, [0.5 5.5], [2.5 2.5], 'k-', 'LineWidth', 1);    % CR + densitometry | distribution parameters
        for r = 1:nR
            for L = 1:5
                if Pm(r, L) < 0.05
                    mk = '*'; if Qm(r, L) < 0.05, mk = '**'; end
                    text(ax, L, r, mk, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                         'FontSize', 7, 'FontWeight', 'bold', 'Color', 'k');
                end
            end
        end
        set(ax, 'XTick', 1:5, 'XTickLabel', compose('L%d', 1:5), 'YTick', 1:nR, 'TickLength', [0 0], ...
            'FontSize', 7, 'XColor', 'k', 'YColor', 'k', 'TickLabelInterpreter', 'none');
        if s == 1, set(ax, 'YTickLabel', rowNames); else, set(ax, 'YTickLabel', {}); end
        title(ax, sprintf('(%c) %s ROI', 'a' + s - 1, sides{s}), 'FontWeight', 'normal');
        box(ax, 'on');
    end
    cb = colorbar(ax); cb.Layout.Tile = 'east';
    cb.Label.String = 'signed effect size r  (red: OD > OS, blue: OD < OS)';
    title(tl, sprintf('OD vs OS, Wilcoxon signed-rank (paired by visit), %s', C.modeName), 'FontSize', 9);
    subtitle(tl, '* p < 0.05   ** q < 0.05 (Benjamini-Hochberg over all tests)', 'FontSize', 7);
    save_fig(f, C, 'res_od_os_effects');
end

%% Paired OD-OS values per visit: rows = ROI side, columns = layer
function fig_paired(S, W, C, metric)
    [mName, yLab] = metric_label(metric);
    sides = {'Left', 'Right'};
    f = newfig(17, 11);
    tl = tiledlayout(f, 2, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
    for s = 1:2
        axs = gobjects(1, 5); vals = cell(5, 2);
        for L = 1:5
            ax = nexttile(tl); axs(L) = ax;
            [od, os] = od_os(S, sides{s}, L, metric, C.sfx);
            paired_panel(ax, od, os, C);
            vals(L, :) = {od, os};
            title(ax, {sprintf('%s L%d', sides{s}, L), wil_tag(W, sides{s}, sprintf('L%d', L), mName)}, ...
                  'FontWeight', 'normal', 'FontSize', 7);
            if L == 1, ylabel(ax, yLab); end
        end
        set(axs, 'YLim', robust_lim(vertcat(vals{:})));   % one scale per row
        for L = 1:5
            mark_clipped(axs(L), ones(height(S), 1), vals{L, 1}, C.OD);
            mark_clipped(axs(L), 2 * ones(height(S), 1), vals{L, 2}, C.OS);
        end
    end
    title(tl, sprintf('%s, OD vs OS per visit (lines connect the same visit), %s', mName, C.modeName), 'FontSize', 9);
    save_fig(f, C, sprintf('res_paired_%s', metric));
end

function fig_paired_ratios(S, W, C)
    sides = {'Left', 'Right'}; ratios = {'L3_L4', 'L4_L5'};
    f = newfig(17, 6.5);
    tl = tiledlayout(f, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    for s = 1:2
        for r = 1:2
            ax = nexttile(tl);
            od = col(S, sprintf('Median_OD_%s_Ratio_%s%s', sides{s}, ratios{r}, C.sfx));
            os = col(S, sprintf('Median_OS_%s_Ratio_%s%s', sides{s}, ratios{r}, C.sfx));
            paired_panel(ax, od, os, C);
            lay = strrep(ratios{r}, '_', '/');
            title(ax, {sprintf('%s CR %s', sides{s}, lay), wil_tag(W, sides{s}, lay, ['CR ratio ' lay])}, ...
                  'FontWeight', 'normal', 'FontSize', 7);
            if s == 1 && r == 1, ylabel(ax, 'CR ratio'); end
        end
    end
    save_fig(f, C, 'res_paired_ratios');
end

%% ========================================================================
%  3.2  Distribution fitting: which distribution fits best, per ROI and eye
%  ========================================================================
function fig_bestfit(S, C)
    tags  = {'BURR', 'EXP', 'GAM', 'K', 'LN', 'NK', 'RAY', 'WBL'};
    names = {'Burr', 'Exponential', 'Gamma', 'K', 'Log-normal', 'Nakagami', 'Rayleigh', 'Weibull'};
    eyes = {'OD', 'OS'}; eyeNames = {'OD (affected)', 'OS (fellow)'};
    rois = [compose('Left_L%d', 1:5), compose('Right_L%d', 1:5)];
    xl = [compose('L%d', 1:5), compose('L%d', 1:5)];

    f = newfig(17, 9);
    tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    rankCmap = flipud(interp1([0 1], [0.93 0.93 0.93; 0.15 0.45 0.35], linspace(0, 1, 8)));
    for e = 1:2
        Rk = nan(8, numel(rois)); Wins = zeros(8, numel(rois));
        for j = 1:numel(rois)
            G = nan(height(S), 8);
            for k = 1:8
                G(:, k) = col(S, sprintf('Median_%s_%s_GoF_%s%s', eyes{e}, rois{j}, tags{k}, C.sfx));
            end
            med = median(G, 1, 'omitnan');
            [~, ord] = sort(med, 'ascend', 'MissingPlacement', 'last');
            Rk(ord, j) = 1:8; Rk(isnan(med), j) = NaN;
            ok = any(~isnan(G), 2);
            if any(ok)
                [~, b] = min(G(ok, :), [], 2);
                Wins(:, j) = accumarray(b, 1, [8 1]);
            end
        end
        ax = nexttile(tl);
        imagesc(ax, Rk, 'AlphaData', ~isnan(Rk)); colormap(ax, rankCmap); clim(ax, [0.5 8.5]);
        hold(ax, 'on');
        plot(ax, [5.5 5.5], [0.5 8.5], 'k-', 'LineWidth', 1.2);
        for j = 1:numel(rois)
            for k = 1:8
                if Wins(k, j) > 0
                    tc = 'k'; if Rk(k, j) <= 3, tc = 'w'; end
                    text(ax, j, k, sprintf('%d', Wins(k, j)), 'HorizontalAlignment', 'center', ...
                         'FontSize', 6, 'Color', tc);
                end
            end
            b = find(Rk(:, j) == 1, 1);
            if ~isempty(b)
                rectangle(ax, 'Position', [j - 0.48, b - 0.48, 0.96, 0.96], 'EdgeColor', 'k', 'LineWidth', 1.2);
            end
        end
        set(ax, 'XTick', 1:numel(rois), 'XTickLabel', xl, 'YTick', 1:8, 'TickLength', [0 0], 'FontSize', 7, ...
            'XColor', 'k', 'YColor', 'k');
        if e == 1, set(ax, 'YTickLabel', names); else, set(ax, 'YTickLabel', {}); end
        xlabel(ax, 'Left ROI             |             Right ROI');
        title(ax, sprintf('(%c) %s', 'a' + e - 1, eyeNames{e}), 'FontWeight', 'normal');
    end
    cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Ticks = 1:8; cb.Direction = 'reverse';
    cb.Label.String = 'rank by median GoF (1 = best)';
    subtitle(tl, 'Box: best distribution (lowest median RMSE over visits). Numbers: visits on which it was the best fit. White: fit failed.', ...
             'FontSize', 7);
    save_fig(f, C, 'res_bestfit');
end

%% ========================================================================
%  3.3  Correlations across visits
%  ========================================================================
% One page per ROI side: rows = L1..L5, columns = OD | OS (overview, no variable labels)
function fig_corr_overview(S, C)
    eyes = {'OD', 'OS'}; eyeNames = {'OD (affected)', 'OS (fellow)'};
    for side = {'Right', 'Left'}
        f = newfig(11.5, 24);
        tl = tiledlayout(f, 5, 2, 'TileSpacing', 'tight', 'Padding', 'compact');
        for L = 1:5
            for e = 1:2
                ax = nexttile(tl);
                [X, labels, nMorph] = corr_matrix_build(S, eyes{e}, sprintf('%s_L%d', side{1}, L), C.sfx);
                o = struct('ShowX', false, 'ShowY', false, 'MarkSize', 3.5);
                corr_matrix_draw(ax, X, labels, nMorph, C.method, C.cmap, o);
                group_ticks(ax, numel(labels), nMorph);
                if L == 1, title(ax, eyeNames{e}, 'FontWeight', 'bold', 'FontSize', 9); end
                if e == 1, ylabel(ax, sprintf('L%d', L), 'FontWeight', 'bold', 'FontSize', 9, 'Rotation', 0, ...
                                  'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle'); end
            end
        end
        cb = colorbar(ax); cb.Layout.Tile = 'south'; cb.Label.String = sprintf('%s correlation', C.method);
        title(tl, sprintf('%s ROI, %s', side{1}, C.modeName), 'FontSize', 10);
        subtitle(tl, {'M: fluid morphology + thickness, T: CR, densitometry and distribution parameters', ...
                      '* p < 0.05   ** q < 0.05 (FDR)   box: |r| \geq r_{min} (80% power)'}, 'FontSize', 7);
        save_fig(f, C, sprintf('res_corr_overview_%s', side{1}));
    end
end

% One page per layer: rows = Right / Left ROI, columns = OD | OS, all variable labels
function fig_corr_detail(S, C, layers)
    eyes = {'OD', 'OS'}; eyeNames = {'OD (affected)', 'OS (fellow)'}; sides = {'Right', 'Left'};
    for L = layers
        f = newfig(17, 20.5);
        tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        letter = 'a';
        for s = 1:2
            for e = 1:2
                ax = nexttile(tl);
                [X, labels, nMorph] = corr_matrix_build(S, eyes{e}, sprintf('%s_L%d', sides{s}, L), C.sfx);
                o = struct('ShowX', true, 'ShowY', true, 'FontSize', 5, 'MarkSize', 4);
                n = corr_matrix_draw(ax, X, labels, nMorph, C.method, C.cmap, o);
                title(ax, sprintf('(%c) %s, %s ROI (n = %d)', letter, eyeNames{e}, sides{s}, n), ...
                      'FontWeight', 'normal', 'FontSize', 8);
                letter = letter + 1;
            end
        end
        cb = colorbar(ax); cb.Layout.Tile = 'south'; cb.Label.String = sprintf('%s correlation', C.method);
        title(tl, sprintf('Layer L%d, %s', L, C.modeName), 'FontSize', 10);
        subtitle(tl, '* p < 0.05   ** q < 0.05 (FDR)   box: |r| \geq r_{min} (80% power)', 'FontSize', 7);
        save_fig(f, C, sprintf('res_corr_L%d', L));
    end
end

% Spearman rho of CR / densitometry with clinical variables
function fig_clinical(S, C)
    sides = {'Left', 'Right'};
    rowNames = [compose('CR L%d', 1:5), compose('Densitometry L%d', 1:5)];
    metrics = [repmat({'CR'}, 1, 5), repmat({'Densito'}, 1, 5)];
    layers = [1:5, 1:5];

    % (a) vs central thickness of the same eye: OD-Left, OD-Right, OS-Left, OS-Right
    colsA = {'OD', 'Left'; 'OD', 'Right'; 'OS', 'Left'; 'OS', 'Right'};
    [Ra, Pa, Na] = deal(nan(10, 4));
    for c = 1:4
        y = col(S, sprintf('CentralThickness_%s', colsA{c, 1}));
        for r = 1:10
            x = metric_col(S, colsA{c, 1}, colsA{c, 2}, layers(r), metrics{r}, C.sfx);
            [Ra(r, c), Pa(r, c), Na(r, c)] = rho(x, y, C.method);
        end
    end
    % (b) vs fluid pocket area in OD (OS has almost no fluid)
    [Rb, Pb, Nb] = deal(nan(10, 2));
    y = col(S, 'Median_OD_Hole_Area');
    for c = 1:2
        for r = 1:10
            x = metric_col(S, 'OD', sides{c}, layers(r), metrics{r}, C.sfx);
            [Rb(r, c), Pb(r, c), Nb(r, c)] = rho(x, y, C.method);
        end
    end
    Q = fdr_bh([Pa(:); Pb(:)]);
    Qa = reshape(Q(1:40), 10, 4); Qb = reshape(Q(41:end), 10, 2);

    f = newfig(14, 10);
    tl = tiledlayout(f, 1, 6, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(tl, [1 4]);
    rho_heatmap(ax, Ra, Pa, Qa, Na, C, {'OD Left', 'OD Right', 'OS Left', 'OS Right'}, rowNames, true);
    title(ax, '(a) vs. central retinal thickness', 'FontWeight', 'normal');
    ax = nexttile(tl, [1 2]);
    rho_heatmap(ax, Rb, Pb, Qb, Nb, C, {'OD Left', 'OD Right'}, rowNames, false);
    title(ax, '(b) vs. fluid area (OD)', 'FontWeight', 'normal');
    cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Label.String = sprintf('%s \\rho', C.method);
    subtitle(tl, '* p < 0.05   ** q < 0.05 (FDR over both panels)   box: |\rho| \geq r_{min} (80% power)', 'FontSize', 7);
    save_fig(f, C, 'res_clinical');
end

%% ========================================================================
%  Helpers
%  ========================================================================
function rho_heatmap(ax, R, P, Q, N, C, xl, yl, showY)
    imagesc(ax, R, 'AlphaData', ~isnan(R)); set(ax, 'Color', [0.9 0.9 0.9]);
    colormap(ax, C.cmap); clim(ax, [-1 1]); hold(ax, 'on');
    plot(ax, [0.5 size(R, 2) + 0.5], [5.5 5.5], 'k-', 'LineWidth', 1);
    rMin = tanh((-norminv(0.025) - norminv(0.2)) ./ sqrt(max(N - 3, eps)));
    for r = 1:size(R, 1)
        for c = 1:size(R, 2)
            if isnan(R(r, c)), continue; end
            mk = ''; if P(r, c) < 0.05, mk = '*'; end
            if Q(r, c) < 0.05, mk = '**'; end
            text(ax, c, r, sprintf('%.2f%s', R(r, c), mk), 'HorizontalAlignment', 'center', 'FontSize', 6, 'Color', 'k');
            if P(r, c) < 0.05 && abs(R(r, c)) >= rMin(r, c)
                rectangle(ax, 'Position', [c - 0.47, r - 0.47, 0.94, 0.94], 'EdgeColor', 'k', 'LineWidth', 0.9);
            end
        end
    end
    set(ax, 'XTick', 1:numel(xl), 'XTickLabel', xl, 'YTick', 1:numel(yl), 'TickLength', [0 0], 'FontSize', 7, ...
        'XColor', 'k', 'YColor', 'k', 'XTickLabelRotation', 30);
    if showY, set(ax, 'YTickLabel', yl); else, set(ax, 'YTickLabel', {}); end
    box(ax, 'on');
end

function [r, p, n] = rho(x, y, method)
    ok = ~isnan(x) & ~isnan(y); n = sum(ok);
    r = NaN; p = NaN;
    if n >= 5 && std(x(ok)) > 0 && std(y(ok)) > 0
        [r, p] = corr(x(ok), y(ok), 'Type', method);
    end
end

function v = paired_panel(ax, od, os, C)
    hold(ax, 'on');
    ok = ~isnan(od) & ~isnan(os);
    for i = find(ok)'
        plot(ax, [1 2], [od(i) os(i)], '-', 'Color', [0.6 0.6 0.6 0.6], 'LineWidth', 0.5);
    end
    jit = 0.06;
    scatter(ax, 1 + jit * (rand(sum(ok), 1) - 0.5), od(ok), 9, C.OD, 'filled', 'MarkerFaceAlpha', 0.85);
    scatter(ax, 2 + jit * (rand(sum(ok), 1) - 0.5), os(ok), 9, C.OS, 'filled', 'MarkerFaceAlpha', 0.85);
    plot(ax, [0.75 1.25], median(od(ok)) * [1 1], 'k-', 'LineWidth', 1.8);
    plot(ax, [1.75 2.25], median(os(ok)) * [1 1], 'k-', 'LineWidth', 1.8);
    set(ax, 'XTick', [1 2], 'XTickLabel', {'OD', 'OS'}, 'FontSize', 7);
    xlim(ax, [0.5 2.5]); style_ax(ax);
    v = [od(ok); os(ok)];
    if isempty(v), v = [0; 1]; end
end

function s = wil_tag(W, side, layer, metric)
    k = find(W.Side == side & W.Layer == layer & W.Metric == metric, 1);
    if isempty(k), s = ''; return; end
    if W.q_FDR(k) < 0.05
        s = sprintf('q %s **', fmt_p(W.q_FDR(k)));
    elseif W.p(k) < 0.05
        s = sprintf('p %s *', fmt_p(W.p(k)));
    else
        s = sprintf('p %s', fmt_p(W.p(k)));
    end
end

function s = fmt_p(p)
    if p < 0.001, s = '< 0.001'; else, s = sprintf('= %.3f', p); end
end

% Axis limits that ignore extreme outliers (beyond 4 IQR from the quartiles)
function yl = robust_lim(v)
    v = v(isfinite(v));
    if isempty(v), yl = [0 1]; return; end
    q = prctile(v, [25 75]); w = 4 * max(diff(q), eps);
    in = v(v >= q(1) - w & v <= q(2) + w);
    yl = [min(in), max(in)];
    if yl(2) <= yl(1), yl = yl + [-0.5 0.5]; end
    yl = yl + [-0.08 0.08] * diff(yl);
end

% Points outside the axis are drawn on the edge as triangles with their value
function mark_clipped(ax, x, y, col)
    yl = ylim(ax);
    hi = y > yl(2); lo = y < yl(1);
    if any(hi)
        plot(ax, x(hi), repmat(yl(2), sum(hi), 1), '^', 'MarkerFaceColor', col, 'MarkerEdgeColor', 'k', 'MarkerSize', 4);
        text(ax, x(hi), repmat(yl(2), sum(hi), 1), compose(' %.2f', y(hi)), 'FontSize', 6, ...
             'VerticalAlignment', 'top', 'Color', 'k');
    end
    if any(lo)
        plot(ax, x(lo), repmat(yl(1), sum(lo), 1), 'v', 'MarkerFaceColor', col, 'MarkerEdgeColor', 'k', 'MarkerSize', 4);
        text(ax, x(lo), repmat(yl(1), sum(lo), 1), compose(' %.2f', y(lo)), 'FontSize', 6, ...
             'VerticalAlignment', 'bottom', 'Color', 'k');
    end
end

function [od, os] = od_os(S, side, L, metric, sfx)
    od = metric_col(S, 'OD', side, L, metric, sfx);
    os = metric_col(S, 'OS', side, L, metric, sfx);
end

function x = metric_col(S, eye, side, L, metric, sfx)
    if strcmp(metric, 'CR')
        x = col(S, sprintf('Median_%s_%s_L%d%s', eye, side, L, sfx));
    else
        x = col(S, sprintf('Median_%s_%s_L%d_%s%s', eye, side, L, metric, sfx));
    end
end

function x = col(S, name)
    if ismember(name, S.Properties.VariableNames)
        x = double(S.(name)); x(imag(x) ~= 0) = NaN; x = real(x(:));
    else
        x = nan(height(S), 1);
    end
end

function [mName, yLab] = metric_label(metric)
    switch metric
        case 'CR',      mName = 'CR';           yLab = 'CR';
        case 'Densito', mName = 'Densitometry'; yLab = 'Densitometry (a.u.)';
        case 'NK_mu',   mName = 'Nakagami mu';  yLab = 'Nakagami m';
        case 'NK_om',   mName = 'Nakagami om';  yLab = 'Nakagami \Omega';
        otherwise,      mName = metric;         yLab = strrep(metric, '_', ' ');
    end
end

function [rowNames, n] = metric_rows()
    dist_names = {'Gamma', 'Nakagami', 'Rayleigh', 'Weibull', 'Lognormal', 'Exponential', 'Burr', 'K-Distribution'};
    dist_params = {{'A','B'}, {'mu','om'}, {'B'}, {'A','B'}, {'mu','sig'}, {'mu'}, {'A','B'}, {'A','B'}};
    rowNames = {'CR', 'Densitometry'};
    for k = 1:8
        for p = 1:numel(dist_params{k})
            rowNames{end+1} = sprintf('%s %s', dist_names{k}, dist_params{k}{p}); %#ok<AGROW>
        end
    end
    n = numel(rowNames);
end

% Marks the two variable groups on an unlabelled matrix
function group_ticks(ax, n, nMorph)
    set(ax, 'XTick', [nMorph / 2 + 0.5, (nMorph + n) / 2 + 0.5], 'XTickLabel', {'M', 'T'}, ...
            'YTick', [nMorph / 2 + 0.5, (nMorph + n) / 2 + 0.5], 'YTickLabel', {'M', 'T'}, 'FontSize', 6);
end

function style_ax(ax)
    grid(ax, 'on'); box(ax, 'on');
    set(ax, 'XColor', 'k', 'YColor', 'k', 'GridAlpha', 0.15, 'FontSize', 7);
end

function f = newfig(w, h)
    f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [1 1 w h], 'Color', 'w');
    if isprop(f, 'Theme'), f.Theme = 'light'; end
    f.Color = 'w';
end

function save_fig(f, C, name)
    base = fullfile(C.out, name);
    exportgraphics(f, [base '.png'], 'Resolution', 300);
    exportgraphics(f, [base '.pdf'], 'ContentType', 'vector');
    close(f);
    fprintf('Saved %s.png / .pdf\n', base);
end
