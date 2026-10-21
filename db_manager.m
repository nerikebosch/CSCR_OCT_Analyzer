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

%% ======================================================================
%  Internal DB Functions
%  ======================================================================

function DB = init_db(dbPath)
    if isfile(dbPath)
        data = load(dbPath);
        DB = data.DB;
        DB = migrate_fw_columns(DB, dbPath);   % no-op on v1.1+ databases
        fprintf('Loaded existing OCT Study Database from: %s\n', dbPath);
        return;
    end

    % ---- Visits table --------------------------------------------------
    Visits = table( ...
        zeros(0,1,'int32'), ...
        datetime.empty(0,1), ...
        zeros(0,1,'double'), ...
        zeros(0,1,'double'), ...
        zeros(0,1,'double'), ...
        strings(0,1), ...
        'VariableNames', {'VisitNum','VisitDate','DaysFromBaseline', ...
                          'CentralThickness_OD','CentralThickness_OS','Notes'});

    % ---- Scans table ---------------------------------------------------
    z = @() zeros(0,1,'double');
    Scans = table( ...
        zeros(0,1,'int32'),  zeros(0,1,'int32'), zeros(0,1,'int32'), ...
        strings(0,1), strings(0,1), ...
        z(),z(),z(),z(),z(), ...   % ROI_Right_L1..L5
        z(),z(),z(),z(),z(), ...   % ROI_Left_L1..L5
        z(),z(),z(),z(),z(), ...   % ROI_Full_L1..L5
        z(), z(), z(), z(), ...    % Ratio_Left/Right, RoC_Left/Right  (legacy)
        z(),z(),z(),z(),z(), ...   % ROI_Right_L1_fw..L5_fw
        z(),z(),z(),z(),z(), ...   % ROI_Left_L1_fw..L5_fw
        z(),z(),z(),z(),z(), ...   % ROI_Full_L1_fw..L5_fw
        z(), z(), z(), z(), ...    % Ratio_Left/Right_fw, RoC_Left/Right_fw
        'VariableNames', { ...
            'ScanID','VisitNum','ImageIndex','EyeSide','FileName', ...
            'ROI_Right_L1','ROI_Right_L2','ROI_Right_L3','ROI_Right_L4','ROI_Right_L5', ...
            'ROI_Left_L1', 'ROI_Left_L2', 'ROI_Left_L3', 'ROI_Left_L4', 'ROI_Left_L5', ...
            'ROI_Full_L1', 'ROI_Full_L2', 'ROI_Full_L3', 'ROI_Full_L4', 'ROI_Full_L5', ...
            'Ratio_Left_L4_L5','Ratio_Right_L4_L5','RateOfChange_Left','RateOfChange_Right', ...
            'ROI_Right_L1_fw','ROI_Right_L2_fw','ROI_Right_L3_fw','ROI_Right_L4_fw','ROI_Right_L5_fw', ...
            'ROI_Left_L1_fw', 'ROI_Left_L2_fw', 'ROI_Left_L3_fw', 'ROI_Left_L4_fw', 'ROI_Left_L5_fw', ...
            'ROI_Full_L1_fw', 'ROI_Full_L2_fw', 'ROI_Full_L3_fw', 'ROI_Full_L4_fw', 'ROI_Full_L5_fw', ...
            'Ratio_Left_L4_L5_fw','Ratio_Right_L4_L5_fw', ...
            'RateOfChange_Left_fw','RateOfChange_Right_fw'});

    DB = struct('Visits', Visits, 'Scans', Scans, ...
                'Created', datetime('now'), 'Version', '1.1');
    save(dbPath, 'DB', '-v7.3');
    fprintf('Created new OCT Study Database (v1.1) at: %s\n', dbPath);
end

% --------------------------------------------------------------------------
function DB = migrate_fw_columns(DB, dbPath)
% Silently adds the 19 fixed-width columns if they are missing (v1.0 -> v1.1).
    fw_cols = { ...
        'ROI_Right_L1_fw','ROI_Right_L2_fw','ROI_Right_L3_fw','ROI_Right_L4_fw','ROI_Right_L5_fw', ...
        'ROI_Left_L1_fw', 'ROI_Left_L2_fw', 'ROI_Left_L3_fw', 'ROI_Left_L4_fw', 'ROI_Left_L5_fw', ...
        'ROI_Full_L1_fw', 'ROI_Full_L2_fw', 'ROI_Full_L3_fw', 'ROI_Full_L4_fw', 'ROI_Full_L5_fw', ...
        'Ratio_Left_L4_L5_fw','Ratio_Right_L4_L5_fw', ...
        'RateOfChange_Left_fw','RateOfChange_Right_fw'};

    changed = false;
    nRows = height(DB.Scans);
    for c = 1:length(fw_cols)
        if ~ismember(fw_cols{c}, DB.Scans.Properties.VariableNames)
            DB.Scans.(fw_cols{c}) = NaN(nRows, 1);
            changed = true;
        end
    end

    if changed
        DB.Version = '1.1';
        data.DB = DB; %#ok<STRNU>
        save(dbPath, '-struct', 'data', '-v7.3');
        fprintf('Database migrated to v1.1: fixed-width ROI columns added.\n');
    end
end

% --------------------------------------------------------------------------
function save_visit_record(dbPath, v)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Visits = data.DB.Visits;

    vNum  = int32(v.VisitNum);
    vDate = v.VisitDate;
    if ~isa(vDate, 'datetime')
        vDate = datetime(vDate, 'InputFormat', 'yyyy-MM-dd');
    end

    idx = find(Visits.VisitNum == vNum, 1);
    if isempty(idx)
        thOD = NaN; if isfield(v,'CentralThickness_OD') && ~isempty(v.CentralThickness_OD), thOD = double(v.CentralThickness_OD); end
        thOS = NaN; if isfield(v,'CentralThickness_OS') && ~isempty(v.CentralThickness_OS), thOS = double(v.CentralThickness_OS); end
        notesStr = ""; if isfield(v,'Notes') && ~isempty(v.Notes), notesStr = coerce_string(v.Notes); end

        newRow = table(vNum, vDate, 0, thOD, thOS, notesStr, ...
            'VariableNames', {'VisitNum','VisitDate','DaysFromBaseline', ...
                              'CentralThickness_OD','CentralThickness_OS','Notes'});
        Visits = [Visits; newRow];
    else
        Visits.VisitDate(idx) = vDate;
        if isfield(v,'CentralThickness_OD') && ~isempty(v.CentralThickness_OD) && ~isnan(v.CentralThickness_OD)
            Visits.CentralThickness_OD(idx) = double(v.CentralThickness_OD);
        end
        if isfield(v,'CentralThickness_OS') && ~isempty(v.CentralThickness_OS) && ~isnan(v.CentralThickness_OS)
            Visits.CentralThickness_OS(idx) = double(v.CentralThickness_OS);
        end
        if isfield(v,'Notes')
            Visits.Notes(idx) = coerce_string(v.Notes);
        end
    end

    Visits = sortrows(Visits, 'VisitNum');
    baseDate = Visits.VisitDate(1);
    Visits.DaysFromBaseline = double(days(Visits.VisitDate - baseDate));

    data.DB.Visits = Visits;
    save(dbPath, '-struct', 'data', '-v7.3');
end

% --------------------------------------------------------------------------
function save_scan_record(dbPath, s)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath);
    Scans = data.DB.Scans;

    vNum   = int32(s.VisitNum);
    imgIdx = int32(s.ImageIndex);
    eyeSide = "OD";  if isfield(s,'EyeSide')   && ~isempty(s.EyeSide),   eyeSide = string(s.EyeSide); end
    fn      = "";    if isfield(s,'FileName')   && ~isempty(s.FileName),   fn = string(s.FileName); end

    getCR = @(f) double(get_field_default(s, f, NaN));

    % Legacy ROI columns
    r_r1=getCR('ROI_Right_L1'); r_r2=getCR('ROI_Right_L2'); r_r3=getCR('ROI_Right_L3');
    r_r4=getCR('ROI_Right_L4'); r_r5=getCR('ROI_Right_L5');
    r_l1=getCR('ROI_Left_L1');  r_l2=getCR('ROI_Left_L2');  r_l3=getCR('ROI_Left_L3');
    r_l4=getCR('ROI_Left_L4');  r_l5=getCR('ROI_Left_L5');
    r_f1=getCR('ROI_Full_L1');  r_f2=getCR('ROI_Full_L2');  r_f3=getCR('ROI_Full_L3');
    r_f4=getCR('ROI_Full_L4');  r_f5=getCR('ROI_Full_L5');

    % Legacy ratios
    ratio_l = compute_ratio(r_l4, r_l5);
    if isfield(s,'Ratio_Left_L4_L5')  && ~isempty(s.Ratio_Left_L4_L5)  && ~isnan(s.Ratio_Left_L4_L5),  ratio_l = double(s.Ratio_Left_L4_L5);  end
    ratio_r = compute_ratio(r_r4, r_r5);
    if isfield(s,'Ratio_Right_L4_L5') && ~isempty(s.Ratio_Right_L4_L5) && ~isnan(s.Ratio_Right_L4_L5), ratio_r = double(s.Ratio_Right_L4_L5); end
    roc_l = getCR('RateOfChange_Left');
    roc_r = getCR('RateOfChange_Right');

    % Fixed-width ROI columns
    fw_r1=getCR('ROI_Right_L1_fw'); fw_r2=getCR('ROI_Right_L2_fw'); fw_r3=getCR('ROI_Right_L3_fw');
    fw_r4=getCR('ROI_Right_L4_fw'); fw_r5=getCR('ROI_Right_L5_fw');
    fw_l1=getCR('ROI_Left_L1_fw');  fw_l2=getCR('ROI_Left_L2_fw');  fw_l3=getCR('ROI_Left_L3_fw');
    fw_l4=getCR('ROI_Left_L4_fw');  fw_l5=getCR('ROI_Left_L5_fw');
    fw_f1=getCR('ROI_Full_L1_fw');  fw_f2=getCR('ROI_Full_L2_fw');  fw_f3=getCR('ROI_Full_L3_fw');
    fw_f4=getCR('ROI_Full_L4_fw');  fw_f5=getCR('ROI_Full_L5_fw');

    fw_ratio_l = compute_ratio(fw_l4, fw_l5);
    if isfield(s,'Ratio_Left_L4_L5_fw')  && ~isempty(s.Ratio_Left_L4_L5_fw)  && ~isnan(s.Ratio_Left_L4_L5_fw),  fw_ratio_l = double(s.Ratio_Left_L4_L5_fw);  end
    fw_ratio_r = compute_ratio(fw_r4, fw_r5);
    if isfield(s,'Ratio_Right_L4_L5_fw') && ~isempty(s.Ratio_Right_L4_L5_fw) && ~isnan(s.Ratio_Right_L4_L5_fw), fw_ratio_r = double(s.Ratio_Right_L4_L5_fw); end
    fw_roc_l = getCR('RateOfChange_Left_fw');
    fw_roc_r = getCR('RateOfChange_Right_fw');

    idx = find(Scans.VisitNum == vNum & Scans.ImageIndex == imgIdx & Scans.EyeSide == eyeSide, 1);

    if isempty(idx)
        % New row — must provide all columns in order
        scanID = int32(height(Scans) + 1);
        varNames = Scans.Properties.VariableNames;
        vals = {scanID, vNum, imgIdx, eyeSide, fn, ...
                r_r1,r_r2,r_r3,r_r4,r_r5, r_l1,r_l2,r_l3,r_l4,r_l5, ...
                r_f1,r_f2,r_f3,r_f4,r_f5, ratio_l,ratio_r,roc_l,roc_r, ...
                fw_r1,fw_r2,fw_r3,fw_r4,fw_r5, fw_l1,fw_l2,fw_l3,fw_l4,fw_l5, ...
                fw_f1,fw_f2,fw_f3,fw_f4,fw_f5, fw_ratio_l,fw_ratio_r,fw_roc_l,fw_roc_r};
        newRow = cell2table(vals, 'VariableNames', varNames);
        Scans = [Scans; newRow];
    else
        % Existing row — only overwrite non-NaN supplied values
        set_if_valid = @(col, val) setfield_if_valid(Scans, idx, col, val);
        Scans = set_if_valid('FileName', fn);
        Scans = update_cols(Scans, idx, ...
            {'ROI_Right_L1','ROI_Right_L2','ROI_Right_L3','ROI_Right_L4','ROI_Right_L5'}, {r_r1,r_r2,r_r3,r_r4,r_r5});
        Scans = update_cols(Scans, idx, ...
            {'ROI_Left_L1','ROI_Left_L2','ROI_Left_L3','ROI_Left_L4','ROI_Left_L5'}, {r_l1,r_l2,r_l3,r_l4,r_l5});
        Scans = update_cols(Scans, idx, ...
            {'ROI_Full_L1','ROI_Full_L2','ROI_Full_L3','ROI_Full_L4','ROI_Full_L5'}, {r_f1,r_f2,r_f3,r_f4,r_f5});
        Scans = update_cols(Scans, idx, ...
            {'Ratio_Left_L4_L5','Ratio_Right_L4_L5','RateOfChange_Left','RateOfChange_Right'}, {ratio_l,ratio_r,roc_l,roc_r});
        Scans = update_cols(Scans, idx, ...
            {'ROI_Right_L1_fw','ROI_Right_L2_fw','ROI_Right_L3_fw','ROI_Right_L4_fw','ROI_Right_L5_fw'}, {fw_r1,fw_r2,fw_r3,fw_r4,fw_r5});
        Scans = update_cols(Scans, idx, ...
            {'ROI_Left_L1_fw','ROI_Left_L2_fw','ROI_Left_L3_fw','ROI_Left_L4_fw','ROI_Left_L5_fw'}, {fw_l1,fw_l2,fw_l3,fw_l4,fw_l5});
        Scans = update_cols(Scans, idx, ...
            {'ROI_Full_L1_fw','ROI_Full_L2_fw','ROI_Full_L3_fw','ROI_Full_L4_fw','ROI_Full_L5_fw'}, {fw_f1,fw_f2,fw_f3,fw_f4,fw_f5});
        Scans = update_cols(Scans, idx, ...
            {'Ratio_Left_L4_L5_fw','Ratio_Right_L4_L5_fw','RateOfChange_Left_fw','RateOfChange_Right_fw'}, {fw_ratio_l,fw_ratio_r,fw_roc_l,fw_roc_r});
    end

    Scans = sortrows(Scans, {'VisitNum','EyeSide','ImageIndex'});
    data.DB.Scans = Scans;
    save(dbPath, '-struct', 'data', '-v7.3');
end

% --------------------------------------------------------------------------
%  Small helpers
% --------------------------------------------------------------------------
function r = compute_ratio(num, den)
    if ~isnan(num) && ~isnan(den) && den ~= 0
        r = num / den;
    else
        r = NaN;
    end
end

function T = update_cols(T, idx, cols, vals)
    for k = 1:length(cols)
        v = vals{k};
        if ~isnan(v) || true   % always write (NaN intentionally clears stale values)
            T.(cols{k})(idx) = v;
        end
    end
end

function T = setfield_if_valid(T, idx, col, val)
    if ~isempty(val)
        T.(col)(idx) = val;
    end
end

function val = get_field_default(s, fieldName, defaultVal)
    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end

function s = coerce_string(v)
    if iscell(v)
        s = string(strjoin(v, ' '));
    else
        s = string(v);
    end
end

% --------------------------------------------------------------------------
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

% --------------------------------------------------------------------------
function Summary = get_summary_table(dbPath)
% Aggregates per-visit metrics across the 3 slices (median).
% Computes all individual layers and all inter-layer ratios dynamically.
    Visits = get_visits_table(dbPath);
    Scans  = get_scans_table(dbPath, []);
    nV     = height(Visits);
    Summary = Visits;
    
    % Pre-allocate the legacy mean/std columns for compute_statistics('plot')
    Summary.Mean_Ratio_Left_L4_L5 = NaN(nV, 1);
    Summary.Std_Ratio_Left_L4_L5 = NaN(nV, 1);
    Summary.Mean_RateOfChange_Left = NaN(nV, 1);
    
    for i = 1:nV
        vNum = Visits.VisitNum(i);
        
        % Process both eyes (OD and OS)
        for eye = ["OD", "OS"]
            sub = Scans(Scans.VisitNum == vNum & Scans.EyeSide == eye, :);
            if isempty(sub), continue; end
            
            % 1. Compute Mean/Std for the standard plot (OD only)
            if eye == "OD"
                Summary.Mean_Ratio_Left_L4_L5(i) = mean(sub.Ratio_Left_L4_L5, 'omitnan');
                if sum(~isnan(sub.Ratio_Left_L4_L5)) > 1
                    Summary.Std_Ratio_Left_L4_L5(i) = std(sub.Ratio_Left_L4_L5, 'omitnan');
                else
                    Summary.Std_Ratio_Left_L4_L5(i) = 0;
                end
                Summary.Mean_RateOfChange_Left(i) = mean(sub.RateOfChange_Left, 'omitnan');
            end
            
            % 2. Dynamically calculate medians and ratios for the Dashboard UI
            sides = {'Left', 'Right'};
            suffixes = {'', '_fw'};
            
            for s = 1:length(sides)
                side = sides{s};
                for fx = 1:length(suffixes)
                    sfx = suffixes{fx};
                    
                    % Extract the raw slice arrays from the Scans table
                    if ~ismember(sprintf('ROI_%s_L1%s', side, sfx), sub.Properties.VariableNames), continue; end
                    L1 = sub.(sprintf('ROI_%s_L1%s', side, sfx));
                    L2 = sub.(sprintf('ROI_%s_L2%s', side, sfx));
                    L3 = sub.(sprintf('ROI_%s_L3%s', side, sfx));
                    L4 = sub.(sprintf('ROI_%s_L4%s', side, sfx));
                    L5 = sub.(sprintf('ROI_%s_L5%s', side, sfx));
                    
                    % Dashboard Layer Medians
                    Summary.(sprintf('Median_%s_%s_L1%s', eye, side, sfx))(i) = median(L1, 'omitnan');
                    Summary.(sprintf('Median_%s_%s_L2%s', eye, side, sfx))(i) = median(L2, 'omitnan');
                    Summary.(sprintf('Median_%s_%s_L3%s', eye, side, sfx))(i) = median(L3, 'omitnan');
                    Summary.(sprintf('Median_%s_%s_L4%s', eye, side, sfx))(i) = median(L4, 'omitnan');
                    Summary.(sprintf('Median_%s_%s_L5%s', eye, side, sfx))(i) = median(L5, 'omitnan');
                    
                    % Dashboard Inter-Layer Ratios
                    % Helper to calculate ratio per slice safely, then take the median
                    calc_ratio = @(num, den) median(num ./ (den + 0./(den ~= 0)), 'omitnan');
                    
                    Summary.(sprintf('Median_%s_%s_Ratio_L1_L2%s', eye, side, sfx))(i) = calc_ratio(L1, L2);
                    Summary.(sprintf('Median_%s_%s_Ratio_L2_L3%s', eye, side, sfx))(i) = calc_ratio(L2, L3);
                    Summary.(sprintf('Median_%s_%s_Ratio_L3_L4%s', eye, side, sfx))(i) = calc_ratio(L3, L4);
                    Summary.(sprintf('Median_%s_%s_Ratio_L4_L5%s', eye, side, sfx))(i) = calc_ratio(L4, L5);
                    Summary.(sprintf('Median_%s_%s_Ratio_L1_L5%s', eye, side, sfx))(i) = calc_ratio(L1, L5);
                end
            end
        end
    end
end

% --------------------------------------------------------------------------
function export_csv_tables(dbPath, outDir)
    if ~isfolder(outDir), mkdir(outDir); end
    Visits  = get_visits_table(dbPath);
    Scans   = get_scans_table(dbPath, []);
    Summary = get_summary_table(dbPath);
    writetable(Visits,  fullfile(outDir, 'visits.csv'));
    writetable(Scans,   fullfile(outDir, 'scans.csv'));
    writetable(Summary, fullfile(outDir, 'visit_summary.csv'));
    fprintf('Exported CSV database tables to: %s\n', outDir);
end

function export_excel_tables(dbPath, excelPath)
    Visits  = get_visits_table(dbPath);
    Scans   = get_scans_table(dbPath, []);
    Summary = get_summary_table(dbPath);
    writetable(Summary, excelPath, 'Sheet', 'Visit_Summary');
    writetable(Visits,  excelPath, 'Sheet', 'Visits');
    writetable(Scans,   excelPath, 'Sheet', 'Scan_Slices');
    fprintf('Exported consolidated Excel report to: %s\n', excelPath);
end
