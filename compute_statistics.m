function varargout = compute_statistics(varargin)
% COMPUTE_STATISTICS Performs longitudinal speckle and clinical statistical analysis
% on OCT data stored in the local database.
%
% USAGE:
%   summary = compute_statistics('update_all')   - Recomputes all visit stats & updates DB.
%   corrRes = compute_statistics('correlations') - Computes thickness vs. CR correlations.
%   fig     = compute_statistics('plot')         - Plots longitudinal temporal evolution.
%   fig     = compute_statistics('plot', savePath) - Saves high-res plot.
%   report  = compute_statistics('report')       - Generates text report.

    action = 'update_all';
    if ~isempty(varargin), action = lower(varargin{1}); end

    switch action
        case 'update_all'
            varargout{1} = update_all_metrics();
        case 'correlations'
            varargout{1} = compute_correlations();
        case 'plot'
            savePath = '';
            if length(varargin) > 1, savePath = varargin{2}; end
            varargout{1} = plot_longitudinal(savePath);
        case 'report'
            varargout{1} = print_stats_report();
        otherwise
            error('Unknown action in compute_statistics: %s', action);
    end
end

%% 1. Recompute All Derived Metrics (Ratios, Rates of Change, Aggregates)
function Summary = update_all_metrics()
    Visits = db_manager('get_visits');
    Scans  = db_manager('get_scans');

    if isempty(Visits) || isempty(Scans)
        warning('Database is empty. Run migrate_excel_to_db first.');
        Summary = table();
        return;
    end

    % Ensure sorted by visit number and image index
    Visits = sortrows(Visits, 'VisitNum');
    Scans  = sortrows(Scans, {'VisitNum', 'EyeSide', 'ImageIndex'});

    numVisits = height(Visits);

    % Compute per-scan ratios
    for s = 1:height(Scans)
        % Left L4/L5 ratio
        if ~isnan(Scans.ROI_Left_L4(s)) && ~isnan(Scans.ROI_Left_L5(s)) && Scans.ROI_Left_L5(s) ~= 0
            Scans.Ratio_Left_L4_L5(s) = Scans.ROI_Left_L4(s) / Scans.ROI_Left_L5(s);
        end
        % Right L4/L5 ratio
        if ~isnan(Scans.ROI_Right_L4(s)) && ~isnan(Scans.ROI_Right_L5(s)) && Scans.ROI_Right_L5(s) ~= 0
            Scans.Ratio_Right_L4_L5(s) = Scans.ROI_Right_L4(s) / Scans.ROI_Right_L5(s);
        end
    end

    % Compute Rate of Change per image slice between consecutive visits:
    % RateOfChange = (Ratio(k, i) - Ratio(k-1, i)) / (Days(k) - Days(k-1))
    for v = 2:numVisits
        vNumCurrent = Visits.VisitNum(v);
        vNumPrev    = Visits.VisitNum(v - 1);
        dtDays = double(days(Visits.VisitDate(v) - Visits.VisitDate(v - 1)));

        if dtDays <= 0, continue; end

        for eye = ["OD", "OS"]
            currRows = find(Scans.VisitNum == vNumCurrent & Scans.EyeSide == eye);
            prevRows = find(Scans.VisitNum == vNumPrev & Scans.EyeSide == eye);

            for i = 1:min(length(currRows), length(prevRows))
                cIdx = currRows(i);
                pIdx = prevRows(i);

                % Left rate of change
                if ~isnan(Scans.Ratio_Left_L4_L5(cIdx)) && ~isnan(Scans.Ratio_Left_L4_L5(pIdx))
                    Scans.RateOfChange_Left(cIdx) = (Scans.Ratio_Left_L4_L5(cIdx) - Scans.Ratio_Left_L4_L5(pIdx)) / dtDays;
                end

                % Right rate of change
                if ~isnan(Scans.Ratio_Right_L4_L5(cIdx)) && ~isnan(Scans.Ratio_Right_L4_L5(pIdx))
                    Scans.RateOfChange_Right(cIdx) = (Scans.Ratio_Right_L4_L5(cIdx) - Scans.Ratio_Right_L4_L5(pIdx)) / dtDays;
                end
            end
        end
    end

    % Save updated scans back to DB
    dbPath = db_manager('db_path');
    data = load(dbPath);
    data.DB.Scans = Scans;
    save(dbPath, '-struct', 'data', '-v7.3');

    % Return summary
    Summary = db_manager('get_summary');
end

%% 2. Clinical Correlations (Central Thickness vs. Speckle Statistics)
function statsOut = compute_correlations()
    Summary = db_manager('get_summary');

    % Clean valid pairs for OD
    validOD = ~isnan(Summary.CentralThickness_OD) & ~isnan(Summary.Mean_Ratio_Left_L4_L5);
    th = Summary.CentralThickness_OD(validOD);
    cr_ratio = Summary.Mean_Ratio_Left_L4_L5(validOD);

    % Pearson correlation
    [r_pearson, p_pearson] = corr(th, cr_ratio, 'Type', 'Pearson');

    % Spearman correlation (rank-based, robust against outliers)
    [r_spearman, p_spearman] = corr(th, cr_ratio, 'Type', 'Spearman');

    % Linear regression model
    mdl = fitlm(th, cr_ratio);

    statsOut = struct();
    statsOut.N = sum(validOD);
    statsOut.Pearson_r = r_pearson;
    statsOut.Pearson_p = p_pearson;
    statsOut.Spearman_rho = r_spearman;
    statsOut.Spearman_p = p_spearman;
    statsOut.R_squared = mdl.Rsquared.Ordinary;
    statsOut.LinearModel = mdl;

    fprintf('\n=== STATISTICAL CORRELATION: Central Thickness vs. L4/L5 Ratio ===\n');
    fprintf('  Total Valid Visits Analyzed: %d\n', statsOut.N);
    fprintf('  Pearson Correlation (r):     %.4f (p = %.4e)\n', r_pearson, p_pearson);
    fprintf('  Spearman Correlation (rho): %.4f (p = %.4e)\n', r_spearman, p_spearman);
    fprintf('  Linear Model R-squared:      %.4f\n', statsOut.R_squared);
    if p_pearson < 0.05
        fprintf('  --> Statistically Significant (p < 0.05)!\n\n');
    else
        fprintf('  --> Not Statistically Significant at alpha = 0.05.\n\n');
    end
end

%% 3. Publication-Grade Longitudinal Plot
function hFig = plot_longitudinal(savePath)
    Summary = db_manager('get_summary');
    if isempty(Summary), error('No summary data found.'); end

    visits = Summary.VisitNum;
    dates  = Summary.VisitDate;
    th_OD  = Summary.CentralThickness_OD;
    ratio_mean = Summary.Mean_Ratio_Left_L4_L5;
    ratio_std  = Summary.Std_Ratio_Left_L4_L5;
    roc_mean   = Summary.Mean_RateOfChange_Left;

    % Replace missing std with 0 for clean errorbar plotting
    ratio_std(isnan(ratio_std)) = 0;

    hFig = figure('Name', 'OCT Longitudinal Analysis', 'Color', 'w', 'Position', [100, 80, 1100, 750]);

    %% Subplot 1: Dual-Axis Temporal Evolution (L4/L5 Ratio & Central Thickness)
    subplot(2, 1, 1);
    hold on;

    % Active / Remission Shading based on Central Thickness (Flare-up > 400 um)
    xLimits = [min(visits)-0.5, max(visits)+0.5];
    yLimsLeft = [0.4, 1.4];

    % Background Bands
    patch([xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.4, 0.4, 0.75, 0.75], ...
        [1 0.88 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'DisplayName', 'Active Zone (<0.75)');
    patch([xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.75, 0.75, 0.95, 0.95], ...
        [1 1 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'DisplayName', 'Pre-recurrence (0.75-0.95)');
    patch([xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.95, 0.95, 1.4, 1.4], ...
        [0.88 1 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'DisplayName', 'Remission (>0.95)');

    % Left Axis: Contrast Ratio (L4 / L5)
    yyaxis left
    hEB = errorbar(visits, ratio_mean, ratio_std, 'o-', ...
        'Color', [0.15 0.25 0.7], 'MarkerSize', 6, 'MarkerFaceColor', [0.3 0.5 0.9], ...
        'LineWidth', 1.8, 'CapSize', 4, 'DisplayName', 'L4/L5 Ratio (Mean \pm Std)');
    ylabel('L4 / L5 Contrast Ratio (\sigma / \mu)', 'FontSize', 11, 'FontWeight', 'bold');
    ylim(yLimsLeft);

    % Right Axis: Central Retinal Thickness (OD)
    yyaxis right
    hTh = plot(visits, th_OD, 's--', ...
        'Color', [0.85 0.3 0.1], 'MarkerSize', 6, 'MarkerFaceColor', [1 0.6 0.3], ...
        'LineWidth', 1.5, 'DisplayName', 'Central Thickness OD (\mum)');
    ylabel('Central Thickness (\mum)', 'FontSize', 11, 'FontWeight', 'bold');
    yLimitsRight = [min(th_OD(~isnan(th_OD)))-30, max(th_OD(~isnan(th_OD)))+40];
    ylim(yLimitsRight);

    title('Temporal Evolution: Retinal Speckle Ratio vs. Anatomical Thickness', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Clinical Visit Number', 'FontSize', 11);
    xlim(xLimits);
    xticks(visits);
    grid on; box on;
    legend([hEB, hTh], {'L4/L5 Ratio (\pm \sigma)', 'Central Thickness OD'}, 'Location', 'northwest');

    %% Subplot 2: Rate of Change (\Delta Ratio / \Delta t in days)
    subplot(2, 1, 2);
    hold on;

    % Zero line
    plot(xLimits, [0 0], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');

    % Rate of Change bars
    validRoc = ~isnan(roc_mean);
    barColors = zeros(length(visits), 3);
    for b = 1:length(visits)
        if roc_mean(b) >= 0
            barColors(b, :) = [0.2 0.7 0.3]; % Green for increasing ratio (recovery)
        else
            barColors(b, :) = [0.85 0.2 0.2]; % Red for declining ratio (deterioration)
        end
    end

    bHandle = bar(visits, roc_mean, 0.6, 'FaceColor', 'flat');
    bHandle.CData = barColors;

    ylabel('\Delta Ratio / \Delta Day', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Clinical Visit Number', 'FontSize', 11);
    title('Rate of Change: Velocity of Speckle Transition Across Visits', 'FontSize', 12, 'FontWeight', 'bold');
    xlim(xLimits);
    xticks(visits);
    grid on; box on;

    % Add visit dates as secondary ticks / labels below
    dateLabels = cellstr(datestr(dates, 'dd-mmm-yy'));
    set(gca, 'XTickLabel', dateLabels, 'XTickLabelRotation', 45);

    if ~isempty(savePath)
        saveas(hFig, savePath);
        fprintf('Saved longitudinal figure to: %s\n', savePath);
    end
end

%% 4. Print Summary Report
function reportStr = print_stats_report()
    Summary = db_manager('get_summary');
    corrs = compute_correlations();

    reportLines = {};
    reportLines{end+1} = sprintf('========================================================================');
    reportLines{end+1} = sprintf('                 OCT LONGITUDINAL CLINICAL STUDY REPORT                 ');
    reportLines{end+1} = sprintf('========================================================================');
    reportLines{end+1} = sprintf('Patient Code: CSCR_M_011 | Total Visits: %d', height(Summary));
    reportLines{end+1} = sprintf('Study Duration: %s to %s', ...
        datestr(min(Summary.VisitDate), 'yyyy-mm-dd'), datestr(max(Summary.VisitDate), 'yyyy-mm-dd'));
    reportLines{end+1} = sprintf('------------------------------------------------------------------------');
    reportLines{end+1} = sprintf('Visit | Date       | Days | Thickness OD | Mean L4/L5 | Std L4/L5 | Rate/Day');
    reportLines{end+1} = sprintf('------------------------------------------------------------------------');

    for i = 1:height(Summary)
        v = Summary.VisitNum(i);
        d = datestr(Summary.VisitDate(i), 'yyyy-mm-dd');
        daysBase = Summary.DaysFromBaseline(i);
        th = Summary.CentralThickness_OD(i);
        mR = Summary.Mean_Ratio_Left_L4_L5(i);
        sR = Summary.Std_Ratio_Left_L4_L5(i);
        roc = Summary.Mean_RateOfChange_Left(i);

        reportLines{end+1} = sprintf('%5d | %s | %4.0f |    %5.0f um  |   %7.4f  |  %7.4f  | %+8.5f', ...
            v, d, daysBase, th, mR, sR, roc);
    end

    reportLines{end+1} = sprintf('------------------------------------------------------------------------');
    reportLines{end+1} = sprintf('KEY CORRELATIONS:');
    reportLines{end+1} = sprintf('  Pearson r (Thickness vs L4/L5 Ratio): %.4f (p = %.4e)', corrs.Pearson_r, corrs.Pearson_p);
    reportLines{end+1} = sprintf('  Spearman rho:                         %.4f (p = %.4e)', corrs.Spearman_rho, corrs.Spearman_p);
    reportLines{end+1} = sprintf('========================================================================\n');

    reportStr = strjoin(reportLines, '\n');
    disp(reportStr);
end
