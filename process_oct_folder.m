function visitNum = process_oct_folder(folderPath, options)
    if nargin < 2, options = struct(); end
    if ~isfield(options, 'plotoption'), options.plotoption = 0; end
    if ~isfield(options, 'MODEL') || isempty(options.MODEL)
        disp('Initializing SAM segmentAnythingModel...');
        MODEL = segmentAnythingModel;
    else
        MODEL = options.MODEL;
    end
    if ~isfolder(folderPath)
        error('Specified folder does not exist: %s', folderPath);
    end
    [~, folderName, ~] = fileparts(folderPath);
    fileList = dir(fullfile(folderPath, '*.bmp'));
    numFiles = length(fileList);
    if numFiles == 0
        error('No .bmp scan files found in: %s', folderPath);
    end
    
    if isfield(options, 'targetIndices') && ~isempty(options.targetIndices)
        targetIndices = options.targetIndices;
    else
        targetIndices = [1, 2, numFiles];
    end
    targetIndices = targetIndices(targetIndices >= 1 & targetIndices <= numFiles);
    
    [extractedDate, extractedEye] = parse_folder_metadata(folderName);
    eyeSide = extractedEye;
    if isfield(options, 'EyeSide') && ~isempty(options.EyeSide)
        eyeSide = upper(string(options.EyeSide));
    end
    
    isLeftEye = (eyeSide == "OS");
    
    visitDate = extractedDate;
    if isfield(options, 'VisitDate') && ~isempty(options.VisitDate)
        if isa(options.VisitDate, 'datetime')
            visitDate = options.VisitDate;
        else
            visitDate = datetime(options.VisitDate, 'InputFormat', 'yyyy-MM-dd');
        end
    end
    
    Visits = db_manager('get_visits');
    if isfield(options, 'VisitNum') && ~isempty(options.VisitNum)
        visitNum = int32(options.VisitNum);
    else
        matchedIdx = find(Visits.VisitDate == visitDate, 1);
        if ~isempty(matchedIdx)
            visitNum = Visits.VisitNum(matchedIdx);
            fprintf('Matched existing Visit #%d for date %s.\n', visitNum, datestr(visitDate, 'yyyy-mm-dd'));
        else
            if isempty(Visits), visitNum = int32(1); else, visitNum = int32(max(Visits.VisitNum) + 1); end
            fprintf('Assigned new Visit #%d for date %s.\n', visitNum, datestr(visitDate, 'yyyy-mm-dd'));
        end
    end
    
    vData = struct();
    vData.VisitNum = visitNum;
    vData.VisitDate = visitDate;
    if isfield(options, 'CentralThickness_OD'), vData.CentralThickness_OD = options.CentralThickness_OD; end
    if isfield(options, 'CentralThickness_OS'), vData.CentralThickness_OS = options.CentralThickness_OS; end
    if isfield(options, 'Notes'), vData.Notes = options.Notes; end
    db_manager('save_visit', vData);
    
    fprintf('====================================================\n');
    fprintf('Processing OCT Folder: %s\n', folderName);
    fprintf('Visit: #%d | Date: %s | Eye: %s | Slices: %s\n', visitNum, datestr(visitDate, 'yyyy-mm-dd'), eyeSide, mat2str(targetIndices));
    fprintf('====================================================\n');
    
    for i = 1:length(targetIndices)
        idx = targetIndices(i);
        fileName = fileList(idx).name;
        fprintf('  --> Processing Slice %d of %d (Index %d): %s\n', i, length(targetIndices), idx, fileName);
        try
            [I_crop_orig, I_crop_aligned, embeddings_aligned, sy, sx, angle_deg, I_true_raw, geom] = ...
                preprocess_OCT(folderPath, fileName, MODEL, isLeftEye);
            [Layer_ILM, h1] = segment_ILM(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, options.plotoption);
            [is_hole_found, Mask_Hole, MaxPH, indMaxPH] = ...
                detect_hole(I_crop_aligned, MODEL, embeddings_aligned, sy, sx, Layer_ILM, options.plotoption, h1);
            [Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top] = ...
                segment_layers(I_crop_aligned, MODEL, sy, sx, MaxPH, indMaxPH, Layer_ILM, Mask_Hole, options.plotoption, h1);
            
            [STATS_Full, STATS_Right, STATS_Left] = ...
                analyze_rois(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, ...
                             sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, ...
                             Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1, I_true_raw, geom);
                             
            [STATS_Full_fw, STATS_Right_fw, STATS_Left_fw] = ...
                analyze_rois_fixed_width(I_crop_orig, I_crop_aligned, angle_deg, is_hole_found, Mask_Hole, sy, ...
                             sx, Layer_Blue1, Layer_Blue2, Layer_Blue3, Layer_Blue4, ...
                             Layer_Inner_Bot, Layer_RPE_bot, Layer_RPE_top, Layer_ILM, h1, I_true_raw, geom);
            
            if ~options.plotoption, close all hidden; end
            
            % Assemble Scan Record dynamically
            scanRecord = struct();
            scanRecord.VisitNum = visitNum;
            scanRecord.ImageIndex = i; 
            scanRecord.EyeSide = eyeSide;
            scanRecord.FileName = fileName;
            
            % DYNAMICALLY EXTRACT ALL TEXTURE METRICS (CR, Densito, GAM, NK)
            scanRecord = extract_texture_metrics(scanRecord, STATS_Right, 'Right', '');
            scanRecord = extract_texture_metrics(scanRecord, STATS_Left, 'Left', '');
            scanRecord = extract_texture_metrics(scanRecord, STATS_Full, 'Full', '');
            
            scanRecord = extract_texture_metrics(scanRecord, STATS_Right_fw, 'Right', '_fw');
            scanRecord = extract_texture_metrics(scanRecord, STATS_Left_fw, 'Left', '_fw');
            scanRecord = extract_texture_metrics(scanRecord, STATS_Full_fw, 'Full', '_fw');
            
            db_manager('save_scan', scanRecord);
            fprintf('      Successfully saved slice %d (Texture values recorded).\n', i);
        catch ME
            warning('Failed processing file %s: %s', fileName, ME.message);
        end
    end
    fprintf('\nUpdating longitudinal statistics and rates of change across visits...\n');
    compute_statistics('update_all');
    fprintf('Folder processing complete! Database updated for Visit #%d.\n\n', visitNum);
end

%% Helper to dynamically map ALL PDF parameters AND GoF into the DB fields
function record = extract_texture_metrics(record, stats_struct, sideName, suffix)
    if isempty(stats_struct) || ~isstruct(stats_struct), return; end
    if strcmp(sideName, 'Full'), structPrefix = 'Layer'; else, structPrefix = sideName(1); end
    
    for i = 1:5
        fName = sprintf('%s%d', structPrefix, i); 
        if isfield(stats_struct, fName) && ~isempty(stats_struct.(fName))
            st = stats_struct.(fName);
            % Original Stats
            record.(sprintf('ROI_%s_L%d%s', sideName, i, suffix)) = st.CR;
            record.(sprintf('ROI_%s_L%d_Densito%s', sideName, i, suffix)) = st.Densito;
            
            % All 8 Distribution Parameters
            record.(sprintf('ROI_%s_L%d_GAM_A%s', sideName, i, suffix)) = st.GAM(1);
            record.(sprintf('ROI_%s_L%d_GAM_B%s', sideName, i, suffix)) = st.GAM(2);
            record.(sprintf('ROI_%s_L%d_NK_mu%s', sideName, i, suffix)) = st.NK(1);
            record.(sprintf('ROI_%s_L%d_NK_om%s', sideName, i, suffix)) = st.NK(2);
            record.(sprintf('ROI_%s_L%d_EXP_mu%s', sideName, i, suffix)) = st.EXP(1);
            record.(sprintf('ROI_%s_L%d_RAY_B%s', sideName, i, suffix)) = st.RAY(1);
            record.(sprintf('ROI_%s_L%d_WBL_A%s', sideName, i, suffix)) = st.WBL(1);
            record.(sprintf('ROI_%s_L%d_WBL_B%s', sideName, i, suffix)) = st.WBL(2);
            record.(sprintf('ROI_%s_L%d_LN_mu%s', sideName, i, suffix)) = st.LN(1);
            record.(sprintf('ROI_%s_L%d_LN_sig%s', sideName, i, suffix)) = st.LN(2);
            record.(sprintf('ROI_%s_L%d_BURR_A%s', sideName, i, suffix)) = st.BURR(1);
            if length(st.BURR) > 1, record.(sprintf('ROI_%s_L%d_BURR_B%s', sideName, i, suffix)) = st.BURR(2); end
            record.(sprintf('ROI_%s_L%d_K_A%s', sideName, i, suffix)) = st.K(1);
            if length(st.K) > 1, record.(sprintf('ROI_%s_L%d_K_B%s', sideName, i, suffix)) = st.K(2); end
            
            % Goodness of Fit (GoF) Array: [BURR, EXP, GAM, K, LN, NK, RAY, WBL]
            if isfield(st, 'GOF') && length(st.GOF) == 8
                record.(sprintf('ROI_%s_L%d_GoF_BURR%s', sideName, i, suffix)) = st.GOF(1);
                record.(sprintf('ROI_%s_L%d_GoF_EXP%s',  sideName, i, suffix)) = st.GOF(2);
                record.(sprintf('ROI_%s_L%d_GoF_GAM%s',  sideName, i, suffix)) = st.GOF(3);
                record.(sprintf('ROI_%s_L%d_GoF_K%s',    sideName, i, suffix)) = st.GOF(4);
                record.(sprintf('ROI_%s_L%d_GoF_LN%s',   sideName, i, suffix)) = st.GOF(5);
                record.(sprintf('ROI_%s_L%d_GoF_NK%s',   sideName, i, suffix)) = st.GOF(6);
                record.(sprintf('ROI_%s_L%d_GoF_RAY%s',  sideName, i, suffix)) = st.GOF(7);
                record.(sprintf('ROI_%s_L%d_GoF_WBL%s',  sideName, i, suffix)) = st.GOF(8);
            end
        end
    end
end

%% Parse Date and Eye Side from Folder Name
function [vDate, eyeSide] = parse_folder_metadata(folderName)
    vDate = datetime('today'); eyeSide = "OD";
    if contains(folderName, '_Retina_Radial_L_', 'IgnoreCase', true) || contains(folderName, '_L_', 'IgnoreCase', true)
        eyeSide = "OS";
    elseif contains(folderName, '_Retina_Radial_R_', 'IgnoreCase', true) || contains(folderName, '_R_', 'IgnoreCase', true)
        eyeSide = "OD";
    end
    dateTokens = regexp(folderName, '(20\d{6})', 'match');
    if ~isempty(dateTokens)
        try, vDate = datetime(dateTokens{end}, 'InputFormat', 'yyyyMMdd'); catch, end
    end
end