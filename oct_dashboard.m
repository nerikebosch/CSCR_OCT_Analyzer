function oct_dashboard()
% OCT_DASHBOARD Interactive MATLAB UI Dashboard for Longitudinal OCT Analysis.
% Displays temporal evolution of speckle contrast ratios (L4/L5), rates of change,
% central retinal thickness, and clinical correlations for patient CSCR_M_011.
%
% USAGE:
%   oct_dashboard()

    % Ensure DB is initialized
    db_manager('init');

    % Create Main Window
    fig = uifigure('Name', 'OCT Clinical Study Dashboard | CSCR Longitudinal Study', ...
                   'Position', [80, 60, 1280, 780], ...
                   'Color', [0.95 0.96 0.98]);

    % Main Layout Grid: 2 rows (Header, Content)
    mainGrid = uigridlayout(fig, [2, 1]);
    mainGrid.RowHeight = {55, '1x'};
    mainGrid.Padding = [10, 10, 10, 10];
    mainGrid.RowSpacing = 8;

    %% 1. Header Bar
    headerPanel = uipanel(mainGrid, 'BackgroundColor', [0.15 0.22 0.35], 'BorderType', 'none');
    headerGrid = uigridlayout(headerPanel, [1, 5]);
    headerGrid.ColumnWidth = {'1x', 140, 130, 110, 110};
    headerGrid.Padding = [12, 6, 12, 6];

    titleLabel = uilabel(headerGrid, ...
        'Text', 'OCT Clinical Study Dashboard  |  Patient CSCR_M_011', ...
        'FontSize', 16, 'FontWeight', 'bold', 'FontColor', [1 1 1]);

    btnProcess = uibutton(headerGrid, 'push', ...
        'Text', '+ Process Folder', ...
        'BackgroundColor', [0.2 0.6 0.35], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_process_folder());

    btnExport = uibutton(headerGrid, 'push', ...
        'Text', 'Export Excel', ...
        'BackgroundColor', [0.25 0.45 0.7], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_export_excel());

    btnReport = uibutton(headerGrid, 'push', ...
        'Text', 'Print Report', ...
        'BackgroundColor', [0.4 0.4 0.5], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) compute_statistics('report'));

    btnRefresh = uibutton(headerGrid, 'push', ...
        'Text', 'Refresh', ...
        'BackgroundColor', [0.3 0.35 0.45], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) refresh_all_data());

    %% 2. Content Area Grid (Left: Sidebar, Right: Tabs)
    contentGrid = uigridlayout(mainGrid, [1, 2]);
    contentGrid.ColumnWidth = {330, '1x'};
    contentGrid.Padding = [0, 0, 0, 0];
    contentGrid.ColumnSpacing = 10;

    %% Left Sidebar: Visit Details & Editor
    sidePanel = uipanel(contentGrid, 'Title', 'Visit & Clinical Details', ...
                        'FontSize', 12, 'FontWeight', 'bold', ...
                        'BackgroundColor', [1 1 1]);
    sideGrid = uigridlayout(sidePanel, [12, 2]);
    sideGrid.RowHeight = {28, 28, 28, 28, 28, 28, 55, 32, 24, '1x', 32, 22};
    sideGrid.ColumnWidth = {110, '1x'};
    sideGrid.Padding = [10, 10, 10, 10];
    sideGrid.RowSpacing = 6;

    % Visit Selector
    uilabel(sideGrid, 'Text', 'Select Visit:', 'FontWeight', 'bold');
    ddVisit = uidropdown(sideGrid, 'Items', {'Visit 1'}, 'ValueChangedFcn', @(~,~) on_visit_selected());

    % Visit Date
    uilabel(sideGrid, 'Text', 'Visit Date:');
    lblDate = uilabel(sideGrid, 'Text', '2024-06-03', 'FontColor', [0.2 0.3 0.6], 'FontWeight', 'bold');

    % Days from Baseline
    uilabel(sideGrid, 'Text', 'Days from Base:');
    lblDays = uilabel(sideGrid, 'Text', '0 days');

    % Central Thickness OD
    uilabel(sideGrid, 'Text', 'Thickness OD (\mum):');
    efThicknessOD = uieditfield(sideGrid, 'numeric', 'Value', 282, 'RoundFractionalValues', 'on');

    % Central Thickness OS
    uilabel(sideGrid, 'Text', 'Thickness OS (\mum):');
    efThicknessOS = uieditfield(sideGrid, 'numeric', 'Value', 248, 'RoundFractionalValues', 'on');

    % Clinical Status
    uilabel(sideGrid, 'Text', 'Clinical State:');
    lblStatus = uilabel(sideGrid, 'Text', 'Remission', 'FontWeight', 'bold', 'FontColor', [0.1 0.6 0.2]);

    % Notes
    uilabel(sideGrid, 'Text', 'Clinical Notes:');
    taNotes = uitextarea(sideGrid, 'Value', {''});

    % Save Visit Button
    btnSaveVisit = uibutton(sideGrid, 'push', ...
        'Text', 'Save Visit Changes', ...
        'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) on_save_visit());
    btnSaveVisit.Layout.Column = [1 2];

    % Slice Table Header
    lblSliceHeader = uilabel(sideGrid, 'Text', 'Image Slices for Selected Visit:', 'FontWeight', 'bold');
    lblSliceHeader.Layout.Column = [1 2];

    % Slice Mini Table
    tblSlices = uitable(sideGrid, 'Data', table(), 'FontSize', 10);
    tblSlices.Layout.Column = [1 2];

    % Add New Visit Button
    btnAddVisit = uibutton(sideGrid, 'push', ...
        'Text', '+ Add New Visit (e.g. Visit 23)', ...
        'BackgroundColor', [0.3 0.5 0.35], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) on_add_new_visit());
    btnAddVisit.Layout.Column = [1 2];

    lblDbStatus = uilabel(sideGrid, 'Text', 'Database: Connected', 'FontSize', 9, 'FontColor', [0.4 0.4 0.4]);
    lblDbStatus.Layout.Column = [1 2];

    %% Right Area: Tab Group
    tabGroup = uitabgroup(contentGrid);

    % Tab 1: Longitudinal Trends
    tabTrends = uitab(tabGroup, 'Title', 'Longitudinal Trends & Evolution');
    gridTrends = uigridlayout(tabTrends, [3, 1]);
    gridTrends.RowHeight = {30, '1x', '1x'};
    gridTrends.Padding = [8, 8, 8, 8];
    gridTrends.RowSpacing = 6;

    % Controls row for Tab 1
    tControlsPanel = uipanel(gridTrends, 'BorderType', 'none');
    tControlsGrid = uigridlayout(tControlsPanel, [1, 4]);
    tControlsGrid.ColumnWidth = {180, 200, 160, '1x'};
    tControlsGrid.Padding = [0, 0, 0, 0];

    cbZones = uicheckbox(tControlsGrid, 'Text', 'Show Clinical Zones', 'Value', true, ...
                         'ValueChangedFcn', @(~,~) render_longitudinal_plot());
    cbThickness = uicheckbox(tControlsGrid, 'Text', 'Overlay Central Thickness (OD)', 'Value', true, ...
                            'ValueChangedFcn', @(~,~) render_longitudinal_plot());
    cbErrorBars = uicheckbox(tControlsGrid, 'Text', 'Show Error Bars (\pm \sigma)', 'Value', true, ...
                            'ValueChangedFcn', @(~,~) render_longitudinal_plot());

    % Axes 1: Dual Axis Plot (L4/L5 Ratio vs Central Thickness)
    axEvolution = uiaxes(gridTrends);
    axEvolution.FontSize = 10;

    % Axes 2: Rate of Change Bar Chart
    axVelocity = uiaxes(gridTrends);
    axVelocity.FontSize = 10;

    % Tab 2: Clinical Correlations
    tabCorr = uitab(tabGroup, 'Title', 'Thickness vs. Speckle Correlations');
    gridCorr = uigridlayout(tabCorr, [2, 1]);
    gridCorr.RowHeight = {'1x', 140};
    gridCorr.Padding = [10, 10, 10, 10];

    axCorr = uiaxes(gridCorr);
    axCorr.FontSize = 11;

    panelCorrSummary = uipanel(gridCorr, 'Title', 'Correlation Analysis Findings', 'FontSize', 11, 'FontWeight', 'bold');
    gridCorrText = uigridlayout(panelCorrSummary, [2, 3]);
    gridCorrText.RowHeight = {28, 28};
    gridCorrText.ColumnWidth = {'1x', '1x', '1x'};

    lblPearson = uilabel(gridCorrText, 'Text', 'Pearson r: --', 'FontWeight', 'bold', 'FontSize', 12);
    lblSpearman = uilabel(gridCorrText, 'Text', 'Spearman \rho: --', 'FontWeight', 'bold', 'FontSize', 12);
    lblR2 = uilabel(gridCorrText, 'Text', 'Linear R^2: --', 'FontWeight', 'bold', 'FontSize', 12);

    lblSignif = uilabel(gridCorrText, 'Text', 'Significance: --', 'FontColor', [0.2 0.5 0.2], 'FontWeight', 'bold');
    lblAnalyzedN = uilabel(gridCorrText, 'Text', 'Analyzed Visits: --');
    uilabel(gridCorrText, 'Text', 'Condition: CSCR Flare vs Remission', 'FontColor', [0.4 0.4 0.4]);

    % Tab 3: Complete Database Table View
    tabTable = uitab(tabGroup, 'Title', 'All Visits Data Table');
    gridTable = uigridlayout(tabTable, [1, 1]);
    gridTable.Padding = [8, 8, 8, 8];
    tblAllVisits = uitable(gridTable, 'FontSize', 10);
    tblAllVisits.CellSelectionCallback = @(~, e) on_table_cell_selected(e);

    %% Initialize & Load Data
    SummaryData = [];
    VisitsData  = [];
    ScansData   = [];

    refresh_all_data();

    %% Nested Event Callbacks

    function refresh_all_data()
        compute_statistics('update_all');
        SummaryData = db_manager('get_summary');
        VisitsData  = db_manager('get_visits');
        ScansData   = db_manager('get_scans');

        if isempty(SummaryData)
            uialert(fig, 'No study data found in database. Please run migrate_excel_to_db.', 'Empty Database');
            return;
        end

        % Update Visit Dropdown
        visitItems = cell(height(VisitsData), 1);
        for v = 1:height(VisitsData)
            visitItems{v} = sprintf('Visit %d (%s)', ...
                VisitsData.VisitNum(v), datestr(VisitsData.VisitDate(v), 'yyyy-mm-dd'));
        end
        ddVisit.Items = visitItems;

        % Default to last visit
        ddVisit.Value = visitItems{end};
        on_visit_selected();

        % Render Visualizations
        render_longitudinal_plot();
        render_correlation_plot();
        render_all_visits_table();

        lblDbStatus.Text = sprintf('Database: %d Visits | %d Scans | Updated %s', ...
            height(VisitsData), height(ScansData), datestr(now, 'HH:MM:SS'));
    end

    function on_visit_selected()
        if isempty(VisitsData), return; end
        vIdx = ddVisit.Value;
        tok = regexp(vIdx, 'Visit (\d+)', 'tokens');
        if isempty(tok), return; end
        currVisitNum = str2double(tok{1}{1});

        rowIdx = find(VisitsData.VisitNum == currVisitNum, 1);
        if isempty(rowIdx), return; end

        vRow = VisitsData(rowIdx, :);
        lblDate.Text = datestr(vRow.VisitDate, 'yyyy-mm-dd');
        lblDays.Text = sprintf('%.0f days', vRow.DaysFromBaseline);
        efThicknessOD.Value = vRow.CentralThickness_OD;
        efThicknessOS.Value = vRow.CentralThickness_OS;
        taNotes.Value = {char(vRow.Notes)};

        % Status badge based on thickness OD
        th = vRow.CentralThickness_OD;
        if th >= 400
            lblStatus.Text = 'Active Flare-up (Edema)';
            lblStatus.FontColor = [0.85 0.2 0.2];
        elseif th >= 300
            lblStatus.Text = 'Pre-recurrence / Mild';
            lblStatus.FontColor = [0.8 0.5 0.1];
        else
            lblStatus.Text = 'Remission / Normal';
            lblStatus.FontColor = [0.15 0.6 0.2];
        end

        % Slices mini-table
        subScans = ScansData(ScansData.VisitNum == currVisitNum & ScansData.EyeSide == "OD", :);
        if ~isempty(subScans)
            displayTbl = table(subScans.ImageIndex, subScans.Ratio_Left_L4_L5, subScans.RateOfChange_Left, ...
                'VariableNames', {'Slice', 'Left_L4_L5', 'RateOfChange'});
            tblSlices.Data = displayTbl;
        else
            tblSlices.Data = table();
        end
    end

    function on_save_visit()
        tok = regexp(ddVisit.Value, 'Visit (\d+)', 'tokens');
        if isempty(tok), return; end
        vNum = str2double(tok{1}{1});

        rowIdx = find(VisitsData.VisitNum == vNum, 1);
        if isempty(rowIdx), return; end

        vStruct = struct();
        vStruct.VisitNum = vNum;
        vStruct.VisitDate = VisitsData.VisitDate(rowIdx);
        vStruct.CentralThickness_OD = efThicknessOD.Value;
        vStruct.CentralThickness_OS = efThicknessOS.Value;
        notesCell = taNotes.Value;
        vStruct.Notes = strjoin(notesCell, ' ');

        db_manager('save_visit', vStruct);
        refresh_all_data();
        uialert(fig, sprintf('Successfully saved updates for Visit %d.', vNum), 'Saved', 'Icon', 'success');
    end

    function on_add_new_visit()
        nextNum = max(VisitsData.VisitNum) + 1;
        prompt = {sprintf('Enter Visit Number [Default: %d]:', nextNum), ...
                  'Enter Visit Date (YYYY-MM-DD):', ...
                  'Central Thickness OD (um):', ...
                  'Central Thickness OS (um):', ...
                  'Clinical Notes:'};
        dlgtitle = 'Add New Clinical Visit';
        dims = [1 45];
        definput = {num2str(nextNum), datestr(today, 'yyyy-mm-dd'), '300', '250', ''};
        answer = inputdlg(prompt, dlgtitle, dims, definput);

        if isempty(answer), return; end

        try
            newV = struct();
            newV.VisitNum = str2double(answer{1});
            newV.VisitDate = datetime(answer{2}, 'InputFormat', 'yyyy-MM-dd');
            newV.CentralThickness_OD = str2double(answer{3});
            newV.CentralThickness_OS = str2double(answer{4});
            newV.Notes = answer{5};

            db_manager('save_visit', newV);
            refresh_all_data();
            uialert(fig, sprintf('Visit #%d added to database!', newV.VisitNum), 'Success', 'Icon', 'success');
        catch ME
            uialert(fig, sprintf('Failed to add visit: %s', ME.message), 'Error', 'Icon', 'error');
        end
    end

    function on_process_folder()
        fPath = uigetdir('', 'Select OCT scan folder for a visit');
        if fPath == 0, return; end

        d = uiprogressdlg(fig, 'Title', 'Processing OCT Scans', ...
                          'Message', 'Running SAM segmentation pipeline...', ...
                          'Indeterminate', 'on');
        try
            opts = struct('plotoption', 0);
            vNum = process_oct_folder(fPath, opts);
            close(d);
            refresh_all_data();
            uialert(fig, sprintf('Folder processed successfully and assigned to Visit #%d!', vNum), ...
                    'Complete', 'Icon', 'success');
        catch ME
            close(d);
            uialert(fig, sprintf('Scan processing failed: %s', ME.message), 'Processing Error', 'Icon', 'error');
        end
    end

    function on_export_excel()
        [file, path] = uiputfile('*.xlsx', 'Save Consolidated Study Excel Report', 'OCT_Study_Export.xlsx');
        if file == 0, return; end
        fullP = fullfile(path, file);
        db_manager('export_excel', fullP);
        uialert(fig, sprintf('Excel report exported to: %s', fullP), 'Export Complete', 'Icon', 'success');
    end

    function on_table_cell_selected(e)
        if isempty(e.Indices), return; end
        selRow = e.Indices(1);
        if selRow <= length(ddVisit.Items)
            ddVisit.Value = ddVisit.Items{selRow};
            on_visit_selected();
        end
    end

    %% Visual Rendering Functions

    function render_longitudinal_plot()
        if isempty(SummaryData), return; end

        cla(axEvolution);
        cla(axVelocity);

        visits = SummaryData.VisitNum;
        dates  = SummaryData.VisitDate;
        ratio_mean = SummaryData.Mean_Ratio_Left_L4_L5;
        ratio_std  = SummaryData.Std_Ratio_Left_L4_L5;
        th_OD  = SummaryData.CentralThickness_OD;
        roc    = SummaryData.Mean_RateOfChange_Left;

        ratio_std(isnan(ratio_std)) = 0;
        xLimits = [min(visits)-0.5, max(visits)+0.5];

        hold(axEvolution, 'on');

        % 1. Background Clinical Bands
        if cbZones.Value
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.4, 0.4, 0.75, 0.75], ...
                [1 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.75, 0.75, 0.95, 0.95], ...
                [1 1 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
            patch(axEvolution, [xLimits(1), xLimits(2), xLimits(2), xLimits(1)], [0.95, 0.95, 1.4, 1.4], ...
                [0.9 1 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
        end

        % 2. Left Axis: L4/L5 Ratio
        yyaxis(axEvolution, 'left');
        if cbErrorBars.Value
            hEB = errorbar(axEvolution, visits, ratio_mean, ratio_std, 'o-', ...
                'Color', [0.15 0.3 0.75], 'MarkerSize', 6, 'MarkerFaceColor', [0.35 0.55 0.95], ...
                'LineWidth', 1.8, 'CapSize', 4, 'DisplayName', 'L4/L5 Ratio');
        else
            hEB = plot(axEvolution, visits, ratio_mean, 'o-', ...
                'Color', [0.15 0.3 0.75], 'MarkerSize', 6, 'MarkerFaceColor', [0.35 0.55 0.95], ...
                'LineWidth', 1.8, 'DisplayName', 'L4/L5 Ratio');
        end
        ylabel(axEvolution, 'L4 / L5 Contrast Ratio (\sigma / \mu)', 'FontWeight', 'bold');
        ylim(axEvolution, [0.4, 1.4]);

        % 3. Right Axis: Central Thickness OD
        yyaxis(axEvolution, 'right');
        if cbThickness.Value
            validTh = ~isnan(th_OD);
            plot(axEvolution, visits(validTh), th_OD(validTh), 's--', ...
                'Color', [0.85 0.35 0.1], 'MarkerSize', 6, 'MarkerFaceColor', [1 0.65 0.35], ...
                'LineWidth', 1.5, 'DisplayName', 'Central Thickness OD');
            ylabel(axEvolution, 'Central Thickness (\mum)', 'FontWeight', 'bold');
            ylim(axEvolution, [min(th_OD(validTh))-30, max(th_OD(validTh))+40]);
        else
            ylabel(axEvolution, '');
            set(axEvolution, 'YTick', []);
        end

        title(axEvolution, 'Temporal Evolution: Retinal Speckle Ratio vs. Central Retinal Thickness', 'FontWeight', 'bold');
        xlim(axEvolution, xLimits);
        xticks(axEvolution, visits);
        grid(axEvolution, 'on');
        legend(axEvolution, 'Location', 'northwest');
        hold(axEvolution, 'off');

        % 4. Rate of Change Velocity Bar Chart (Bottom Axes)
        hold(axVelocity, 'on');
        plot(axVelocity, xLimits, [0 0], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');

        barColors = zeros(length(visits), 3);
        for b = 1:length(visits)
            if roc(b) >= 0
                barColors(b, :) = [0.2 0.7 0.3];
            else
                barColors(b, :) = [0.85 0.25 0.25];
            end
        end

        bHandle = bar(axVelocity, visits, roc, 0.6, 'FaceColor', 'flat');
        bHandle.CData = barColors;

        ylabel(axVelocity, '\Delta Ratio / \Delta Day', 'FontWeight', 'bold');
        xlabel(axVelocity, 'Clinical Visit Date', 'FontWeight', 'bold');
        title(axVelocity, 'Rate of Change Velocity: Transition Speed Across Clinical Visits', 'FontWeight', 'bold');
        xlim(axVelocity, xLimits);
        xticks(axVelocity, visits);

        dateLabels = cellstr(datestr(dates, 'dd-mmm-yy'));
        set(axVelocity, 'XTickLabel', dateLabels, 'XTickLabelRotation', 40);
        grid(axVelocity, 'on');
        hold(axVelocity, 'off');
    end

    function render_correlation_plot()
        if isempty(SummaryData), return; end
        cla(axCorr);
        corrs = compute_statistics('correlations');

        valid = ~isnan(SummaryData.CentralThickness_OD) & ~isnan(SummaryData.Mean_Ratio_Left_L4_L5);
        xTh = SummaryData.CentralThickness_OD(valid);
        yRatio = SummaryData.Mean_Ratio_Left_L4_L5(valid);

        hold(axCorr, 'on');
        scatter(axCorr, xTh, yRatio, 55, [0.2 0.4 0.75], 'filled', 'MarkerEdgeColor', 'k');

        % Fit line
        p = polyfit(xTh, yRatio, 1);
        xLine = linspace(min(xTh)-20, max(xTh)+20, 100);
        yLine = polyval(p, xLine);
        plot(axCorr, xLine, yLine, 'r-', 'LineWidth', 1.8);

        xlabel(axCorr, 'Central Retinal Thickness OD (\mum)', 'FontWeight', 'bold');
        ylabel(axCorr, 'Mean L4 / L5 Contrast Ratio', 'FontWeight', 'bold');
        title(axCorr, sprintf('Scatter Correlation: Central Thickness vs. L4/L5 Ratio (r = %.3f, R^2 = %.3f)', ...
            corrs.Pearson_r, corrs.R_squared), 'FontWeight', 'bold');
        grid(axCorr, 'on');
        box(axCorr, 'on');
        hold(axCorr, 'off');

        % Update metrics card
        lblPearson.Text  = sprintf('Pearson r: %.4f (p = %.3e)', corrs.Pearson_r, corrs.Pearson_p);
        lblSpearman.Text = sprintf('Spearman \\rho: %.4f (p = %.3e)', corrs.Spearman_rho, corrs.Spearman_p);
        lblR2.Text       = sprintf('Linear R^2: %.4f', corrs.R_squared);
        lblAnalyzedN.Text= sprintf('Analyzed Visits: %d of %d', corrs.N, height(SummaryData));

        if corrs.Pearson_p < 0.05
            lblSignif.Text = 'Significance: Statistically Significant (p < 0.05)';
            lblSignif.FontColor = [0.15 0.6 0.2];
        else
            lblSignif.Text = 'Significance: Trend only (p >= 0.05)';
            lblSignif.FontColor = [0.7 0.4 0.1];
        end
    end

    function render_all_visits_table()
        if isempty(SummaryData), return; end
        displayT = SummaryData(:, {'VisitNum', 'VisitDate', 'DaysFromBaseline', ...
                                  'CentralThickness_OD', 'CentralThickness_OS', ...
                                  'Mean_Ratio_Left_L4_L5', 'Std_Ratio_Left_L4_L5', ...
                                  'Mean_RateOfChange_Left', 'Notes'});
        tblAllVisits.Data = displayT;
    end
end
