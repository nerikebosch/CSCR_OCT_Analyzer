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
    
    % Update if exists or append
    idx = find(Visits.VisitNum == vNum, 1);
    if isempty(idx)
        % Brand new visit
        thOD = NaN; if isfield(v, 'CentralThickness_OD') && ~isempty(v.CentralThickness_OD), thOD = double(v.CentralThickness_OD); end
        thOS = NaN; if isfield(v, 'CentralThickness_OS') && ~isempty(v.CentralThickness_OS), thOS = double(v.CentralThickness_OS); end
        
        notesStr = ""; 
        if isfield(v, 'Notes') && ~isempty(v.Notes)
            if iscell(v.Notes), notesStr = string(strjoin(v.Notes, ' ')); else, notesStr = string(v.Notes); end
        end
        
        newRow = table(vNum, vDate, 0, thOD, thOS, notesStr, ...
            'VariableNames', {'VisitNum', 'VisitDate', 'DaysFromBaseline', ...
                              'CentralThickness_OD', 'CentralThickness_OS', 'Notes'});
        Visits = [Visits; newRow];
    else
        % Existing visit: Update date, preserve thickness unless provided, update notes safely
        Visits.VisitDate(idx) = vDate;
        
        if isfield(v, 'CentralThickness_OD') && ~isempty(v.CentralThickness_OD) && ~isnan(v.CentralThickness_OD)
            Visits.CentralThickness_OD(idx) = double(v.CentralThickness_OD);
        end
        if isfield(v, 'CentralThickness_OS') && ~isempty(v.CentralThickness_OS) && ~isnan(v.CentralThickness_OS)
            Visits.CentralThickness_OS(idx) = double(v.CentralThickness_OS);
        end
        
        % Unconditionally update notes whenever the field is passed from the UI
        if isfield(v, 'Notes')
            if iscell(v.Notes)
                Visits.Notes(idx) = string(strjoin(v.Notes, ' '));
            else
                Visits.Notes(idx) = string(v.Notes);
            end
        end
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

    % Define the target column names we will build
    sides = {'Left', 'Right'};
    metrics = {'L1', 'L2', 'L3', 'L4', 'L5', 'Ratio_L1_L2', 'Ratio_L2_L3', 'Ratio_L3_L4', 'Ratio_L4_L5', 'Ratio_L1_L5', 'RateOfChange'};
    
    % Initialize empty arrays for the table
    summaryData = struct();
    for eye = ["OD", "OS"]
        for s = 1:length(sides)
            for m = 1:length(metrics)
                varName = sprintf('Median_%s_%s_%s', eye, sides{s}, metrics{m});
                summaryData.(varName) = NaN(numVisits, 1);
            end
        end
    end

    for i = 1:numVisits
        vNum = Visits.VisitNum(i);
        
        for eye = ["OD", "OS"]
            subScans = Scans(Scans.VisitNum == vNum & Scans.EyeSide == eye, :);
            if isempty(subScans), continue; end
            
            for s = 1:length(sides)
                side = sides{s}; % 'Left' or 'Right'
                
                % 1. Pool Single Layers (Combines Side ROI + Full ROI to handle mixed slices)
                for L = 1:5
                    colSide = sprintf('ROI_%s_L%d', side, L);
                    colFull = sprintf('ROI_Full_L%d', L);
                    
                    pool = [subScans.(colSide)(subScans.(colSide) > 0 & ~isnan(subScans.(colSide))); ...
                            subScans.(colFull)(subScans.(colFull) > 0 & ~isnan(subScans.(colFull)))];
                            
                    if ~isempty(pool)
                        summaryData.(sprintf('Median_%s_%s_L%d', eye, side, L))(i) = median(pool);
                    end
                end
                
                % 2. Pool Ratios
                ratioPairs = [1,2; 2,3; 3,4; 4,5; 1,5];
                for r = 1:size(ratioPairs, 1)
                    top = ratioPairs(r, 1); bot = ratioPairs(r, 2);
                    
                    cSideT = sprintf('ROI_%s_L%d', side, top); cSideB = sprintf('ROI_%s_L%d', side, bot);
                    cFullT = sprintf('ROI_Full_L%d', top);     cFullB = sprintf('ROI_Full_L%d', bot);
                    
                    % Calculate ratio per slice, then pool
                    vSide = subScans.(cSideT) > 0 & subScans.(cSideB) > 0;
                    vFull = subScans.(cFullT) > 0 & subScans.(cFullB) > 0;
                    
                    poolRat = [subScans.(cSideT)(vSide) ./ subScans.(cSideB)(vSide); ...
                               subScans.(cFullT)(vFull) ./ subScans.(cFullB)(vFull)];
                               
                    if ~isempty(poolRat)
                        summaryData.(sprintf('Median_%s_%s_Ratio_L%d_L%d', eye, side, top, bot))(i) = median(poolRat);
                    end
                end
                
                % 3. Rate of change (Currently only calculated for Left/Right in main script)
                cRoc = sprintf('RateOfChange_%s', side);
                if ismember(cRoc, subScans.Properties.VariableNames)
                    roc = subScans.(cRoc)(~isnan(subScans.(cRoc)));
                    if ~isempty(roc), summaryData.(sprintf('Median_%s_%s_RateOfChange', eye, side))(i) = median(roc); end
                end
            end
        end
    end

    % Convert the struct to table columns and attach to Visits
    Summary = Visits;
    fNames = fieldnames(summaryData);
    for f = 1:length(fNames)
        Summary.(fNames{f}) = summaryData.(fNames{f});
    end
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
