function SimulinkBatchModifierGUI_V21()
% --- Simulink批量修改工具 V20.2.21 (“终极版”) ---
% =========================================================================
% ★★★★★【使 用 必 读】★★★★★
% 1. 在运行此脚本前，请务必先手动、完整地初始化您的Simulink项目环境。
% =========================================================================
% V20.2.20 (Bus Safety Fix) 更新日志:
% - [核心安全修复] 新增了对总线（Bus）信号线的检测逻辑。脚本现在会自动
%   识别并跳过所有直接连接到 Bus Selector 或 Bus Creator 模块的信号线，
%   彻底解决了因尝试修改受控总线信号名而导致的程序崩溃问题。
%
% V20.2.19 (Final Bug Fix) 更新日志:
% - [兼容性/Bug修复] 修复了Clear按钮在旧版MATLAB中因UI组件bug导致的崩溃问题。
% =========================================================================
% 新增功能：批量模式
% - 在功能1面板中启用“批量模式”后，可加载一个Excel文件（第一列原字符串，第二列新字符串），
%   程序将按顺序应用所有替换规则。

% --- 初始化主窗口和数据结构 ---
app = struct();
app.UIFigure = uifigure('Name', 'Simulink 批量修改与接口工具 V20.2.20 (终极版)', ...
'Position', [100 100 1000, 650], ...
'Visible', 'off');
createComponents();
app.UIFigure.Visible = 'on';

%% %%%%%%%%%%%%%%%%%%%%% UI组件创建函数 (内嵌) %%%%%%%%%%%%%%%%%%%%%%%%%%
function createComponents()
    uibutton(app.UIFigure, 'push', 'Text', '选择模型文件...', 'Position', [20, 600, 120, 30], 'ButtonPushedFcn', @SelectModelButtonPushed);
    app.ModelPathField = uieditfield(app.UIFigure, 'text', 'Editable', 'off', 'Position', [150, 600, 650, 30]);
    
    % --- 功能1面板，增加批量模式控件 ---
    app.Function1Panel = uipanel(app.UIFigure, 'Title', '功能1: 名称批量修改 (不区分大小写)', 'Position', [20, 420, 380, 170]);
    app.EnableF1CheckBox = uicheckbox(app.Function1Panel, 'Text', '启用此功能', 'Position', [15, 124, 100, 22], 'Value', true);
    
    % 批量模式开关
    app.BatchModeCheckBox = uicheckbox(app.Function1Panel, 'Text', '批量模式 (从Excel加载多组规则)', ...
        'Position', [120, 124, 250, 22], 'Value', false, 'ValueChangedFcn', @BatchModeToggled);
    
    modePanel = uipanel(app.Function1Panel, 'Title', '修改模式', 'Position', [15, 65, 350, 60]);
    bg = uibuttongroup(modePanel, 'Position', [1, 1, 348, 58]);
    app.PrefixModeButton = uiradiobutton(bg, 'Text', '① 前缀修改', 'Position', [10, 10, 120, 22], 'Value', true);
    app.KeywordModeButton = uiradiobutton(bg, 'Text', '② 关键词修改', 'Position', [220, 10, 120, 22]);
    
    % 单条模式输入框
    app.SingleOldLabel = uilabel(app.Function1Panel, 'Text', '原前缀/关键词', 'Position', [15, 30, 90, 22]);
    app.OldStringField = uieditfield(app.Function1Panel, 'text', 'Position', [110, 30, 255, 22]);
    app.SingleNewLabel = uilabel(app.Function1Panel, 'Text', '新前缀/关键词', 'Position', [15, 5, 90, 22]);
    app.NewStringField = uieditfield(app.Function1Panel, 'text', 'Position', [110, 5, 255, 22]);
    
    % 批量模式控件 (初始隐藏)
    app.BatchFileButton = uibutton(app.Function1Panel, 'push', 'Text', '选择批量Excel...', ...
        'Position', [15, 30, 120, 22], 'ButtonPushedFcn', @SelectBatchExcelButtonPushed, 'Visible', 'off');
    app.BatchFilePathField = uieditfield(app.Function1Panel, 'text', 'Editable', 'off', ...
        'Position', [140, 30, 225, 22], 'Visible', 'off');
    app.BatchRuleCountLabel = uilabel(app.Function1Panel, 'Text', '已加载 0 条规则', ...
        'Position', [15, 5, 200, 22], 'Visible', 'off', 'FontColor', [0 0.5 0]);
    
    % 初始化批量数据结构
    app.BatchMode = false;
    app.BatchRenameRules = {};  % cell of struct('old','new')
    
    % --- 其余面板保持不变 ---
    app.Function2Panel = uipanel(app.UIFigure, 'Title', '功能2: 名称规范检查及修正', 'Position', [20, 255, 380, 155]);
    app.EnableF2CheckBox = uicheckbox(app.Function2Panel, 'Text', '启用此功能 (名称规范化)', 'Position', [15, 110, 350, 22], 'Value', true);
    uilabel(app.Function2Panel, 'Text', '说明:该功能只会对执行功能1的名称进行规范化检查及修正', 'Position', [25, 85, 340, 18], 'FontColor', [0.6 0.6 0.6]);
    uilabel(app.Function2Panel, 'Text', '· 信号名称首段大写，次段首字母大写，其余小写', 'Position', [25, 60, 340, 22]);
    uilabel(app.Function2Panel, 'Text', '· 标定量全部大写', 'Position', [25, 35, 340, 22]);
    app.EnableFamilySepCheckBox = uicheckbox(app.Function2Panel, 'Text', '自动检索fl\fr\rl\rr，frle\frri\rele\reri，fa\ra并分离', 'Position', [25, 10, 350, 22], 'Value', true);
    
    app.ExcelPanel = uipanel(app.UIFigure, 'Title', '功能3: 配套Interface Excel修改', 'Position', [20, 160, 380, 85]);
    app.EnableExcelCheckBox = uicheckbox(app.ExcelPanel, 'Text', '启用Excel修改功能', 'Position', [15, 35, 350, 22], 'Enable', 'off');
    app.ExcelStatusLabel = uilabel(app.ExcelPanel, 'Text', '请先选择模型文件...', 'Position', [15, 10, 350, 22], 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    app.RunButton = uibutton(app.UIFigure, 'push', 'Text', '开始执行', 'Position', [20, 110, 380, 40], 'FontSize', 14, 'FontWeight', 'bold', 'ButtonPushedFcn', @RunButtonPushed, 'Enable', 'off');
    
    app.LogArea = uitextarea(app.UIFigure, 'Editable', 'off', 'Position', [420, 235, 560, 395], 'Value', '');
    learnedPanel = uipanel(app.UIFigure, 'Title', '预处理记忆库', 'Position', [420, 20, 560, 205]);
    app.LearnedArea = uitextarea(learnedPanel, 'Editable', 'off', 'Position', [10, 35, 540, 155], 'Value', '');
    uibutton(learnedPanel, 'push', 'Text', 'Clear', 'Position', [490, 5, 60, 22], 'ButtonPushedFcn', @ClearLearnedMapButtonPushed);
    
    app.ProgressBar = uigauge(app.UIFigure, 'semicircular', 'Position', [20, 20, 180, 80]);
    app.ProgressLabel = uilabel(app.UIFigure, 'HorizontalAlignment', 'center', 'Position', [220, 50, 160, 22], 'Text', '进度: 0%');
    app.ModelPath = ''; app.ExcelPath = ''; app.TotalSteps = 0; app.CurrentStep = 0;
    app.DetailedLog = {};
    app.LearnedMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
end

% --- 批量模式开关回调 ---
function BatchModeToggled(~, ~)
    app.BatchMode = app.BatchModeCheckBox.Value;
    if app.BatchMode
        app.SingleOldLabel.Visible = 'off';
        app.OldStringField.Visible = 'off';
        app.SingleNewLabel.Visible = 'off';
        app.NewStringField.Visible = 'off';
        app.BatchFileButton.Visible = 'on';
        app.BatchFilePathField.Visible = 'on';
        app.BatchRuleCountLabel.Visible = 'on';
    else
        app.SingleOldLabel.Visible = 'on';
        app.OldStringField.Visible = 'on';
        app.SingleNewLabel.Visible = 'on';
        app.NewStringField.Visible = 'on';
        app.BatchFileButton.Visible = 'off';
        app.BatchFilePathField.Visible = 'off';
        app.BatchRuleCountLabel.Visible = 'off';
    end
end

% --- 批量Excel选择回调 (兼容旧版MATLAB，无列名要求) ---
function SelectBatchExcelButtonPushed(~, ~)
    [file, path] = uigetfile({'*.xlsx;*.xls'}, '选择批量替换规则Excel文件');
    if isequal(file, 0)
        log('用户取消选择批量Excel文件');
        return;
    end
    fullPath = fullfile(path, file);
    app.BatchFilePathField.Value = fullPath;
    try
        % 使用xlsread读取所有原始数据（兼容各版本MATLAB）
        [~, ~, raw] = xlsread(fullPath);
        if size(raw, 1) < 2
            error('Excel文件至少需要包含一行数据（请从第二行开始填写规则）。');
        end
        % 从第二行开始提取第一列和第二列
        rules = {};
        for i = 2:size(raw, 1)
            if size(raw, 2) < 2
                continue;   % 列数不足则跳过该行
            end
            oldRaw = raw{i, 1};
            newRaw = raw{i, 2};
            
            % 将数值或字符串统一转换为字符数组
            if isnumeric(oldRaw)
                oldStr = num2str(oldRaw);
            elseif ischar(oldRaw) || isstring(oldRaw)
                oldStr = char(oldRaw);
            else
                continue;   % 不支持的类型跳过
            end
            
            if isnumeric(newRaw)
                newStr = num2str(newRaw);
            elseif ischar(newRaw) || isstring(newRaw)
                newStr = char(newRaw);
            else
                continue;
            end
            
            % 去除首尾空格并检查非空
            oldStr = strtrim(oldStr);
            newStr = strtrim(newStr);
            if isempty(oldStr) || isempty(newStr)
                continue;
            end
            
            rules{end+1} = struct('old', oldStr, 'new', newStr);
        end
        
        if isempty(rules)
            error('未找到有效的替换规则。请确保Excel第二行起的第一列和第二列均非空。');
        end
        
        app.BatchRenameRules = rules;
        app.BatchRuleCountLabel.Text = sprintf('已加载 %d 条规则', length(rules));
        log(sprintf('批量规则加载成功，共 %d 条规则。', length(rules)));
    catch ME
        errordlg(['加载批量Excel失败: ' ME.message], '错误');
        log(['加载批量Excel失败: ' ME.message]);
        app.BatchRenameRules = {};
        app.BatchRuleCountLabel.Text = '已加载 0 条规则';
    end
end

%% %%%%%%%%%%%%%%%%%%%%% 回调函数和辅助函数区 (全部内嵌) %%%%%%%%%%%%%%%%%%%%%%
function SelectModelButtonPushed(~, ~)
    [file, path] = uigetfile({'*.slx;*.mdl'}, '选择Simulink模型文件 (*.slx, *.mdl)');
    if isequal(file, 0), log('用户取消选择'); return; end
    app.ModelPath = fullfile(path, file);
    app.ModelPathField.Value = app.ModelPath;
    log(['已选择模型: ' app.ModelPath]);
    
    app.RunButton.Enable = 'on';
    
    [~, modelName, ~] = fileparts(file);
    expectedExcelName = ['interface' modelName];
    excelPathXlsx = fullfile(path, [expectedExcelName '.xlsx']);
    excelPathXls = fullfile(path, [expectedExcelName '.xls']);
    
    found = false;
    if exist(excelPathXlsx, 'file'), app.ExcelPath = excelPathXlsx; found = true;
    elseif exist(excelPathXls, 'file'), app.ExcelPath = excelPathXls; found = true; end
    
    if found
        [~, excelFile, ext] = fileparts(app.ExcelPath);
        app.ExcelStatusLabel.Text = ['已找到配套文件: ' excelFile ext];
        app.ExcelStatusLabel.FontColor = [0, 0.5, 0];
        app.EnableExcelCheckBox.Enable = 'on';
        app.EnableExcelCheckBox.Value = true;
        log(['已找到配套Excel文件: ' app.ExcelPath]);
    else
        app.ExcelPath = '';
        app.ExcelStatusLabel.Text = '未找到配套的Excel文件';
        app.ExcelStatusLabel.FontColor = [1, 0, 0];
        app.EnableExcelCheckBox.Enable = 'off';
        app.EnableExcelCheckBox.Value = false;
        log('提示: 未在模型目录下找到配套的Excel文件，将仅处理模型。');
    end
end

function RunButtonPushed(~, ~)
    if isempty(app.ModelPath), errordlg('请先选择一个模型文件！', '错误'); return; end
    if ~app.EnableF1CheckBox.Value && ~app.EnableF2CheckBox.Value, msgbox('请至少启用一个功能！', '提示'); return; end
    if app.EnableF1CheckBox.Value && app.BatchMode && isempty(app.BatchRenameRules)
        errordlg('批量模式已启用但未加载有效规则，请先选择批量Excel文件。', '错误'); return;
    end
    
    app.RunButton.Enable = 'off'; app.LogArea.Value = ''; app.DetailedLog = {};
    app.ProgressBar.Value = 0; app.ProgressLabel.Text = '进度: 0%'; app.CurrentStep = 0;
    newModelName = '';
    
    try
        log('开始处理...');
        
        excelSteps = 0;
        if app.EnableExcelCheckBox.Value && ~isempty(app.ExcelPath)
            [excelPath_p, excelName_n, excelExt_e] = fileparts(app.ExcelPath);
            newExcelName = [excelName_n '_modified' excelExt_e];
            newExcelPath = fullfile(excelPath_p, newExcelName);
            log('正在创建Excel副本...');
            copyfile(app.ExcelPath, newExcelPath, 'f');
            log(['Excel副本已创建: ' newExcelPath]);
            excelSteps = countExcelSteps(newExcelPath);
        end
        
        [filepath, name, ext] = fileparts(app.ModelPath);
        newModelName = [name '_modified']; newModelPath = fullfile(filepath, [newModelName ext]);
        if bdIsLoaded(newModelName), close_system(newModelName, 0); end
        log('正在创建模型副本...');
        copyfile(app.ModelPath, newModelPath, 'f');
        log(['模型副本已创建: ' newModelPath]);
        log('正在加载模型副本...');
        load_system(newModelPath);

        log('扫描并排序Simulink对象...', false);
        allBlockPaths = find_system(newModelName, 'LookUnderMasks', 'all', 'FollowLinks', 'off', 'Type', 'Block');
        allBlockHandles = get_param(allBlockPaths, 'Handle'); if iscell(allBlockHandles); allBlockHandles = cell2mat(allBlockHandles); end
        blockDepths = arrayfun(@(h) length(strfind(getfullname(h), '/')), allBlockHandles);
        [~, sortedIdx] = sort(blockDepths, 'descend'); sortedBlockHandles = allBlockHandles(sortedIdx);
        allLineHandles = find_system(newModelName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'FindAll', 'on', 'Type', 'Line');
        sfRoot = sfroot; machine = sfRoot.find('-isa', 'Stateflow.Machine', 'Name', newModelName);
        allSfObjects = []; if ~isempty(machine); allSfObjects = machine.find('-isa', 'Stateflow.Object'); end
        validSfObjects = {}; sfDepths = [];
        for i = 1:length(allSfObjects), if isprop(allSfObjects(i), 'Path') && ~isempty(allSfObjects(i).Path), validSfObjects{end+1} = allSfObjects(i); sfDepths(end+1) = length(strfind(allSfObjects(i).Path, '/')); end, end
        [~, sortedIdx] = sort(sfDepths, 'descend'); sortedSfObjects = validSfObjects(sortedIdx);
        
        log('构建方向信号家族命名映射表 (如果已启用)...', false);
        directionalRenameMap = buildDirectionalRenameMap(sortedBlockHandles, allLineHandles, sortedSfObjects);

        app.TotalSteps = excelSteps + length(sortedBlockHandles) + length(allLineHandles) + length(sortedSfObjects);
        log(['预计总步骤: ' num2str(app.TotalSteps)]);

        if app.EnableExcelCheckBox.Value && ~isempty(app.ExcelPath)
            processExcelFile(newExcelPath, directionalRenameMap);
        end
        
        processAllObjects(sortedBlockHandles, allLineHandles, sortedSfObjects, directionalRenameMap);
        
        log('所有任务执行完毕，正在保存...');
        allLoadedModels = find_system('SearchDepth', 0, 'Type', 'block_diagram');
        originalCallbacks = {};
        for i = 1:length(allLoadedModels)
            model = allLoadedModels{i};
            if strcmp(get_param(model, 'Lock'), 'on'), continue; end
            callbacks_row = {model, get_param(model, 'PreSaveFcn'), get_param(model, 'PostSaveFcn')};
            originalCallbacks(end+1, :) = callbacks_row;
            set_param(model, 'PreSaveFcn', ''); set_param(model, 'PostSaveFcn', '');
        end
        cleanupObj = onCleanup(@() restoreAllCallbacks(originalCallbacks));
        try, save_system(newModelName); catch saveME, rethrow(saveME); end
        close_system(newModelName);
        log(['新模型已保存至: ' newModelPath]);
        
        writeLogToTxt(filepath, name);
        
        msgbox('处理完成！', '成功');
        if ~isempty(filepath) && exist(filepath, 'dir'), log(['正在将MATLAB当前目录切换到: ' filepath]); cd(filepath); end
    catch ME
        errordlg(['发生错误: ' ME.message], '执行失败');
        log(['错误: ' ME.getReport('basic')]);
        if ~isempty(newModelName) && bdIsLoaded(newModelName), close_system(newModelName, 0); end
    end
    app.RunButton.Enable = 'on';
end

% ############# START: MODIFIED FUNCTION #############
function processAllObjects(blockHandles, lineHandles, sfObjects, directionalRenameMap)
    log('--- 开始单遍处理所有Simulink对象 ---');
    for i = 1:length(blockHandles)
        handle = blockHandles(i); linkStatus = get_param(handle, 'LinkStatus');
        if ~strcmpi(linkStatus, 'none'), updateProgress(); continue; end
        blockType = get_param(handle, 'BlockType');
        if contains(blockType, 'Lookup')
            finalTableName = '';
            try, originalTableParam = get_param(handle, 'Table'); if ischar(originalTableParam) && ~isempty(originalTableParam), finalTableName = calculateFinalName(originalTableParam, 'parameter', directionalRenameMap); if ~strcmp(originalTableParam, finalTableName), set_param(handle, 'Table', finalTableName); logDetail(sprintf('Block Param (Table): "%s" -> "%s"', originalTableParam, finalTableName)); end, end, catch, end
            originalName = get_param(handle, 'Name'); if ~isempty(finalTableName) && ~strcmp(originalName, finalTableName), safeSetParam(handle, 'Name', finalTableName); end
            otherParams = {'BreakpointsForDimension1', 'BreakpointsForDimension2', 'BreakpointsForDimension3'};
            for p_idx = 1:length(otherParams)
                try, originalParam = get_param(handle, otherParams{p_idx}); if ischar(originalParam) && ~isempty(originalParam), finalParam = calculateFinalName(originalParam, 'parameter', directionalRenameMap); if ~strcmp(originalParam, finalParam), set_param(handle, otherParams{p_idx}, finalParam); logDetail(sprintf('Block Param (%s): "%s" -> "%s"', get_param(handle, 'Name'), originalParam, finalParam)); end, end, catch, end
            end
        else
            originalName = get_param(handle, 'Name'); finalName = calculateFinalName(originalName, 'signal', directionalRenameMap);
            if ~strcmp(originalName, finalName), safeSetParam(handle, 'Name', finalName); end
            paramsToModify = {}; paramType = 'parameter';
            if strcmp(blockType, 'Constant'), paramsToModify = {'Value'};
            elseif any(strcmp(blockType, {'Goto', 'From'})), paramsToModify = {'GotoTag'}; paramType = 'signal';
            end
            for p_idx = 1:length(paramsToModify)
                try, originalParam = get_param(handle, paramsToModify{p_idx}); if ischar(originalParam) && ~isempty(originalParam), finalParam = calculateFinalName(originalParam, paramType, directionalRenameMap); if ~strcmp(originalParam, finalParam), set_param(handle, paramsToModify{p_idx}, finalParam); logDetail(sprintf('Block Param (%s): "%s" -> "%s"', get_param(handle, 'Name'), originalParam, finalParam)); end, end, catch, end
            end
        end
        updateProgress();
    end
    
    for i = 1:length(lineHandles)
        handle = lineHandles(i);
        
        % --- 安全修复: 检查信号线是否连接到总线模块 ---
        isBusLine = false;
        try
            srcPort = get_param(handle, 'SrcPortHandle');
            if srcPort > 0
                srcBlockType = get_param(get_param(srcPort, 'Parent'), 'BlockType');
                if any(strcmpi(srcBlockType, {'BusSelector', 'BusCreator'}))
                    isBusLine = true;
                end
            end
            
            if ~isBusLine
                dstPorts = get_param(handle, 'DstPortHandle');
                for j = 1:length(dstPorts)
                    if dstPorts(j) > 0
                        dstBlockType = get_param(get_param(dstPorts(j), 'Parent'), 'BlockType');
                        if any(strcmpi(dstBlockType, {'BusSelector', 'BusCreator'}))
                            isBusLine = true;
                            break;
                        end
                    end
                end
            end
        catch
            % 忽略在检查过程中可能出现的任何错误
            isBusLine = false; 
        end
        
        if isBusLine
            originalName = get_param(handle, 'Name');
            if ~isempty(originalName)
                log(['跳过连接到总线模块的信号线: ' originalName], false);
            end
            updateProgress();
            continue;
        end
        % --- 修复结束 ---
        
        originalName = get_param(handle, 'Name');
        if ~isempty(originalName)
            finalName = calculateFinalName(originalName, 'signal', directionalRenameMap);
            if ~strcmp(originalName, finalName)
                safeSetParam(handle, 'Name', finalName);
            end
        end
        updateProgress();
    end
    
    for i = 1:length(sfObjects)
        sfObj = sfObjects{i};
        if isprop(sfObj, 'Name') && ~isempty(sfObj.Name), originalName = sfObj.Name; finalName = calculateFinalName(originalName, 'signal', directionalRenameMap); if ~strcmp(originalName, finalName), safeSetSfName(sfObj, finalName); end, end
        if isprop(sfObj, 'LabelString') && ~isempty(sfObj.LabelString), originalContent = sfObj.LabelString; finalContent = originalContent; words = unique(regexp(originalContent, '\w+', 'match'), 'stable'); for w_idx = 1:length(words), word = words{w_idx}; finalWord = calculateFinalName(word, 'auto', directionalRenameMap); if ~strcmp(word, finalWord), finalContent = regexprep(finalContent, ['\<' word '\>'], finalWord); end, end, if ~strcmp(originalContent, finalContent), sf('set', sfObj.Id, '.labelString', finalContent); logDetail(sprintf('SF Content: "%s" -> "%s"', strrep(originalContent,newline,'\n'), strrep(finalContent,newline,'\n'))); end, end
        updateProgress();
    end
end
% ############# END: MODIFIED FUNCTION #############

function processExcelFile(filePath, directionalRenameMap)
    log('--- 开始处理Excel文件 ---');
    targetSheets = {'IN', 'OUT', 'MP', 'CAL', 'NVV'};
    
    try, [~, sheetNames] = xlsfinfo(filePath); catch ME, error('...无法读取Excel文件信息...'); end
    
    for i = 1:length(targetSheets)
        sheet = targetSheets{i};
        if ~ismember(sheet, sheetNames), log(['Excel警告: 未找到 "' sheet '" sheet, 跳过。']); continue; end
        
        log(['正在处理 sheet: ' sheet]);
        T = readtable(filePath, 'Sheet', sheet);
        
        varNames = T.Properties.VariableNames;
        [nameFound, nameColIdx] = ismember('name', lower(varNames));
        
        if ~nameFound, log(['Excel警告: Sheet "' sheet '" 中未找到 "name"列, 跳过。']); continue; end
        actualNameCol = varNames{nameColIdx};
        
        originalNames = T.(actualNameCol);
        newNames = originalNames;
        
        for k = 1:height(T)
            originalName = originalNames{k};
            if ~ischar(originalName) || isempty(originalName), updateProgress(); continue; end
            
            nameAfterF1 = originalName;
            if app.EnableF1CheckBox.Value, nameAfterF1 = applyF1Rule(originalName); end

            nameWasChangedByF1 = ~strcmp(originalName, nameAfterF1);
            finalName = nameAfterF1;
            
            if app.EnableF2CheckBox.Value && nameWasChangedByF1
                nameToNormalize = nameAfterF1;
                if isKey(app.LearnedMap, nameAfterF1)
                    nameToNormalize = app.LearnedMap(nameAfterF1);
                elseif app.EnableFamilySepCheckBox.Value && isKey(directionalRenameMap, nameAfterF1)
                    nameToNormalize = directionalRenameMap(nameAfterF1);
                end
                
                if any(strcmpi(sheet, {'IN', 'OUT', 'MP'}))
                    finalName = applyF2Rule(nameToNormalize, 'signal');
                elseif any(strcmpi(sheet, {'CAL', 'NVV'}))
                    finalName = applyF2Rule(nameToNormalize, 'parameter');
                end
            end
            
            newNames{k} = finalName;
            
            if ~strcmp(originalName, finalName)
                logDetail(sprintf('Excel (%s): "%s" -> "%s"', sheet, originalName, finalName));
            end
            updateProgress();
        end
        
        T.(actualNameCol) = newNames;
        writetable(T, filePath, 'Sheet', sheet);
    end
    log('--- Excel文件处理完毕 ---');
end

function stepCount = countExcelSteps(filePath)
    stepCount = 0;
    targetSheets = {'IN', 'OUT', 'MP', 'CAL', 'NVV'};
    try
        [~, sheetNames] = xlsfinfo(filePath);
        for i = 1:length(targetSheets)
            sheet = targetSheets{i};
            if ismember(sheet, sheetNames)
                T = readtable(filePath, 'Sheet', sheet);
                if ismember('name', lower(T.Properties.VariableNames))
                    stepCount = stepCount + height(T);
                end
            end
        end
    catch ME
        log(['警告: 预计算Excel步骤时出错: ' ME.message]);
    end
end

function finalName = calculateFinalName(originalName, type, directionalRenameMap)
    nameAfterF1 = originalName;
    if app.EnableF1CheckBox.Value, nameAfterF1 = applyF1Rule(originalName); end
    
    nameWasChangedByF1 = ~strcmp(originalName, nameAfterF1);
    finalName = nameAfterF1;

    if app.EnableF2CheckBox.Value && nameWasChangedByF1
        nameToNormalize = nameAfterF1;
        if isKey(app.LearnedMap, nameAfterF1)
            nameToNormalize = app.LearnedMap(nameAfterF1);
        elseif app.EnableFamilySepCheckBox.Value && isKey(directionalRenameMap, nameAfterF1)
            nameToNormalize = directionalRenameMap(nameAfterF1);
        end
        
        finalName = applyF2Rule(nameToNormalize, type);
    end
    
    finalName = sanitizeName(finalName);
end

function renameMap = buildDirectionalRenameMap(blockHandles, lineHandles, sfObjects)
    log('预分析: 正在查找方向信号家族...', false);
    renameMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    
    if ~app.EnableF2CheckBox.Value || ~app.EnableFamilySepCheckBox.Value
        log('家族分离功能未启用，跳过分析。', false);
        return;
    end
    
    familyDefs = { {'frle', 'frri', 'rele', 'reri'}, {'fl', 'fr', 'rl', 'rr'}, {'fa', 'ra'} };
    
    allNamesAfterF1 = {};
    
    function processPotentialName(name)
        if ~ischar(name) || isempty(name), return; end
        
        nameAfterF1 = applyF1Rule(name);
        if ~strcmp(name, nameAfterF1)
            allNamesAfterF1{end+1} = nameAfterF1;
        end
    end
    
    for i = 1:length(blockHandles)
        handle = blockHandles(i);
        if strcmpi(get_param(handle, 'LinkStatus'), 'none')
            processPotentialName(get_param(handle, 'Name'));
            
            blockType = get_param(handle, 'BlockType');
            paramsToScan = {};
            if contains(blockType, 'Lookup'), paramsToScan = {'Table', 'BreakpointsForDimension1', 'BreakpointsForDimension2', 'BreakpointsForDimension3'};
            elseif strcmp(blockType, 'Constant'), paramsToScan = {'Value'};
            elseif any(strcmp(blockType, {'Goto', 'From'})), paramsToScan = {'GotoTag'}; end
            
            for p_idx = 1:length(paramsToScan)
                try, processPotentialName(get_param(handle, paramsToScan{p_idx})); catch, end
            end
        end
    end
    
    for i = 1:length(lineHandles), processPotentialName(get_param(lineHandles(i), 'Name')); end
    for i = 1:length(sfObjects), if isprop(sfObjects{i}, 'Name'), processPotentialName(sfObjects{i}.Name); end, end
    
    allNamesAfterF1 = unique(allNamesAfterF1);
    
    familyGroups = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    for i = 1:length(allNamesAfterF1)
        name = allNamesAfterF1{i};
        nameLower = lower(name);

        bestOverallMatch = struct('familyIdx', -1, 'matchIdx', -1, 'dir', '');

        for f_idx = 1:length(familyDefs)
            directions = familyDefs{f_idx};
            for d_idx = 1:length(directions)
                dir = directions{d_idx};
                match_indices = strfind(nameLower, dir);
                
                for k = 1:length(match_indices)
                    match_idx = match_indices(k);
                    end_idx = match_idx + length(dir) - 1;
                    
                    is_valid_boundary = false;
                    if end_idx == length(nameLower), is_valid_boundary = true;
                    elseif ~isletter(nameLower(end_idx + 1)), is_valid_boundary = true; end
                    
                    if is_valid_boundary
                        if bestOverallMatch.familyIdx == -1
                            bestOverallMatch.familyIdx = f_idx; bestOverallMatch.matchIdx = match_idx; bestOverallMatch.dir = dir;
                        else
                            if f_idx < bestOverallMatch.familyIdx
                                bestOverallMatch.familyIdx = f_idx; bestOverallMatch.matchIdx = match_idx; bestOverallMatch.dir = dir;
                            elseif f_idx == bestOverallMatch.familyIdx
                                if length(dir) > length(bestOverallMatch.dir)
                                    bestOverallMatch.matchIdx = match_idx; bestOverallMatch.dir = dir;
                                elseif length(dir) == length(bestOverallMatch.dir)
                                    if match_idx > bestOverallMatch.matchIdx, bestOverallMatch.matchIdx = match_idx; bestOverallMatch.dir = dir; end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if bestOverallMatch.familyIdx > -1
            dir = bestOverallMatch.dir; match_idx = bestOverallMatch.matchIdx; f_idx = bestOverallMatch.familyIdx;
            prefix = nameLower(1:match_idx-1); suffix = nameLower(match_idx+length(dir):end);
            familyKey = sprintf('%d#%s#%s', f_idx, prefix, suffix);
            
            if ~isKey(familyGroups, familyKey), familyGroups(familyKey) = containers.Map(); end
            group = familyGroups(familyKey); group(dir) = name;
        end
    end
    
    familyKeys = keys(familyGroups);
    for i = 1:length(familyKeys)
        key = familyKeys{i}; group = familyGroups(key);
        keyParts = strsplit(key, '#'); familyId = str2double(keyParts{1});
        directions = familyDefs{familyId};
        if group.Count == length(directions)
            prefix = keyParts{2}; suffix = keyParts{3};
            for d_idx = 1:length(directions)
                dir = directions{d_idx}; originalFullName = group(dir);
                originalPrefix = originalFullName(1:length(prefix)); originalSuffix = originalFullName(end-length(suffix)+1:end);
                newFullName = [originalPrefix, '_', dir, '_', originalSuffix];
                newFullName = strrep(newFullName, '__', '_');
                if startsWith(newFullName, '_'), newFullName = newFullName(2:end); end
                if endsWith(newFullName, '_'), newFullName = newFullName(1:end-1); end
                renameMap(originalFullName) = newFullName;
                
                if ~isKey(app.LearnedMap, originalFullName)
                    app.LearnedMap(originalFullName) = newFullName;
                    updateLearnedArea();
                end
            end
        end
    end
end

% --- 修改后的 applyF1Rule，支持批量模式 ---
function newName = applyF1Rule(oldName)
    if ~app.EnableF1CheckBox.Value
        newName = oldName;
        return;
    end
    
    if app.BatchMode && ~isempty(app.BatchRenameRules)
        % 批量模式：依次应用所有规则
        newName = oldName;
        for r = 1:length(app.BatchRenameRules)
            rule = app.BatchRenameRules{r};
            if isempty(rule.old)
                continue;
            end
            if app.PrefixModeButton.Value
                % 前缀模式
                if strncmpi(newName, rule.old, length(rule.old))
                    newName = [rule.new, newName(length(rule.old)+1:end)];
                end
            else
                % 关键词模式 (正则替换，忽略大小写)
                % 对 rule.old 中的特殊字符进行转义，避免正则误解
                escapedOld = regexptranslate('escape', rule.old);
                newName = regexprep(newName, escapedOld, rule.new, 'ignorecase');
            end
        end
    else
        % 单条模式（原逻辑）
        oldStr = app.OldStringField.Value;
        newStr = app.NewStringField.Value;
        if isempty(oldStr)
            newName = oldName;
            return;
        end
        if app.PrefixModeButton.Value
            if strncmpi(oldName, oldStr, length(oldStr))
                newName = [newStr, oldName(length(oldStr)+1:end)];
            else
                newName = oldName;
            end
        else
            newName = regexprep(oldName, oldStr, newStr, 'ignorecase');
        end
    end
end

function safeSetParam(handle, paramName, desiredName)
    objectType = get_param(handle, 'Type');
    finalName = desiredName;
    suffix = 1;
    addSuffixLog = false;
    if strcmp(objectType, 'block')
        parentPath = get_param(handle, 'Parent');
        while true
            existingObj = find_system(parentPath, 'SearchDepth', 1, 'Name', finalName);
            isSelf = false;
            if ~isempty(existingObj)
                if iscell(existingObj) && numel(existingObj) == 1, isSelf = (get_param(existingObj{1}, 'Handle') == handle);
                elseif numel(existingObj) == 1, isSelf = (existingObj == handle); end
            end
            if isempty(existingObj) || isSelf, break;
            else, finalName = sprintf('%s_%d', desiredName, suffix); suffix = suffix + 1; addSuffixLog = true; end
        end
    end
    originalName = get_param(handle, paramName);
    if ~strcmp(originalName, finalName)
        set_param(handle, paramName, finalName);
        logText = sprintf('%s (%s): "%s" -> "%s"', paramName, objectType, originalName, finalName);
        if addSuffixLog, logText = [logText, ' (因冲突自动添加后缀)']; end
        logDetail(logText);
    end
end

function safeSetSfName(sfObj, desiredName), parentObj = sfObj.getParent; finalName = desiredName; suffix = 1; while true, existingObj = parentObj.find('-isa', class(sfObj), 'Name', finalName); if isempty(existingObj) || (numel(existingObj) == 1 && existingObj.Id == sfObj.Id), break; else, finalName = sprintf('%s_%d', desiredName, suffix); suffix = suffix + 1; end, end, originalName = sfObj.Name; if ~strcmp(originalName, finalName), sf('set', sfObj.Id, '.name', finalName); logDetail(sprintf('SF Name: "%s" -> "%s" (%s)', originalName, finalName, class(sfObj))); end, end
function newName = applyF2Rule(oldName, type)
    if ~ischar(oldName), newName = oldName; return; end
    newName = oldName; 
    if strcmp(type, 'auto')
        if ~strcmp(oldName, upper(oldName)) || isempty(regexp(oldName, '^[A-Z_0-9]+$', 'once')), type = 'signal'; else, type = 'parameter'; end
    end
    parts = strsplit(oldName, '_');
    if isempty(parts) || isempty(parts{1}); return; end
    if strcmp(type, 'signal')
        if numel(parts) >= 1; parts{1} = upper(parts{1}); end
        if numel(parts) >= 2 && ~isempty(parts{2}); parts{2} = [upper(parts{2}(1)), lower(parts{2}(2:end))]; end
        if numel(parts) >= 3; for i = 3:numel(parts); parts{i} = lower(parts{i}); end; end
        newName = strjoin(parts, '_');
    elseif strcmp(type, 'parameter'), newName = upper(strrep(oldName, ' ', '')); end
end

function log(message, writeToFile)
    if nargin < 2, writeToFile = true; end
    timestamp = datestr(now, 'HH:MM:SS');
    fullMessage = ['[' timestamp '] ' message];
    currentLog = app.LogArea.Value; 
    if ischar(currentLog); currentLog = {currentLog}; end
    if numel(currentLog) == 1 && isempty(currentLog{1}); currentLog = {}; end
    app.LogArea.Value = [currentLog; {fullMessage}]; 
    drawnow;
    if writeToFile, app.DetailedLog{end+1} = fullMessage; end
end

function logDetail(message)
    log(message, true);
end

function writeLogToTxt(path, modelName)
    log('正在生成TXT日志文件...');
    try
        logFileName = fullfile(path, ['改动日志_' modelName '_' datestr(now, 'yyyymmdd_HHMMSS') '.txt']);
        logContent = app.DetailedLog;
        fileID = fopen(logFileName, 'w', 'n', 'UTF-8');
        if fileID == -1, error('无法创建日志文件。请检查文件夹权限。'); end
        cleanupObj = onCleanup(@() fclose(fileID));
        fprintf(fileID, '--- Simulink批量修改工具 V20.2.20 改动日志 ---\n');
        fprintf(fileID, '--- 执行时间: %s ---\n\n', datestr(now));
        for i = 1:numel(logContent), fprintf(fileID, '%s\n', logContent{i}); end
        log(['TXT日志文件已生成: ', logFileName]);
    catch ME, log(['警告: 生成TXT日志文件失败: ', ME.message]); end
end

function updateProgress(), app.CurrentStep = app.CurrentStep + 1; if app.TotalSteps > 0, progress = round(app.CurrentStep / app.TotalSteps * 100); app.ProgressBar.Value = progress; app.ProgressLabel.Text = sprintf('进度: %d%%', progress); end, drawnow; end
function sanitized_name = sanitizeName(name), sanitized_name = strrep(name, '/', '_'); end
function restoreAllCallbacks(callbacks), if isempty(callbacks), return; end, log('正在恢复所有原始模型回调...'); for i = 1:size(callbacks, 1), model = callbacks{i, 1}; if bdIsLoaded(model), try, set_param(model, 'PreSaveFcn', callbacks{i, 2}); set_param(model, 'PostSaveFcn', callbacks{i, 3}); catch ME, log(sprintf('警告: 无法为 %s 恢复回调: %s', model, ME.message)); end, end, end, log('回调恢复完毕。'); end

function ClearLearnedMapButtonPushed(~, ~)
    app.LearnedMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    updateLearnedArea();
    log('预处理记忆库已清空。');
end

function updateLearnedArea()
    mapKeys = keys(app.LearnedMap);
    
    if isempty(mapKeys)
        app.LearnedArea.Value = '';
    else
        mapVals = values(app.LearnedMap);
        displayContent = cell(length(mapKeys), 1);
        for i = 1:length(mapKeys)
            displayContent{i} = sprintf('"%s" -> "%s"', mapKeys{i}, mapVals{i});
        end
        app.LearnedArea.Value = displayContent;
    end
    
    drawnow;
end

end