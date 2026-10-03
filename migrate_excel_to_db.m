%% MIGRATE_EXCEL_TO_DB
% Reads historical data from C:\School\Thesis\Statistics.xlsx and imports
% all 22 clinical visits, scan slices, central thicknesses, and notes
% into the local database (oct_study_db.mat).

function migrate_excel_to_db(excelPath)
    if nargin < 1 || isempty(excelPath)
        excelPath = 'C:\School\Thesis\Statistics.xlsx';
    end

    if ~isfile(excelPath)
        error('Excel file not found at: %s', excelPath);
    end

    fprintf('====================================================\n');
    fprintf('Starting Migration from Excel to Local OCT Database\n');
    fprintf('Source File: %s\n', excelPath);
    fprintf('====================================================\n\n');

    % Initialize clean DB
    dbPath = db_manager('db_path');
    if isfile(dbPath)
        delete(dbPath); % Fresh start for clean migration
    end
    db_manager('init');

    %% 1. Read Sheet3 (Visits & Central Thickness)
    fprintf('--- Step 1: Reading Visits & Central Thickness from Sheet3 ---\n');
    T3 = readcell(excelPath, 'Sheet', 'Sheet3');
    numVisits = size(T3, 2) - 1; % Columns 2..end

    %% 2. Read Sheet1 (Notes)
    fprintf('--- Step 2: Reading Clinical Notes from Sheet1 ---\n');
    T1 = readcell(excelPath, 'Sheet', 'Sheet1');

    % Map notes by visit index
    notesList = cell(numVisits, 1);
    for v = 1:numVisits
        col1 = v + 2; % In Sheet1, data starts at column 3
        if col1 <= size(T1, 2)
            nVal = T1{7, col1};
            if ~isempty(nVal) && ~all(ismissing(nVal))
                notesList{v} = char(string(nVal));
            else
                notesList{v} = '';
            end
        else
            notesList{v} = '';
        end
    end

    % Insert each visit into DB
    for v = 1:numVisits
        col3 = v + 1; % In Sheet3, data starts at column 2
        rawDate = T3{2, col3};
        if isa(rawDate, 'datetime')
            vDate = rawDate;
        else
            vDate = datetime(char(string(rawDate)), 'InputFormat', 'dd-MMM-yyyy', 'Locale', 'en_US');
        end

        rawOD = T3{3, col3};
        thOD = NaN;
        if isnumeric(rawOD) && ~isnan(rawOD), thOD = double(rawOD); end

        rawOS = T3{4, col3};
        thOS = NaN;
        if isnumeric(rawOS) && ~isnan(rawOS), thOS = double(rawOS); end

        vStruct = struct();
        vStruct.VisitNum = v;
        vStruct.VisitDate = vDate;
        vStruct.CentralThickness_OD = thOD;
        vStruct.CentralThickness_OS = thOS;
        vStruct.Notes = notesList{v};

        db_manager('save_visit', vStruct);
        fprintf('  Imported Visit %02d | Date: %s | OD Thickness: %3.0f um | OS Thickness: %3.0f um\n', ...
            v, datestr(vDate, 'yyyy-mm-dd'), thOD, thOS);
    end

    %% 3. Read Sheet4 (Individual Scan Slices & ROI Metrics)
    fprintf('\n--- Step 3: Reading Scan Slices and ROI Values from Sheet4 ---\n');
    T4 = readcell(excelPath, 'Sheet', 'Sheet4');

    % Sheet4 has 3 columns per visit starting at col 3
    totalImageCols = size(T4, 2) - 2;
    fprintf('  Found %d image slice columns in Sheet4.\n', totalImageCols);

    for colIdx = 3:size(T4, 2)
        % Determine visit and image slice
        imageColOffset = colIdx - 3;
        vNum = floor(imageColOffset / 3) + 1;
        imgIdx = mod(imageColOffset, 3) + 1;

        if vNum > numVisits, continue; end

        s = struct();
        s.VisitNum = vNum;
        s.ImageIndex = imgIdx;
        s.EyeSide = 'OD'; % Sheet4 is Right Eye
        s.FileName = sprintf('Visit%02d_Image%d.bmp', vNum, imgIdx);

        % Extract ROI Values safely
        s.ROI_Right_L1 = get_num(T4{3, colIdx});
        s.ROI_Right_L2 = get_num(T4{4, colIdx});
        s.ROI_Right_L3 = get_num(T4{5, colIdx});
        s.ROI_Right_L4 = get_num(T4{6, colIdx});
        s.ROI_Right_L5 = get_num(T4{7, colIdx});

        s.ROI_Left_L1 = get_num(T4{8, colIdx});
        s.ROI_Left_L2 = get_num(T4{9, colIdx});
        s.ROI_Left_L3 = get_num(T4{10, colIdx});
        s.ROI_Left_L4 = get_num(T4{11, colIdx});
        s.ROI_Left_L5 = get_num(T4{12, colIdx});

        s.ROI_Full_L1 = get_num(T4{13, colIdx});
        s.ROI_Full_L2 = get_num(T4{14, colIdx});
        s.ROI_Full_L3 = get_num(T4{15, colIdx});
        s.ROI_Full_L4 = get_num(T4{16, colIdx});
        s.ROI_Full_L5 = get_num(T4{17, colIdx});

        % Ratios and Rate of Change
        s.Ratio_Left_L4_L5 = get_num(T4{18, colIdx});
        s.RateOfChange_Left = get_num(T4{19, colIdx});

        % Right side ratio if L4 and L5 exist
        if ~isnan(s.ROI_Right_L4) && ~isnan(s.ROI_Right_L5) && s.ROI_Right_L5 ~= 0
            s.Ratio_Right_L4_L5 = s.ROI_Right_L4 / s.ROI_Right_L5;
        else
            s.Ratio_Right_L4_L5 = NaN;
        end
        s.RateOfChange_Right = NaN;

        db_manager('save_scan', s);
    end

    %% 4. Verification and Summary
    fprintf('\n--- Step 4: Verifying Migrated Database ---\n');
    visits = db_manager('get_visits');
    scans  = db_manager('get_scans');
    summary = db_manager('get_summary');

    fprintf('  Total Visits Imported: %d\n', height(visits));
    fprintf('  Total Scans Imported:  %d\n', height(scans));
    fprintf('  Database Location:     %s\n\n', dbPath);

    fprintf('--- Sample of Imported Visit Summary ---\n');
    disp(summary(1:min(5, height(summary)), {'VisitNum', 'VisitDate', 'CentralThickness_OD', 'Mean_Ratio_Left_L4_L5', 'Std_Ratio_Left_L4_L5'}));

    fprintf('Migration completed successfully!\n');
end

function val = get_num(cellVal)
    if isempty(cellVal) || any(ismissing(cellVal))
        val = NaN;
    elseif isnumeric(cellVal)
        val = double(cellVal);
    else
        parsed = str2double(string(cellVal));
        if isnan(parsed)
            val = NaN;
        else
            val = parsed;
        end
    end
end
