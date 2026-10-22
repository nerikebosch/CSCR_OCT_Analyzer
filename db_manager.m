function varargout = db_manager(action, varargin)
    defaultDbPath = fullfile(fileparts(mfilename('fullpath')), 'oct_study_db.mat');
    switch lower(action)
        case 'init'
            dbPath = defaultDbPath;
            if ~isempty(varargin) && ~isempty(varargin{1}), dbPath = varargin{1}; end
            out = init_db(dbPath);
            if nargout > 0, varargout{1} = out; end
        case 'save_visit'
            save_visit_record(defaultDbPath, varargin{1});
        case 'save_scan'
            save_scan_record(defaultDbPath, varargin{1});
        case 'get_visits'
            varargout{1} = get_visits_table(defaultDbPath);
        case 'get_scans'
            visitNum = []; if ~isempty(varargin), visitNum = varargin{1}; end
            varargout{1} = get_scans_table(defaultDbPath, visitNum);
        case 'get_summary'
            varargout{1} = get_summary_table(defaultDbPath);
        case 'export_csv'
            outDir = fullfile(fileparts(mfilename('fullpath')), 'db_export');
            if ~isempty(varargin) && ~isempty(varargin{1}), outDir = varargin{1}; end
            export_csv_tables(defaultDbPath, outDir);
        case 'export_excel'
            excelPath = fullfile(fileparts(mfilename('fullpath')), 'oct_study_export.xlsx');
            if ~isempty(varargin) && ~isempty(varargin{1}), excelPath = varargin{1}; end
            export_excel_tables(defaultDbPath, excelPath);
        case 'db_path'
            varargout{1} = defaultDbPath;
        otherwise
            error('Unknown db_manager action: %s', action);
    end
end

function DB = init_db(dbPath)
    if isfile(dbPath)
        data = load(dbPath);
        DB = data.DB;
        DB = migrate_fw_and_texture_columns(DB, dbPath); % Auto-updates older databases!
        fprintf('Loaded existing OCT Study Database from: %s\n', dbPath);
        return;
    end
    % Create empty if missing (simplified creation; relies on migration to build columns)
    Visits = table(zeros(0,1,'int32'), datetime.empty(0,1), zeros(0,1,'double'), zeros(0,1,'double'), zeros(0,1,'double'), strings(0,1), ...
        'VariableNames', {'VisitNum','VisitDate','DaysFromBaseline','CentralThickness_OD','CentralThickness_OS','Notes'});
    Scans = table(zeros(0,1,'int32'), zeros(0,1,'int32'), zeros(0,1,'int32'), strings(0,1), strings(0,1), ...
        'VariableNames', {'ScanID','VisitNum','ImageIndex','EyeSide','FileName'});
    DB = struct('Visits', Visits, 'Scans', Scans, 'Created', datetime('now'), 'Version', '1.0');
    DB = migrate_fw_and_texture_columns(DB, dbPath);
    fprintf('Created new OCT Study Database at: %s\n', dbPath);
end

function DB = migrate_fw_and_texture_columns(DB, dbPath)
    changed = false;
    nRows = height(DB.Scans);
    
    % Generate ALL required column names dynamically
    requiredCols = {'Ratio_Left_L4_L5', 'Ratio_Right_L4_L5', 'RateOfChange_Left', 'RateOfChange_Right', ...
                    'Ratio_Left_L4_L5_fw', 'Ratio_Right_L4_L5_fw', 'RateOfChange_Left_fw', 'RateOfChange_Right_fw'};
    for side = ["Right", "Left", "Full"]
        for L = 1:5
            for sfx = ["", "_fw"]
                requiredCols{end+1} = sprintf('ROI_%s_L%d%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_Densito%s', side, L, sfx);
                % PDF Parameters
                requiredCols{end+1} = sprintf('ROI_%s_L%d_GAM_A%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_GAM_B%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_NK_mu%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_NK_om%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_EXP%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_RAY%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_WBL_A%s', side, L, sfx);
                requiredCols{end+1} = sprintf('ROI_%s_L%d_WBL_B%s', side, L, sfx);
            end
        end
    end
    
    for c = 1:length(requiredCols)
        if ~ismember(requiredCols{c}, DB.Scans.Properties.VariableNames)
            DB.Scans.(requiredCols{c}) = NaN(max(nRows, 0), 1);
            changed = true;
        end
    end
    
    if changed
        DB.Version = '1.3';
        data.DB = DB; 
        save(dbPath, '-struct', 'data', '-v7.3');
        fprintf('Database auto-migrated to v1.3 (Added Full PDF Parameters).\n');
    end
end

function save_visit_record(dbPath, v)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath); Visits = data.DB.Visits;
    vNum  = int32(v.VisitNum); vDate = v.VisitDate;
    if ~isa(vDate, 'datetime'), vDate = datetime(vDate, 'InputFormat', 'yyyy-MM-dd'); end
    idx = find(Visits.VisitNum == vNum, 1);
    if isempty(idx)
        thOD = NaN; if isfield(v,'CentralThickness_OD'), thOD = double(v.CentralThickness_OD); end
        thOS = NaN; if isfield(v,'CentralThickness_OS'), thOS = double(v.CentralThickness_OS); end
        notesStr = ""; if isfield(v,'Notes'), notesStr = string(v.Notes); end
        newRow = table(vNum, vDate, 0, thOD, thOS, notesStr, 'VariableNames', {'VisitNum','VisitDate','DaysFromBaseline','CentralThickness_OD','CentralThickness_OS','Notes'});
        Visits = [Visits; newRow];
    else
        Visits.VisitDate(idx) = vDate;
        if isfield(v,'CentralThickness_OD'), Visits.CentralThickness_OD(idx) = double(v.CentralThickness_OD); end
        if isfield(v,'CentralThickness_OS'), Visits.CentralThickness_OS(idx) = double(v.CentralThickness_OS); end
        if isfield(v,'Notes'), Visits.Notes(idx) = string(v.Notes); end
    end
    Visits = sortrows(Visits, 'VisitNum');
    Visits.DaysFromBaseline = double(days(Visits.VisitDate - Visits.VisitDate(1)));
    data.DB.Visits = Visits; save(dbPath, '-struct', 'data', '-v7.3');
end

function save_scan_record(dbPath, s)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath); Scans = data.DB.Scans;
    vNum = int32(s.VisitNum); imgIdx = int32(s.ImageIndex); eyeSide = string(s.EyeSide);
    
    idx = find(Scans.VisitNum == vNum & Scans.ImageIndex == imgIdx & Scans.EyeSide == eyeSide, 1);
    if isempty(idx)
        % Create empty row
        scanID = int32(height(Scans) + 1);
        newRow = Scans(1,:); % Copy structure
        for c = 1:width(newRow)
            if iscell(newRow{1,c}), newRow{1,c} = {""};
            elseif isstring(newRow{1,c}), newRow{1,c} = "";
            else, newRow{1,c} = NaN; end
        end
        newRow.ScanID = scanID; newRow.VisitNum = vNum; newRow.ImageIndex = imgIdx; newRow.EyeSide = eyeSide;
        idx = height(Scans) + 1;
        Scans = [Scans; newRow];
    end
    
    % Dynamically inject ALL fields provided in the 's' struct into the DB row
    flds = fieldnames(s);
    for f = 1:length(flds)
        fName = flds{f};
        if ismember(fName, Scans.Properties.VariableNames)
            val = s.(fName);
            if ~isempty(val)
                if ischar(val) || isstring(val), Scans.(fName)(idx) = string(val);
                else, Scans.(fName)(idx) = double(val); end
            end
        end
    end
    
    Scans = sortrows(Scans, {'VisitNum','EyeSide','ImageIndex'});
    data.DB.Scans = Scans; save(dbPath, '-struct', 'data', '-v7.3');
end

function Visits = get_visits_table(dbPath)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath); Visits = data.DB.Visits;
end
function Scans = get_scans_table(dbPath, visitNum)
    if ~isfile(dbPath), init_db(dbPath); end
    data = load(dbPath); Scans = data.DB.Scans;
    if ~isempty(visitNum), Scans = Scans(Scans.VisitNum == int32(visitNum), :); end
end

function Summary = get_summary_table(dbPath)
    Visits = get_visits_table(dbPath);
    Scans  = get_scans_table(dbPath, []);
    nV     = height(Visits);
    Summary = Visits;
    
    Summary.Mean_Ratio_Left_L4_L5 = NaN(nV, 1);
    Summary.Std_Ratio_Left_L4_L5 = NaN(nV, 1);
    Summary.Mean_RateOfChange_Left = NaN(nV, 1);
    
    for i = 1:nV
        vNum = Visits.VisitNum(i);
        for eye = ["OD", "OS"]
            sub = Scans(Scans.VisitNum == vNum & Scans.EyeSide == eye, :);
            if isempty(sub), continue; end
            
            if eye == "OD"
                Summary.Mean_Ratio_Left_L4_L5(i) = mean(sub.Ratio_Left_L4_L5, 'omitnan');
                if sum(~isnan(sub.Ratio_Left_L4_L5)) > 1, Summary.Std_Ratio_Left_L4_L5(i) = std(sub.Ratio_Left_L4_L5, 'omitnan'); else, Summary.Std_Ratio_Left_L4_L5(i) = 0; end
                Summary.Mean_RateOfChange_Left(i) = mean(sub.RateOfChange_Left, 'omitnan');
            end
            
            % DYNAMICALLY GET MEDIAN FOR EVERY SINGLE METRIC
            for c = 1:width(sub)
                colName = sub.Properties.VariableNames{c};
                if startsWith(colName, 'ROI_')
                    Summary.(sprintf('Median_%s_%s', eye, strrep(colName, 'ROI_', '')))(i) = median(sub.(colName), 'omitnan');
                end
            end
            
            % Inter-layer Ratios for CR
            sides = {'Left', 'Right'}; suffixes = {'', '_fw'};
            for s = 1:length(sides)
                side = sides{s};
                for fx = 1:length(suffixes)
                    sfx = suffixes{fx};
                    if ~ismember(sprintf('ROI_%s_L1%s', side, sfx), sub.Properties.VariableNames), continue; end
                    L1 = sub.(sprintf('ROI_%s_L1%s', side, sfx)); L2 = sub.(sprintf('ROI_%s_L2%s', side, sfx));
                    L3 = sub.(sprintf('ROI_%s_L3%s', side, sfx)); L4 = sub.(sprintf('ROI_%s_L4%s', side, sfx));
                    L5 = sub.(sprintf('ROI_%s_L5%s', side, sfx));
                    calc_ratio = @(num, den) median(num ./ (den + 0./(den ~= 0)), 'omitnan');
                    Summary.(sprintf('Median_%s_%s_Ratio_L1_L2%s', eye, side, sfx))(i) = calc_ratio(L1, L2);
                    Summary.(sprintf('Median_%s_%s_Ratio_L3_L4%s', eye, side, sfx))(i) = calc_ratio(L3, L4);
                    Summary.(sprintf('Median_%s_%s_Ratio_L4_L5%s', eye, side, sfx))(i) = calc_ratio(L4, L5);
                end
            end
        end
    end
end

function export_csv_tables(dbPath, outDir)
    if ~isfolder(outDir), mkdir(outDir); end
    writetable(get_visits_table(dbPath), fullfile(outDir, 'visits.csv'));
    writetable(get_scans_table(dbPath, []), fullfile(outDir, 'scans.csv'));
    writetable(get_summary_table(dbPath), fullfile(outDir, 'visit_summary.csv'));
end
function export_excel_tables(dbPath, excelPath)
    writetable(get_summary_table(dbPath), excelPath, 'Sheet', 'Visit_Summary');
    writetable(get_visits_table(dbPath), excelPath, 'Sheet', 'Visits');
    writetable(get_scans_table(dbPath, []), excelPath, 'Sheet', 'Scan_Slices');
end