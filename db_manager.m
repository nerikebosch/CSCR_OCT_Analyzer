function varargout = db_manager(action, varargin)
% DB_MANAGER Centralized local database interface for OCT Retinal Scan Analysis.
% Manages structured persistent storage in 'oct_study_db.mat' without requiring
% external database servers or additional MATLAB toolboxes.
%
% USAGE:
%   db_manager('init')                         - Initializes empty or verifies DB.
%   db_manager('save_visit', visitData)        - Saves or updates a visit record.
%   db_manager('save_scan', scanData)          - Saves or updates a scan record.
%   visits = db_manager('get_visits')          - Returns table of all visits.
%   scans  = db_manager('get_scans')           - Returns table of all scans.
%   scans  = db_manager('get_scans', visitNum) - Returns scans for a specific visit.
%   stats  = db_manager('get_summary')         - Returns aggregated visit-level stats.
%   db_manager('export_csv', outputDir)        - Exports tables as CSV files.
%   db_manager('export_excel', excelPath)      - Exports tables to multi-sheet Excel.

    defaultDbPath = fullfile(fileparts(mfilename('fullpath')), 'oct_study_db.mat');

    switch lower(action)
        case 'init'
            dbPath = defaultDbPath;
            if ~isempty(varargin) && ~isempty(varargin{1})
                dbPath = varargin{1};
            end
            out = init_db(dbPath);
            if nargout > 0, varargout{1} = out; end

        case 'save_visit'
            visitData = varargin{1};
            save_visit_record(defaultDbPath, visitData);

        case 'save_scan'
            scanData = varargin{1};
            save_scan_record(defaultDbPath, scanData);

        case 'get_visits'
            varargout{1} = get_visits_table(defaultDbPath);

        case 'get_scans'
            visitNum = [];
            if ~isempty(varargin)
                visitNum = varargin{1};
            end
            varargout{1} = get_scans_table(defaultDbPath, visitNum);

        case 'get_summary'
            varargout{1} = get_summary_table(defaultDbPath);

        case 'export_csv'
            outDir = fullfile(fileparts(mfilename('fullpath')), 'db_export');
            if ~isempty(varargin) && ~isempty(varargin{1})
                outDir = varargin{1};
            end
            export_csv_tables(defaultDbPath, outDir);

        case 'export_excel'
            excelPath = fullfile(fileparts(mfilename('fullpath')), 'oct_study_export.xlsx');
            if ~isempty(varargin) && ~isempty(varargin{1})
                excelPath = varargin{1};
            end
            export_excel_tables(defaultDbPath, excelPath);

        case 'db_path'
            varargout{1} = defaultDbPath;

        otherwise
            error('Unknown db_manager action: %s', action);
    end
end

%% Internal DB Functions

function DB = init_db(dbPath)
    if isfile(dbPath)
        data = load(dbPath);
        DB = data.DB;
        fprintf('Loaded existing OCT Study Database from: %s\n', dbPath);
        return;
    end

    % Create empty typed tables
    Visits = table( ...
        zeros(0,1,'int32'), ...       % VisitNum
        datetime.empty(0,1), ...      % VisitDate
        zeros(0,1,'double'), ...      % DaysFromBaseline
        zeros(0,1,'double'), ...      % CentralThickness_OD
        zeros(0,1,'double'), ...      % CentralThickness_OS
        strings(0,1), ...             % Notes
        'VariableNames', {'VisitNum', 'VisitDate', 'DaysFromBaseline', ...
                          'CentralThickness_OD', 'CentralThickness_OS', 'Notes'});

    Scans = table( ...
        zeros(0,1,'int32'), ...       % ScanID
        zeros(0,1,'int32'), ...       % VisitNum
        zeros(0,1,'int32'), ...       % ImageIndex (1, 2, 3)
        strings(0,1), ...             % EyeSide ('OD' or 'OS')
        strings(0,1), ...             % FileName
        zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), ... % ROI_Right_L1..L5
        zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), ... % ROI_Left_L1..L5
        zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), ... % ROI_Full_L1..L5
        zeros(0,1,'double'), ...      % Ratio_Left_L4_L5
        zeros(0,1,'double'), ...      % Ratio_Right_L4_L5
        zeros(0,1,'double'), ...      % RateOfChange_Left
        zeros(0,1,'double'), ...      % RateOfChange_Right
        'VariableNames', {'ScanID', 'VisitNum', 'ImageIndex', 'EyeSide', 'FileName', ...
                          'ROI_Right_L1', 'ROI_Right_L2', 'ROI_Right_L3', 'ROI_Right_L4', 'ROI_Right_L5', ...
                          'ROI_Left_L1',  'ROI_Left_L2',  'ROI_Left_L3',  'ROI_Left_L4',  'ROI_Left_L5', ...
                          'ROI_Full_L1',  'ROI_Full_L2',  'ROI_Full_L3',  'ROI_Full_L4',  'ROI_Full_L5', ...
                          'Ratio_Left_L4_L5', 'Ratio_Right_L4_L5', ...
                          'RateOfChange_Left', 'RateOfChange_Right'});

    DB = struct('Visits', Visits, 'Scans', Scans, 'Created', datetime('now'), 'Version', '1.0');
    save(dbPath, 'DB', '-v7.3');
    fprintf('Created new OCT Study Database at: %s\n', dbPath);
end

function save_visit_record(dbPath, v)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Visits = data.DB.Visits;

    % Normalize input values
    vNum = int32(v.VisitNum);
    vDate = v.VisitDate;
    if ~isa(vDate, 'datetime')
        vDate = datetime(vDate, 'InputFormat', 'yyyy-MM-dd');
    end

    thOD = NaN; if isfield(v, 'CentralThickness_OD') && ~isempty(v.CentralThickness_OD), thOD = double(v.CentralThickness_OD); end
    thOS = NaN; if isfield(v, 'CentralThickness_OS') && ~isempty(v.CentralThickness_OS), thOS = double(v.CentralThickness_OS); end
    notesStr = ""; if isfield(v, 'Notes') && ~isempty(v.Notes), notesStr = string(v.Notes); end

    % Compute days from baseline
    daysFromBase = 0;
    if ~isempty(Visits)
        baseDate = min(Visits.VisitDate);
        if vDate < baseDate
            baseDate = vDate;
        end
        daysFromBase = double(days(vDate - baseDate));
    end

    % Update if exists or append
    idx = find(Visits.VisitNum == vNum, 1);
    if isempty(idx)
        newRow = table(vNum, vDate, daysFromBase, thOD, thOS, notesStr, ...
            'VariableNames', {'VisitNum', 'VisitDate', 'DaysFromBaseline', ...
                              'CentralThickness_OD', 'CentralThickness_OS', 'Notes'});
        Visits = [Visits; newRow];
    else
        Visits.VisitDate(idx) = vDate;
        Visits.DaysFromBaseline(idx) = daysFromBase;
        Visits.CentralThickness_OD(idx) = thOD;
        Visits.CentralThickness_OS(idx) = thOS;
        Visits.Notes(idx) = notesStr;
    end

    % Re-sort by visit number and recalculate days from baseline
    Visits = sortrows(Visits, 'VisitNum');
    baseDate = Visits.VisitDate(1);
    Visits.DaysFromBaseline = double(days(Visits.VisitDate - baseDate));

    data.DB.Visits = Visits;
    save(dbPath, '-struct', 'data', '-v7.3');
end

function save_scan_record(dbPath, s)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Scans = data.DB.Scans;

    vNum = int32(s.VisitNum);
    imgIdx = int32(s.ImageIndex);
    eyeSide = "OD"; if isfield(s, 'EyeSide') && ~isempty(s.EyeSide), eyeSide = string(s.EyeSide); end
    fn = ""; if isfield(s, 'FileName') && ~isempty(s.FileName), fn = string(s.FileName); end

    % Helper to extract ROI field
    getCR = @(f) double(get_field_default(s, f, NaN));

    r_r1 = getCR('ROI_Right_L1'); r_r2 = getCR('ROI_Right_L2');
    r_r3 = getCR('ROI_Right_L3'); r_r4 = getCR('ROI_Right_L4'); r_r5 = getCR('ROI_Right_L5');

    r_l1 = getCR('ROI_Left_L1');  r_l2 = getCR('ROI_Left_L2');
    r_l3 = getCR('ROI_Left_L3');  r_l4 = getCR('ROI_Left_L4');  r_l5 = getCR('ROI_Left_L5');

    r_f1 = getCR('ROI_Full_L1');  r_f2 = getCR('ROI_Full_L2');
    r_f3 = getCR('ROI_Full_L3');  r_f4 = getCR('ROI_Full_L4');  r_f5 = getCR('ROI_Full_L5');

    % Ratios
    ratio_l = NaN;
    if ~isnan(r_l4) && ~isnan(r_l5) && r_l5 ~= 0
        ratio_l = r_l4 / r_l5;
    end
    if isfield(s, 'Ratio_Left_L4_L5') && ~isempty(s.Ratio_Left_L4_L5) && ~isnan(s.Ratio_Left_L4_L5)
        ratio_l = double(s.Ratio_Left_L4_L5);
    end

    ratio_r = NaN;
    if ~isnan(r_r4) && ~isnan(r_r5) && r_r5 ~= 0
        ratio_r = r_r4 / r_r5;
    end
    if isfield(s, 'Ratio_Right_L4_L5') && ~isempty(s.Ratio_Right_L4_L5) && ~isnan(s.Ratio_Right_L4_L5)
        ratio_r = double(s.Ratio_Right_L4_L5);
    end

    roc_l = getCR('RateOfChange_Left');
    roc_r = getCR('RateOfChange_Right');

    % Check if record exists for this (VisitNum, ImageIndex, EyeSide)
    idx = find(Scans.VisitNum == vNum & Scans.ImageIndex == imgIdx & Scans.EyeSide == eyeSide, 1);
    if isempty(idx)
        scanID = int32(height(Scans) + 1);
        newRow = table(scanID, vNum, imgIdx, eyeSide, fn, ...
            r_r1, r_r2, r_r3, r_r4, r_r5, ...
            r_l1, r_l2, r_l3, r_l4, r_l5, ...
            r_f1, r_f2, r_f3, r_f4, r_f5, ...
            ratio_l, ratio_r, roc_l, roc_r, ...
            'VariableNames', Scans.Properties.VariableNames);
        Scans = [Scans; newRow];
    else
        Scans.FileName(idx) = fn;
        Scans.ROI_Right_L1(idx) = r_r1; Scans.ROI_Right_L2(idx) = r_r2;
        Scans.ROI_Right_L3(idx) = r_r3; Scans.ROI_Right_L4(idx) = r_r4; Scans.ROI_Right_L5(idx) = r_r5;
        Scans.ROI_Left_L1(idx) = r_l1;   Scans.ROI_Left_L2(idx) = r_l2;
        Scans.ROI_Left_L3(idx) = r_l3;   Scans.ROI_Left_L4(idx) = r_l4;   Scans.ROI_Left_L5(idx) = r_l5;
        Scans.ROI_Full_L1(idx) = r_f1;   Scans.ROI_Full_L2(idx) = r_f2;
        Scans.ROI_Full_L3(idx) = r_f3;   Scans.ROI_Full_L4(idx) = r_f4;   Scans.ROI_Full_L5(idx) = r_f5;
        Scans.Ratio_Left_L4_L5(idx) = ratio_l;
        Scans.Ratio_Right_L4_L5(idx) = ratio_r;
        Scans.RateOfChange_Left(idx) = roc_l;
        Scans.RateOfChange_Right(idx) = roc_r;
    end

    Scans = sortrows(Scans, {'VisitNum', 'EyeSide', 'ImageIndex'});
    data.DB.Scans = Scans;
    save(dbPath, '-struct', 'data', '-v7.3');
end

function val = get_field_default(s, fieldName, defaultVal)
    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end

function Visits = get_visits_table(dbPath)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Visits = data.DB.Visits;
end

function Scans = get_scans_table(dbPath, visitNum)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Scans = data.DB.Scans;
    if ~isempty(visitNum)
        Scans = Scans(Scans.VisitNum == int32(visitNum), :);
    end
end

function Summary = get_summary_table(dbPath)
    Visits = get_visits_table(dbPath);
    Scans = get_scans_table(dbPath, []);
    numVisits = height(Visits);

    % Initialize arrays for all 5 layers and their ratios (now using MEDIAN)
    med_l1 = NaN(numVisits, 1); med_l2 = NaN(numVisits, 1);
    med_l3 = NaN(numVisits, 1); med_l4 = NaN(numVisits, 1); med_l5 = NaN(numVisits, 1);
    
    med_ratio_l1_l2 = NaN(numVisits, 1); med_ratio_l2_l3 = NaN(numVisits, 1);
    med_ratio_l3_l4 = NaN(numVisits, 1); med_ratio_l4_l5 = NaN(numVisits, 1);
    med_ratio_l1_l5 = NaN(numVisits, 1); med_roc_l = NaN(numVisits, 1);

    for i = 1:numVisits
        vNum = Visits.VisitNum(i);
        subScans = Scans(Scans.VisitNum == vNum & Scans.EyeSide == "OD", :);

        if ~isempty(subScans)
            % Single Layers - USING MEDIAN
            l1 = subScans.ROI_Left_L1(subScans.ROI_Left_L1 > 0 & ~isnan(subScans.ROI_Left_L1));
            l2 = subScans.ROI_Left_L2(subScans.ROI_Left_L2 > 0 & ~isnan(subScans.ROI_Left_L2));
            l3 = subScans.ROI_Left_L3(subScans.ROI_Left_L3 > 0 & ~isnan(subScans.ROI_Left_L3));
            l4 = subScans.ROI_Left_L4(subScans.ROI_Left_L4 > 0 & ~isnan(subScans.ROI_Left_L4));
            l5 = subScans.ROI_Left_L5(subScans.ROI_Left_L5 > 0 & ~isnan(subScans.ROI_Left_L5));

            if ~isempty(l1), med_l1(i) = median(l1); end
            if ~isempty(l2), med_l2(i) = median(l2); end
            if ~isempty(l3), med_l3(i) = median(l3); end
            if ~isempty(l4), med_l4(i) = median(l4); end
            if ~isempty(l5), med_l5(i) = median(l5); end

            % Ratios - USING MEDIAN
            v12 = subScans.ROI_Left_L1 > 0 & subScans.ROI_Left_L2 > 0;
            if any(v12), med_ratio_l1_l2(i) = median(subScans.ROI_Left_L1(v12) ./ subScans.ROI_Left_L2(v12)); end

            v23 = subScans.ROI_Left_L2 > 0 & subScans.ROI_Left_L3 > 0;
            if any(v23), med_ratio_l2_l3(i) = median(subScans.ROI_Left_L2(v23) ./ subScans.ROI_Left_L3(v23)); end

            v34 = subScans.ROI_Left_L3 > 0 & subScans.ROI_Left_L4 > 0;
            if any(v34), med_ratio_l3_l4(i) = median(subScans.ROI_Left_L3(v34) ./ subScans.ROI_Left_L4(v34)); end

            v45 = subScans.ROI_Left_L4 > 0 & subScans.ROI_Left_L5 > 0;
            if any(v45), med_ratio_l4_l5(i) = median(subScans.ROI_Left_L4(v45) ./ subScans.ROI_Left_L5(v45)); end

            v15 = subScans.ROI_Left_L1 > 0 & subScans.ROI_Left_L5 > 0;
            if any(v15), med_ratio_l1_l5(i) = median(subScans.ROI_Left_L1(v15) ./ subScans.ROI_Left_L5(v15)); end

            % Rate of change usually remains mean, or median of slices
            roc_l = subScans.RateOfChange_Left(~isnan(subScans.RateOfChange_Left));
            if ~isempty(roc_l), med_roc_l(i) = median(roc_l); end
        end
    end

    Summary = addvars(Visits, med_l1, med_l2, med_l3, med_l4, med_l5, ...
        med_ratio_l1_l2, med_ratio_l2_l3, med_ratio_l3_l4, med_ratio_l4_l5, med_ratio_l1_l5, med_roc_l, ...
        'NewVariableNames', {'Median_Left_L1', 'Median_Left_L2', 'Median_Left_L3', 'Median_Left_L4', 'Median_Left_L5', ...
        'Median_Ratio_L1_L2', 'Median_Ratio_L2_L3', 'Median_Ratio_L3_L4', 'Median_Ratio_L4_L5', 'Median_Ratio_L1_L5', 'Median_RateOfChange_Left'});
end

function export_csv_tables(dbPath, outDir)
    if ~isfolder(outDir), mkdir(outDir); end
    Visits = get_visits_table(dbPath);
    Scans = get_scans_table(dbPath, []);
    Summary = get_summary_table(dbPath);

    writetable(Visits, fullfile(outDir, 'visits.csv'));
    writetable(Scans, fullfile(outDir, 'scans.csv'));
    writetable(Summary, fullfile(outDir, 'visit_summary.csv'));
    fprintf('Exported CSV database tables to: %s\n', outDir);
end

function export_excel_tables(dbPath, excelPath)
    Visits = get_visits_table(dbPath);
    Scans = get_scans_table(dbPath, []);
    Summary = get_summary_table(dbPath);

    writetable(Summary, excelPath, 'Sheet', 'Visit_Summary');
    writetable(Visits, excelPath, 'Sheet', 'Visits');
    writetable(Scans, excelPath, 'Sheet', 'Scan_Slices');
    fprintf('Exported consolidated Excel report to: %s\n', excelPath);
end
