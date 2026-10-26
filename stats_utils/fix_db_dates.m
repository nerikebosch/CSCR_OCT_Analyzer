function fix_db_dates()
    % This script re-sorts the database chronologically by VisitDate
    
    dbPath = fullfile(pwd, 'oct_study_db.mat');
    if ~isfile(dbPath)
        disp('Database not found.'); return;
    end
    
    data = load(dbPath);
    V = data.DB.Visits;
    S = data.DB.Scans;
    
    % Sort visits by date
    V_sorted = sortrows(V, 'VisitDate');
    old_nums = V_sorted.VisitNum;
    
    % Re-number visits and update the matching scans
    for i = 1:height(V_sorted)
        new_num = int32(i);
        % Update scans that belonged to the old visit number
        S.VisitNum(S.VisitNum == old_nums(i)) = new_num;
        % Update the visit table itself
        V_sorted.VisitNum(i) = new_num;
    end
    
    % Save it back
    data.DB.Visits = sortrows(V_sorted, 'VisitNum');
    data.DB.Scans = sortrows(S, {'VisitNum', 'EyeSide', 'ImageIndex'});
    save(dbPath, '-struct', 'data', '-v7.3');
    
    disp('Database successfully re-sorted chronologically!');
end