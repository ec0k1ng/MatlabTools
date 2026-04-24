function SignalEnumGenerator()
    % 信号和枚举生成工具（支持枚举、总线、自定义数值类型、信号/参数、变量定义文件）
    % 支持生成加载脚本，一键恢复所有工作区对象（含描述信息）
    % 优化：总线生成不再产生临时变量，工作区更干净
    % 新增：可缩放UI、多文件管理、数据类型校验、加载脚本合并、单例模式

    % 单例模式：关闭已有实例
    persistent FIG_HANDLE
    if ~isempty(FIG_HANDLE) && ishandle(FIG_HANDLE)
        delete(FIG_HANDLE);
    end

    % 创建主窗口 (uifigure 支持缩放)
    fig = uifigure('Name', '信号与枚举生成工具', 'Position', [300 150 950 800], ...
                   'NumberTitle', 'off', 'Resize', 'on');
    FIG_HANDLE = fig;

    % 创建主网格布局 (行数动态调整)
    mainGrid = uigridlayout(fig, [20, 3], ...
        'RowHeight', {30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,'1x'}, ...
        'ColumnWidth', {120, '1x', 90}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 5, 'ColumnSpacing', 5);

    % ==================== 枚举文件管理区域 ====================
    lblEnum = uilabel(mainGrid, 'Text', '枚举定义文件列表:', 'FontWeight', 'bold', ...
        'Tooltip', '支持多个Excel文件，按顺序合并，重复定义以最后为准');
    lblEnum.Layout.Row = 1; lblEnum.Layout.Column = 1;
    
    % 占位
    placeholder1 = uilabel(mainGrid, 'Text', '');
    placeholder1.Layout.Row = 1; placeholder1.Layout.Column = 2;
    placeholder2 = uilabel(mainGrid, 'Text', '');
    placeholder2.Layout.Row = 1; placeholder2.Layout.Column = 3;

    enumListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', '已选择的枚举定义文件（完整路径）');
    enumListBox.Layout.Row = [2, 6];
    enumListBox.Layout.Column = 2;

    btnAddEnumFile = uibutton(mainGrid, 'Text', '添加文件...', ...
        'ButtonPushedFcn', @(src,event) addFiles('enum'));
    btnAddEnumFile.Layout.Row = 2; btnAddEnumFile.Layout.Column = 3;
    btnAddEnumFolder = uibutton(mainGrid, 'Text', '添加文件夹...', ...
        'ButtonPushedFcn', @(src,event) addFolder('enum'));
    btnAddEnumFolder.Layout.Row = 3; btnAddEnumFolder.Layout.Column = 3;
    btnDelEnum = uibutton(mainGrid, 'Text', '删除选中', ...
        'ButtonPushedFcn', @(src,event) deleteSelected('enum'));
    btnDelEnum.Layout.Row = 4; btnDelEnum.Layout.Column = 3;
    btnClearEnum = uibutton(mainGrid, 'Text', '清空全部', ...
        'ButtonPushedFcn', @(src,event) clearAll('enum'));
    btnClearEnum.Layout.Row = 5; btnClearEnum.Layout.Column = 3;

    % 枚举文件存放路径
    lblTargetPath = uilabel(mainGrid, 'Text', '枚举文件存放路径:', 'FontWeight', 'bold');
    lblTargetPath.Layout.Row = 7; lblTargetPath.Layout.Column = 1;
    enumTargetPathEdit = uieditfield(mainGrid, 'text', 'Value', '');
    enumTargetPathEdit.Layout.Row = 7; enumTargetPathEdit.Layout.Column = 2;
    btnBrowsePath = uibutton(mainGrid, 'Text', '浏览...', ...
        'ButtonPushedFcn', @(src,event) selectEnumTargetFolder());
    btnBrowsePath.Layout.Row = 7; btnBrowsePath.Layout.Column = 3;

    % ==================== Interface 文件管理区域 ====================
    lblIntf = uilabel(mainGrid, 'Text', 'Interface文件列表:', 'FontWeight', 'bold');
    lblIntf.Layout.Row = 8; lblIntf.Layout.Column = 1;
    placeholder3 = uilabel(mainGrid, 'Text', '');
    placeholder3.Layout.Row = 8; placeholder3.Layout.Column = 2;
    placeholder4 = uilabel(mainGrid, 'Text', '');
    placeholder4.Layout.Row = 8; placeholder4.Layout.Column = 3;

    interfaceListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', '已选择的Interface文件（完整路径）');
    interfaceListBox.Layout.Row = [9, 12];
    interfaceListBox.Layout.Column = 2;

    btnAddIntf = uibutton(mainGrid, 'Text', '添加文件...', ...
        'ButtonPushedFcn', @(src,event) addFiles('interface'));
    btnAddIntf.Layout.Row = 9; btnAddIntf.Layout.Column = 3;
    btnAddIntfFolder = uibutton(mainGrid, 'Text', '添加文件夹...', ...
        'ButtonPushedFcn', @(src,event) addFolder('interface'));
    btnAddIntfFolder.Layout.Row = 10; btnAddIntfFolder.Layout.Column = 3;
    btnDelIntf = uibutton(mainGrid, 'Text', '删除选中', ...
        'ButtonPushedFcn', @(src,event) deleteSelected('interface'));
    btnDelIntf.Layout.Row = 11; btnDelIntf.Layout.Column = 3;
    btnClearIntf = uibutton(mainGrid, 'Text', '清空全部', ...
        'ButtonPushedFcn', @(src,event) clearAll('interface'));
    btnClearIntf.Layout.Row = 12; btnClearIntf.Layout.Column = 3;

    % ==================== 变量定义文件管理区域 ====================
    lblVar = uilabel(mainGrid, 'Text', '变量定义文件列表:', 'FontWeight', 'bold');
    lblVar.Layout.Row = 13; lblVar.Layout.Column = 1;
    placeholder5 = uilabel(mainGrid, 'Text', '');
    placeholder5.Layout.Row = 13; placeholder5.Layout.Column = 2;
    placeholder6 = uilabel(mainGrid, 'Text', '');
    placeholder6.Layout.Row = 13; placeholder6.Layout.Column = 3;

    varListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', '已选择的变量定义文件（完整路径）');
    varListBox.Layout.Row = [14, 17];
    varListBox.Layout.Column = 2;

    btnAddVar = uibutton(mainGrid, 'Text', '添加文件...', ...
        'ButtonPushedFcn', @(src,event) addFiles('var'));
    btnAddVar.Layout.Row = 14; btnAddVar.Layout.Column = 3;
    btnAddVarFolder = uibutton(mainGrid, 'Text', '添加文件夹...', ...
        'ButtonPushedFcn', @(src,event) addFolder('var'));
    btnAddVarFolder.Layout.Row = 15; btnAddVarFolder.Layout.Column = 3;
    btnDelVar = uibutton(mainGrid, 'Text', '删除选中', ...
        'ButtonPushedFcn', @(src,event) deleteSelected('var'));
    btnDelVar.Layout.Row = 16; btnDelVar.Layout.Column = 3;
    btnClearVar = uibutton(mainGrid, 'Text', '清空全部', ...
        'ButtonPushedFcn', @(src,event) clearAll('var'));
    btnClearVar.Layout.Row = 17; btnClearVar.Layout.Column = 3;

    % 加载脚本文件名
    lblScript = uilabel(mainGrid, 'Text', '加载脚本文件名:', 'FontWeight', 'bold');
    lblScript.Layout.Row = 18; lblScript.Layout.Column = 1;
    scriptNameEdit = uieditfield(mainGrid, 'text', 'Value', 'LoadWorkspaceData.m');
    scriptNameEdit.Layout.Row = 18; scriptNameEdit.Layout.Column = 2;
    lblScriptHint = uilabel(mainGrid, 'Text', '（.m文件，保存在当前目录）', ...
        'FontColor', [0.5 0.5 0.5]);
    lblScriptHint.Layout.Row = 18; lblScriptHint.Layout.Column = 3;

    % 生成与退出按钮面板
    btnPanel = uigridlayout(mainGrid, [1,2], 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0]);
    btnPanel.Layout.Row = 19; btnPanel.Layout.Column = [1,3];
    btnGenerate = uibutton(btnPanel, 'Text', '生成', 'BackgroundColor', [0.3 0.7 0.3], ...
        'FontColor','w','FontWeight','bold','FontSize',12, ...
        'ButtonPushedFcn', @(src,event) generate());
    btnGenerate.Layout.Row = 1; btnGenerate.Layout.Column = 1;
    btnExit = uibutton(btnPanel, 'Text', '退出', 'BackgroundColor', [0.8 0.3 0.3], ...
        'FontColor','w','FontWeight','bold','FontSize',12, ...
        'ButtonPushedFcn', @(src,event) delete(fig));
    btnExit.Layout.Row = 1; btnExit.Layout.Column = 2;

    % 状态栏
    statusLabel = uilabel(mainGrid, 'Text', '就绪', 'FontAngle', 'italic', ...
        'BackgroundColor', [0.9 0.9 0.9]);
    statusLabel.Layout.Row = 20; statusLabel.Layout.Column = [1,3];

    % 存储数据
    appData = struct();
    appData.enumFiles = {};
    appData.targetPath = '';
    appData.interfaceFiles = {};
    appData.varFiles = {};
    appData.enumListBox = enumListBox;
    appData.interfaceListBox = interfaceListBox;
    appData.varListBox = varListBox;
    set(fig, 'UserData', appData);

    % ==================== 回调函数 ====================
    function selectEnumTargetFolder()
        folder = uigetdir(pwd, '选择枚举类生成目标路径');
        % 置顶窗口
        pause(0.01);
        figure(fig);
        drawnow;
        % 关键：对列表框做操作来保持窗口活跃
        appData = get(fig, 'UserData');
        updateListBox(appData.enumListBox, appData.enumFiles);  % 强制刷新界面
        if folder ~= 0
            enumTargetPathEdit.Value = folder;
            appData = get(fig, 'UserData');
            appData.targetPath = folder;
            set(fig, 'UserData', appData);
            statusLabel.Text = sprintf('枚举文件存放路径: %s', folder);
        end
    end

    function addFiles(type)
        switch type
            case 'enum'
                [files, path] = uigetfile('*.xlsx', '选择一个或多个枚举 Excel 文件', ...
                    pwd, 'MultiSelect', 'on');
            case 'interface'
                [files, path] = uigetfile('*.xlsx', '选择一个或多个 Interface Excel 文件', ...
                    pwd, 'MultiSelect', 'on');
            case 'var'
                [files, path] = uigetfile('*.xlsx', '选择一个或多个变量定义 Excel 文件', ...
                    pwd, 'MultiSelect', 'on');
        end
        % 置顶窗口
        pause(0.01);
        figure(fig);
        drawnow;
        if isequal(files, 0), return; end
        if ischar(files), files = {files}; end
        
        % 过滤掉临时文件（以~开头的文件）
        validFiles = {};
        for i = 1:length(files)
            if ~startsWith(files{i}, '~')
                validFiles{end+1} = files{i};
            end
        end
        
        if isempty(validFiles)
            statusLabel.Text = '未选择有效的文件（临时文件已被过滤）';
            return;
        end
        
        newPaths = cellfun(@(f) fullfile(path, f), validFiles, 'UniformOutput', false);
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                allFiles = [appData.enumFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.enumFiles = allFiles;
                updateListBox(appData.enumListBox, allFiles);
                statusLabel.Text = sprintf('已添加 %d 个枚举文件，共 %d 个', length(newPaths), length(allFiles));
            case 'interface'
                allFiles = [appData.interfaceFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.interfaceFiles = allFiles;
                updateListBox(appData.interfaceListBox, allFiles);
                statusLabel.Text = sprintf('已添加 %d 个 Interface 文件，共 %d 个', length(newPaths), length(allFiles));
            case 'var'
                allFiles = [appData.varFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.varFiles = allFiles;
                updateListBox(appData.varListBox, allFiles);
                statusLabel.Text = sprintf('已添加 %d 个变量定义文件，共 %d 个', length(newPaths), length(allFiles));
        end
        set(fig, 'UserData', appData);
    end

    function addFolder(type)
        switch type
            case 'enum'
                folder = uigetdir(pwd, '选择包含枚举 Excel 文件的根文件夹');
            case 'interface'
                folder = uigetdir(pwd, '选择包含 Interface Excel 文件的根文件夹');
            case 'var'
                folder = uigetdir(pwd, '选择包含变量定义 Excel 文件的根文件夹');
        end
        % 置顶窗口
        pause(0.01);
        figure(fig);
        drawnow;
        if folder == 0, return; end
        statusLabel.Text = '正在扫描文件夹...';  % UI更新：保持窗口活跃
        % 关键：对列表框做操作来保持窗口活跃
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                updateListBox(appData.enumListBox, appData.enumFiles);  % 强制刷新界面
            case 'interface'
                updateListBox(appData.interfaceListBox, appData.interfaceFiles);
            case 'var'
                updateListBox(appData.varListBox, appData.varFiles);
        end
        excelFiles = findAllExcelFiles(folder);
        switch type
            case 'enum'
                allFiles = [appData.enumFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.enumFiles = allFiles;
                updateListBox(appData.enumListBox, allFiles);
                statusLabel.Text = sprintf('从文件夹中添加了 %d 个枚举文件，共 %d 个', length(excelFiles), length(allFiles));
            case 'interface'
                allFiles = [appData.interfaceFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.interfaceFiles = allFiles;
                updateListBox(appData.interfaceListBox, allFiles);
                statusLabel.Text = sprintf('从文件夹中添加了 %d 个 Interface 文件，共 %d 个', length(excelFiles), length(allFiles));
            case 'var'
                allFiles = [appData.varFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.varFiles = allFiles;
                updateListBox(appData.varListBox, allFiles);
                statusLabel.Text = sprintf('从文件夹中添加了 %d 个变量定义文件，共 %d 个', length(excelFiles), length(allFiles));
        end
        set(fig, 'UserData', appData);
    end

    function deleteSelected(type)
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                if isempty(appData.enumFiles), return; end
                selected = appData.enumListBox.Value;
                if isempty(selected), return; end
                [~, idx] = intersect(appData.enumFiles, selected);
                appData.enumFiles(idx) = [];
                updateListBox(appData.enumListBox, appData.enumFiles);
                statusLabel.Text = sprintf('已删除 %d 个枚举文件，剩余 %d 个', length(idx), length(appData.enumFiles));
            case 'interface'
                if isempty(appData.interfaceFiles), return; end
                selected = appData.interfaceListBox.Value;
                if isempty(selected), return; end
                [~, idx] = intersect(appData.interfaceFiles, selected);
                appData.interfaceFiles(idx) = [];
                updateListBox(appData.interfaceListBox, appData.interfaceFiles);
                statusLabel.Text = sprintf('已删除 %d 个 Interface 文件，剩余 %d 个', length(idx), length(appData.interfaceFiles));
            case 'var'
                if isempty(appData.varFiles), return; end
                selected = appData.varListBox.Value;
                if isempty(selected), return; end
                [~, idx] = intersect(appData.varFiles, selected);
                appData.varFiles(idx) = [];
                updateListBox(appData.varListBox, appData.varFiles);
                statusLabel.Text = sprintf('已删除 %d 个变量定义文件，剩余 %d 个', length(idx), length(appData.varFiles));
        end
        set(fig, 'UserData', appData);
    end


    function clearAll(type)
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                appData.enumFiles = {};
                updateListBox(appData.enumListBox, {});
                statusLabel.Text = '已清空枚举文件列表';
            case 'interface'
                appData.interfaceFiles = {};
                updateListBox(appData.interfaceListBox, {});
                statusLabel.Text = '已清空 Interface 文件列表';
            case 'var'
                appData.varFiles = {};
                updateListBox(appData.varListBox, {});
                statusLabel.Text = '已清空变量定义文件列表';
        end
        set(fig, 'UserData', appData);
    end

    function updateListBox(listbox, filePaths)
        if isempty(filePaths)
            listbox.Items = {};
            listbox.Value = {};
            return;
        end
        listbox.Items = filePaths;
        listbox.Value = {};
    end

    function excelFiles = findAllExcelFiles(rootFolder)
        excelFiles = {};
        items = dir(rootFolder);
        for i = 1:length(items)
            if items(i).isdir && ~ismember(items(i).name, {'.', '..'})
                subFiles = findAllExcelFiles(fullfile(rootFolder, items(i).name));
                excelFiles = [excelFiles, subFiles];
            elseif ~items(i).isdir && endsWith(items(i).name, '.xlsx', 'IgnoreCase', true) && ~startsWith(items(i).name, '~')
                excelFiles{end+1} = fullfile(rootFolder, items(i).name);
            end
        end
    end

    % ==================== 生成主函数 ====================
    function generate()
        appData = get(fig, 'UserData');
        if ~isempty(appData.enumFiles) && isempty(appData.targetPath)
            uialert(fig, '选择了枚举文件，请选择枚举文件存放路径！', '错误');
            return;
        end

        % 错误日志收集
        errorLog = {};
        warningLog = {};

        % 记录已生成的对象（用于加载脚本合并）
        generatedVarNames = {};

        % 使用 Map 记录每个变量名对应的脚本行（去重）
        scriptMap = containers.Map();
        scriptOrder = {};  % 保持变量第一次出现的顺序
        function recordScriptLine(varName, lines)
            if ischar(lines)
                lines = {lines};
            end
            if ~scriptMap.isKey(varName)
                scriptOrder{end+1} = varName;
            end
            scriptMap(varName) = lines;
        end

        % 添加头部固定行
        headerLines = {
            '%% Simulink 工作区数据加载脚本';
            '% 此脚本由 SignalEnumGenerator 自动生成';
            '% 运行此脚本可恢复所有工作区对象（枚举, AliasType, Bus, Parameter, Signal）及其描述信息';
            '';
            };
        if ~isempty(appData.targetPath)
            headerLines = [headerLines; ...
                {sprintf('%% 添加枚举类路径'); ...
                 sprintf('addpath(''%s'');', appData.targetPath); ...
                 'savepath;'; ...
                 ''}];
        end
        for i = 1:length(headerLines)
            recordScriptLine(['__header__' num2str(i)], headerLines{i});
        end

        statusLabel.Text = '正在生成...';
        statusLabel.FontColor = [0.5 0 0];
        drawnow;

        try
            % 1. 处理所有枚举文件
            for i = 1:length(appData.enumFiles)
                enumFile = appData.enumFiles{i};
                fprintf('\n--- 处理枚举文件 (%d/%d): %s ---\n', i, length(appData.enumFiles), enumFile);
                try
                    [newVars, errors, warnings] = processEnumFile(enumFile, appData.targetPath);
                    generatedVarNames = [generatedVarNames, newVars];
                    errorLog = [errorLog; errors];
                    warningLog = [warningLog; warnings];
                catch ME
                    errorLog{end+1} = sprintf('枚举文件处理失败: %s - %s', enumFile, ME.message);
                end
            end

            % 2. 处理所有Interface文件
            for i = 1:length(appData.interfaceFiles)
                intfFile = appData.interfaceFiles{i};
                fprintf('\n--- 处理 Interface 文件 (%d/%d): %s ---\n', i, length(appData.interfaceFiles), intfFile);
                try
                    [newVars, errors, warnings] = processInterfaceFile(intfFile);
                    generatedVarNames = [generatedVarNames, newVars];
                    errorLog = [errorLog; errors];
                    warningLog = [warningLog; warnings];
                catch ME
                    errorLog{end+1} = sprintf('Interface文件处理失败: %s - %s', intfFile, ME.message);
                end
            end

            % 3. 处理所有变量定义文件
            for i = 1:length(appData.varFiles)
                varFile = appData.varFiles{i};
                fprintf('\n--- 处理变量定义文件 (%d/%d): %s ---\n', i, length(appData.varFiles), varFile);
                try
                    [newVars, errors, warnings] = processVariableDefinitionFile(varFile);
                    generatedVarNames = [generatedVarNames, newVars];
                    errorLog = [errorLog; errors];
                    warningLog = [warningLog; warnings];
                catch ME
                    errorLog{end+1} = sprintf('变量定义文件处理失败: %s - %s', varFile, ME.message);
                end
            end

            % 4. 生成加载脚本（合并模式，无备份）
            scriptFileName = strtrim(scriptNameEdit.Value);
            if isempty(scriptFileName)
                scriptFileName = 'LoadWorkspaceData.m';
            end
            if ~endsWith(scriptFileName, '.m')
                scriptFileName = [scriptFileName, '.m'];
            end
            scriptPath = fullfile(pwd, scriptFileName);
            mergeLoadScript(scriptPath, scriptMap, scriptOrder, generatedVarNames);

            % 5. 统一输出错误和警告
            if ~isempty(warningLog)
                fprintf('\n⚠️ 警告信息汇总:\n');
                for i = 1:length(warningLog)
                    fprintf('   %s\n', warningLog{i});
                end
            end
            if ~isempty(errorLog)
                fprintf('\n❌ 错误信息汇总:\n');
                for i = 1:length(errorLog)
                    fprintf('   %s\n', errorLog{i});
                end
                statusLabel.Text = '生成完成，但存在错误';
                statusLabel.FontColor = [0.8 0.5 0];
                uialert(fig, sprintf('生成过程中发生 %d 个错误，请查看命令窗口', length(errorLog)), '警告');
            else
                fprintf('\n✅ 生成完成！所有处理成功。\n');
                statusLabel.Text = '✅ 生成完成！';
                statusLabel.FontColor = [0 0.5 0];
                uialert(fig, sprintf('生成成功！\n加载脚本已保存至:\n%s', scriptPath), '完成', 'icon','success');
            end
        catch ME
            statusLabel.Text = '❌ 生成失败';
            statusLabel.FontColor = [0.8 0 0];
            uialert(fig, sprintf('生成失败:\n%s', ME.message), '错误');
            rethrow(ME);
        end

        % ==================== 嵌套辅助函数 ====================
        function [varNames, errors, warnings] = processEnumFile(excelFile, targetPath)
            varNames = {};
            errors = {};
            warnings = {};
            % 生成枚举类
            try
                [enumGroups, enumErrors] = parseEnumSheet(excelFile);
                errors = [errors; enumErrors];
                if ~isempty(enumGroups)
                    if ~exist(targetPath, 'dir'), mkdir(targetPath); end
                    for i = 1:length(enumGroups)
                        enumInfo = enumGroups{i};
                        className = matlab.lang.makeValidName(enumInfo.Name);
                        filePath = fullfile(targetPath, [className, '.m']);
                        % 枚举文件直接覆盖
                        fid = fopen(filePath, 'w', 'n', 'UTF-8');
                        if fid == -1
                            errors{end+1} = sprintf('无法创建枚举文件: %s', className);
                            continue;
                        end
                        fprintf(fid, '%% %s 枚举类定义\n', className);
                        if ~isempty(enumInfo.Description)
                            fprintf(fid, '%% 描述: %s\n', enumInfo.Description);
                        end
                        fprintf(fid, 'classdef %s < Simulink.IntEnumType\r\n', className);
                        fprintf(fid, '    enumeration\r\n');
                        for j = 1:length(enumInfo.Members)
                            memberName = enumInfo.Members{j}{1};
                            memberValue = enumInfo.Members{j}{2};
                            fprintf(fid, '        %s(%s)\r\n', memberName, memberValue);
                        end
                        fprintf(fid, '    end\r\n');
                        fprintf(fid, 'end\r\n');
                        fclose(fid);
                        fprintf('   ✅ 生成枚举: %s.m\n', className);
                    end
                end
            catch ME
                errors{end+1} = sprintf('解析枚举sheet失败: %s', ME.message);
            end

            % 处理自定义数值类型 (numeric sheet)
            try
                [aliasVars, aliasErrors, aliasWarnings] = processNumericSheet(excelFile);
                varNames = [varNames, aliasVars];
                errors = [errors; aliasErrors];
                warnings = [warnings; aliasWarnings];
            catch ME
                errors{end+1} = sprintf('处理numeric sheet失败: %s', ME.message);
            end

            % 处理总线定义 (bus sheet)
            try
                [busVars, busErrors, busWarnings] = processBusSheet(excelFile);
                varNames = [varNames, busVars];
                errors = [errors; busErrors];
                warnings = [warnings; busWarnings];
            catch ME
                errors{end+1} = sprintf('处理bus sheet失败: %s', ME.message);
            end
        end

        function [enumGroups, errors] = parseEnumSheet(excelFile)
            enumGroups = {};
            errors = {};
            try
                [~, ~, rawData] = xlsread(excelFile, 'enumeration');
                if isempty(rawData)
                    errors{end+1} = '无法读取 "enumeration" sheet';
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'ConvName'});
                if headerRowIdx == 0
                    errors{end+1} = '未找到 ConvName 列';
                    return;
                end
                convNameCol = findColumnIndex(headers, {'ConvName'});
                descCol = findColumnIndex(headers, {'Description', '描述'});
                if convNameCol == 0
                    errors{end+1} = '未找到 ConvName 列';
                    return;
                end
                % 按行解析，相同ConvName合并（后面的覆盖前面）
                enumMap = containers.Map();
                for row = headerRowIdx+1:size(rawData, 1)
                    if convNameCol > size(rawData, 2), continue; end
                    convName = rawData{row, convNameCol};
                    if isempty(convName) || ~ischar(convName), continue; end
                    convName = strtrim(convName);
                    enumMembers = {};
                    for col = 1:size(rawData, 2)
                        cellValue = rawData{row, col};
                        if ~isempty(cellValue) && ischar(cellValue)
                            tokens = regexp(cellValue, '(\w+)\((\d+)\)', 'tokens');
                            if ~isempty(tokens) && ~isempty(tokens{1})
                                enumMembers{end+1} = tokens{1};
                            end
                        end
                    end
                    if ~isempty(enumMembers)
                        enumDesc = '';
                        if descCol > 0 && descCol <= size(rawData, 2)
                            desc = rawData{row, descCol};
                            if ischar(desc)
                                enumDesc = strtrim(desc);
                            end
                        end
                        enumMap(convName) = struct('Name', convName, 'Members', {enumMembers}, 'Description', enumDesc);
                    end
                end
                enumGroups = values(enumMap);
            catch ME
                errors{end+1} = sprintf('解析枚举sheet异常: %s', ME.message);
            end
        end

        function [varNames, errors, warnings] = processNumericSheet(excelFile)
            varNames = {};
            errors = {};
            warnings = {};
            try
                [~, ~, rawData] = xlsread(excelFile, 'numeric');
                if isempty(rawData) || size(rawData, 1) < 2
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'ConvName', 'DataType'});
                if headerRowIdx == 0
                    warnings{end+1} = sprintf('%s: numeric sheet 未找到 ConvName/DataType 列，跳过', excelFile);
                    return;
                end
                convNameCol = findColumnIndex(headers, {'ConvName'});
                dataTypeCol = findColumnIndex(headers, {'DataType'});
                descCol = findColumnIndex(headers, {'Description', '描述'});
                if convNameCol == 0 || dataTypeCol == 0
                    warnings{end+1} = sprintf('%s: numeric sheet 缺少必需列，跳过', excelFile);
                    return;
                end
                dataRows = rawData(headerRowIdx+1:end, :);
                for row = 1:size(dataRows, 1)
                    if convNameCol > size(dataRows, 2), continue; end
                    typeName = dataRows{row, convNameCol};
                    if isempty(typeName) || ~ischar(typeName), continue; end
                    typeName = strtrim(typeName);
                    typeName = matlab.lang.makeValidName(typeName);
                    if dataTypeCol > size(dataRows, 2), continue; end
                    baseType = dataRows{row, dataTypeCol};
                    if isempty(baseType) || ~ischar(baseType)
                        baseType = 'double';
                    else
                        baseType = strtrim(baseType);
                    end
                    if strcmpi(baseType, 'boolean') || strcmpi(baseType, 'bool')
                        baseType = 'boolean';
                    end
                    description = '';
                    if descCol > 0 && descCol <= size(dataRows, 2)
                        desc = dataRows{row, descCol};
                        if ischar(desc)
                            description = strtrim(desc);
                        end
                    end
                    try
                        aliasObj = Simulink.AliasType;
                        aliasObj.BaseType = baseType;
                        if ~isempty(description)
                            aliasObj.Description = description;
                        else
                            aliasObj.Description = sprintf('Custom numeric type created from Excel: %s -> %s', typeName, baseType);
                        end
                        assignin('base', typeName, aliasObj);
                        varNames{end+1} = typeName;
                        % 记录脚本行
                        lines = {
                            sprintf('%% 自定义类型: %s', typeName);
                            sprintf('%s = Simulink.AliasType;', typeName);
                            sprintf('%s.BaseType = ''%s'';', typeName, baseType);
                            sprintf('%s.Description = ''%s'';', typeName, strrep(aliasObj.Description, '''', ''''''));
                            sprintf('assignin(''base'', ''%s'', %s);', typeName, typeName);
                            ''};
                        recordScriptLine(typeName, lines);
                        fprintf('   ✅ 创建自定义类型: %s (本质类型: %s)\n', typeName, baseType);
                    catch ME
                        errors{end+1} = sprintf('创建AliasType失败 %s: %s', typeName, ME.message);
                    end
                end
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:xlsread:SheetNotFound')
                    errors{end+1} = sprintf('处理numeric sheet失败: %s', ME.message);
                end
            end
        end

        function [varNames, errors, warnings] = processBusSheet(excelFile)
            varNames = {};
            errors = {};
            warnings = {};
            try
                [~, ~, rawData] = xlsread(excelFile, 'bus');
                if isempty(rawData) || size(rawData, 1) < 2
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'BusName', 'ElementName', 'Typedef'});
                if headerRowIdx == 0
                    warnings{end+1} = sprintf('%s: bus sheet 未找到 BusName/ElementName/Typedef 列，跳过', excelFile);
                    return;
                end
                busNameCol = findColumnIndex(headers, {'BusName'});
                elemIdxCol = findColumnIndex(headers, {'ElementIndex'});
                elemNameCol = findColumnIndex(headers, {'ElementName'});
                typeDefCol = findColumnIndex(headers, {'Typedef'});
                busDescCol = findColumnIndex(headers, {'BusDescription', '总线描述'});
                elemDescCol = findColumnIndex(headers, {'ElementDescription', '元素描述', 'Description', '描述'});
                initValCol = findColumnIndex(headers, {'InitialValue', '初始值'});
                if busNameCol == 0 || elemNameCol == 0 || typeDefCol == 0
                    warnings{end+1} = sprintf('%s: bus sheet 缺少必需列，跳过', excelFile);
                    return;
                end
                dataRows = rawData(headerRowIdx+1:end, :);
                busMap = containers.Map();
                for row = 1:size(dataRows, 1)
                    if busNameCol > size(dataRows, 2), continue; end
                    busName = dataRows{row, busNameCol};
                    if isempty(busName) || ~ischar(busName), continue; end
                    busName = strtrim(busName);
                    if elemNameCol > size(dataRows, 2), continue; end
                    elemName = dataRows{row, elemNameCol};
                    if isempty(elemName) || ~ischar(elemName), continue; end
                    elemName = strtrim(elemName);
                    if typeDefCol > size(dataRows, 2), continue; end
                    dataType = dataRows{row, typeDefCol};
                    if isempty(dataType) || ~ischar(dataType)
                        dataType = 'double';
                    else
                        dataType = strtrim(dataType);
                    end
                    idx = length(busMap) + 1;
                    if elemIdxCol > 0 && elemIdxCol <= size(dataRows, 2)
                        rawIdx = dataRows{row, elemIdxCol};
                        if isnumeric(rawIdx) && ~isnan(rawIdx)
                            idx = round(rawIdx);
                        elseif ischar(rawIdx) && ~isempty(str2num(rawIdx))
                            idx = round(str2double(rawIdx));
                        end
                    end
                    elemDesc = '';
                    if elemDescCol > 0 && elemDescCol <= size(dataRows, 2)
                        ed = dataRows{row, elemDescCol};
                        if ischar(ed)
                            elemDesc = strtrim(ed);
                        end
                    end
                    initVal = '';
                    if initValCol > 0 && initValCol <= size(dataRows, 2)
                        iv = dataRows{row, initValCol};
                        if ~isempty(iv)
                            if isnumeric(iv)
                                if isscalar(iv)
                                    initVal = num2str(iv);
                                else
                                    initVal = mat2str(iv);
                                end
                            elseif ischar(iv)
                                initVal = strtrim(iv);
                                if isempty(str2num(initVal)) && ~strcmp(initVal(1), '[')
                                    initVal = ['''' initVal ''''];
                                end
                            end
                        end
                    end
                    if ~busMap.isKey(busName)
                        busDesc = '';
                        if busDescCol > 0 && busDescCol <= size(dataRows, 2)
                            bd = dataRows{row, busDescCol};
                            if ischar(bd)
                                busDesc = strtrim(bd);
                            end
                        end
                        busMap(busName) = struct('elements', struct('idx', {}, 'name', {}, 'type', {}, 'desc', {}, 'initVal', {}), 'description', busDesc);
                    end
                    curStruct = busMap(busName);
                    newElem = struct('idx', idx, 'name', elemName, 'type', dataType, 'desc', elemDesc, 'initVal', initVal);
                    if isempty(curStruct.elements)
                        curStruct.elements = newElem;
                    else
                        curStruct.elements(end+1) = newElem;
                    end
                    busMap(busName) = curStruct;
                end
                busNames = busMap.keys;
                for i = 1:length(busNames)
                    busName = busNames{i};
                    busInfo = busMap(busName);
                    elements = busInfo.elements;
                    if all(isfield(elements, 'idx'))
                        [~, sortOrder] = sort([elements.idx]);
                        elements = elements(sortOrder);
                    end
                    busObj = Simulink.Bus;
                    busObj.HeaderFile = '';
                    if ~isempty(busInfo.description)
                        busObj.Description = busInfo.description;
                    else
                        busObj.Description = sprintf('Bus created from Excel: %s', busName);
                    end
                    busObj.DataScope = 'Auto';
                    busObj.Alignment = -1;
                    elemArray = cell(1, length(elements));
                    for j = 1:length(elements)
                        elem = elements(j);
                        be = Simulink.BusElement;
                        be.Name = matlab.lang.makeValidName(elem.name);
                        be.DataType = elem.type;
                        be.Complexity = 'real';
                        be.Dimensions = 1;
                        be.SamplingMode = 'Sample based';
                        be.Min = [];
                        be.Max = [];
                        be.Unit = '';
                        if ~isempty(elem.desc)
                            be.Description = elem.desc;
                        else
                            be.Description = '';
                        end
                        elemArray{j} = be;
                    end
                    busObj.Elements = [elemArray{:}];
                    assignin('base', busName, busObj);
                    varNames{end+1} = busName;
                    % 总线脚本行
                    busLines = {};
                    busLines{end+1} = sprintf('%% 总线: %s', busName);
                    busLines{end+1} = sprintf('%s = Simulink.Bus;', busName);
                    busLines{end+1} = sprintf('%s.Description = ''%s'';', busName, strrep(busObj.Description, '''', ''''''));
                    busLines{end+1} = sprintf('%s.DataScope = ''%s'';', busName, busObj.DataScope);
                    busLines{end+1} = sprintf('%s.Alignment = %d;', busName, busObj.Alignment);
                    busLines{end+1} = sprintf('elemArray = cell(1, %d);', length(elements));
                    for j = 1:length(elements)
                        elem = elements(j);
                        busLines{end+1} = 'be = Simulink.BusElement;';
                        busLines{end+1} = sprintf('be.Name = ''%s'';', matlab.lang.makeValidName(elem.name));
                        busLines{end+1} = sprintf('be.DataType = ''%s'';', elem.type);
                        busLines{end+1} = 'be.Complexity = ''real'';';
                        busLines{end+1} = 'be.Dimensions = 1;';
                        busLines{end+1} = 'be.SamplingMode = ''Sample based'';';
                        if ~isempty(elem.desc)
                            busLines{end+1} = sprintf('be.Description = ''%s'';', strrep(elem.desc, '''', ''''''));
                        end
                        busLines{end+1} = sprintf('elemArray{%d} = be;', j);
                    end
                    busLines{end+1} = sprintf('%s.Elements = [elemArray{:}];', busName);
                    busLines{end+1} = 'clear be elemArray;';
                    busLines{end+1} = sprintf('assignin(''base'', ''%s'', %s);', busName, busName);
                    busLines{end+1} = '';
                    recordScriptLine(busName, busLines);
                    
                    % 为每个成员生成 Simulink.Signal
                    for j = 1:length(elements)
                        elem = elements(j);
                        signalName = matlab.lang.makeValidName(elem.name);
                        sig = Simulink.Signal;
                        sig.DataType = elem.type;
                        if ~isempty(elem.initVal)
                            sig.InitialValue = elem.initVal;
                        end
                        if ~isempty(elem.desc)
                            sig.Description = sprintf('Bus member of %s: %s', busName, elem.desc);
                        else
                            sig.Description = sprintf('Signal for bus %s element %s', busName, elem.name);
                        end
                        assignin('base', signalName, sig);
                        varNames{end+1} = signalName;
                        signalLines = {};
                        signalLines{end+1} = sprintf('%% 总线成员信号: %s (来自总线 %s)', signalName, busName);
                        signalLines{end+1} = sprintf('%s = Simulink.Signal;', signalName);
                        signalLines{end+1} = sprintf('%s.DataType = ''%s'';', signalName, elem.type);
                        if ~isempty(elem.initVal)
                            initValStr = elem.initVal;
                            if ~(length(initValStr) >= 2 && initValStr(1) == '''' && initValStr(end) == '''')
                                initValStr = ['''' initValStr ''''];
                            end
                            signalLines{end+1} = sprintf('%s.InitialValue = %s;', signalName, initValStr);
                        end
                        if ~isempty(elem.desc)
                            descText = sprintf('Bus member of %s: %s', busName, elem.desc);
                            signalLines{end+1} = sprintf('%s.Description = ''%s'';', signalName, strrep(descText, '''', ''''''));
                        end
                        signalLines{end+1} = sprintf('assignin(''base'', ''%s'', %s);', signalName, signalName);
                        signalLines{end+1} = '';
                        recordScriptLine(signalName, signalLines);
                        fprintf('   ✅ 创建总线成员信号: %s (所属总线: %s)\n', signalName, busName);
                    end
                    fprintf('   ✅ 创建总线对象: %s (包含 %d 个元素)\n', busName, length(elements));
                end
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:xlsread:SheetNotFound')
                    errors{end+1} = sprintf('处理bus sheet失败: %s', ME.message);
                end
            end
        end

        function [varNames, errors, warnings] = processInterfaceFile(excelFile)
            varNames = {};
            errors = {};
            warnings = {};
            sheets = {'CAL', 'NVV', 'IN', 'OUT', 'MP'};
            for i = 1:length(sheets)
                sheetName = sheets{i};
                try
                    [numData, ~, rawData] = xlsread(excelFile, sheetName);
                    if isempty(rawData) || size(rawData, 1) < 2
                        continue;
                    end
                    if strcmpi(sheetName, 'CAL') || strcmpi(sheetName, 'NVV')
                        [vars, errs, warns] = processCalNvvSheet(rawData, numData, excelFile);
                    else
                        [vars, errs, warns] = processSignalSheet(rawData, excelFile);
                    end
                    varNames = [varNames, vars];
                    errors = [errors; errs];
                    warnings = [warnings; warns];
                catch ME
                    errors{end+1} = sprintf('工作表 %s 处理失败: %s', sheetName, ME.message);
                end
            end
        end

        function [varNames, errors, warnings] = processCalNvvSheet(rawData, numData, srcFile)
            varNames = {};
            errors = {};
            warnings = {};
            if isempty(rawData) || size(rawData,1) < 2
                return;
            end
            headers = rawData(1, :);
            for i = 1:length(headers)
                if isnumeric(headers{i}) && isnan(headers{i})
                    headers{i} = '';
                end
            end
            nameCol = findColumnIndex(headers, {'Name'});
            typeCol = findColumnIndex(headers, {'typedef', 'DataType'});
            defaultCol = findColumnIndex(headers, {'defaultvalue', 'default', 'Value'});
            widthCol = findColumnIndex(headers, {'width'});
            descCol = findColumnIndex(headers, {'Description', '描述'});
            if nameCol == 0
                warnings{end+1} = sprintf('%s: 未找到Name列，跳过', srcFile);
                return;
            end
            dataRows = rawData(2:end, :);
            for row = 1:size(dataRows, 1)
                if nameCol > size(dataRows, 2), break; end
                varName = dataRows{row, nameCol};
                if isempty(varName) || ~ischar(varName), continue; end
                varName = matlab.lang.makeValidName(varName);
                dataTypeRaw = 'double';
                if typeCol > 0 && typeCol <= size(dataRows, 2)
                    dt = dataRows{row, typeCol};
                    if ~isempty(dt) && ischar(dt)
                        dataTypeRaw = strtrim(dt);
                    end
                end
                % 数据类型校验
                [valid, errMsg] = validateDataType(dataTypeRaw);
                if ~valid
                    errors{end+1} = sprintf('参数 %s 数据类型无效: %s', varName, errMsg);
                    continue;
                end
                width = 1;
                if widthCol > 0 && widthCol <= size(dataRows, 2)
                    w = dataRows{row, widthCol};
                    if isnumeric(w) && ~isnan(w) && w > 0
                        width = round(w);
                    end
                end
                defaultValue = 0;
                isArray = false;
                if defaultCol > 0 && defaultCol <= size(dataRows, 2)
                    dv = dataRows{row, defaultCol};
                    if isempty(dv) || (isnumeric(dv) && isnan(dv))
                        defaultValue = 0;
                    elseif isnumeric(dv)
                        defaultValue = dv;
                        if numel(defaultValue) > 1, isArray = true; end
                    elseif ischar(dv) && ~isempty(dv)
                        strVal = strtrim(dv);
                        if any(strVal == '[') || any(strVal == ';') || any(strVal == ',')
                            eval(['defaultValue = ' strVal ';']);
                            isArray = true;
                        else
                            numVal = str2double(strVal);
                            if ~isnan(numVal)
                                defaultValue = numVal;
                            else
                                defaultValue = strVal;
                            end
                        end
                    else
                        if defaultCol <= size(numData, 2)
                            colData = numData(:, defaultCol);
                            validData = colData(~isnan(colData));
                            if ~isempty(validData)
                                if length(validData) > 1
                                    defaultValue = validData';
                                    isArray = true;
                                else
                                    defaultValue = validData;
                                end
                            else
                                defaultValue = 0;
                            end
                        end
                    end
                end
                description = '';
                if descCol > 0 && descCol <= size(dataRows, 2)
                    d = dataRows{row, descCol};
                    if ischar(d)
                        description = strtrim(d);
                    end
                end
                % 处理枚举类型
                if startsWith(dataTypeRaw, 'Enum:', 'IgnoreCase', true)
                    enumClassName = strtrim(dataTypeRaw(6:end));
                    enumClassName = matlab.lang.makeValidName(enumClassName);
                    try
                        if ~exist(enumClassName, 'class')
                            errors{end+1} = sprintf('枚举类 %s 未找到，参数 %s 创建失败', enumClassName, varName);
                            continue;
                        end
                        param = Simulink.Parameter;
                        param.DataType = ['Enum: ', enumClassName];
                        if ~isempty(description)
                            param.Description = description;
                        end
                        enumValue = [];
                        if isnumeric(defaultValue)
                            members = enumeration(enumClassName);
                            if ~isempty(members)
                                memberValues = arrayfun(@(m) int32(m), members);
                                idx = find(memberValues == defaultValue, 1);
                                if ~isempty(idx)
                                    enumValue = members(idx);
                                else
                                    warnings{end+1} = sprintf('数值 %d 未匹配枚举 %s，使用第一个成员', defaultValue, enumClassName);
                                    enumValue = members(1);
                                end
                            else
                                errors{end+1} = sprintf('枚举类 %s 无成员', enumClassName);
                                continue;
                            end
                        elseif ischar(defaultValue)
                            memberStr = strtrim(defaultValue);
                            if contains(memberStr, '.')
                                parts = strsplit(memberStr, '.');
                                memberName = parts{end};
                            else
                                memberName = memberStr;
                            end
                            memberName = strrep(memberName, '''', '');
                            try
                                enumValue = eval([enumClassName '.' memberName]);
                            catch
                                members = enumeration(enumClassName);
                                memberNames = arrayfun(@(m) char(m), members, 'UniformOutput', false);
                                idx = find(strcmpi(memberNames, memberName), 1);
                                if ~isempty(idx)
                                    enumValue = members(idx);
                                else
                                    errors{end+1} = sprintf('枚举类 %s 中未找到成员 %s', enumClassName, memberName);
                                    continue;
                                end
                            end
                        else
                            errors{end+1} = sprintf('参数 %s 默认值类型不支持', varName);
                            continue;
                        end
                        param.Value = enumValue;
                        assignin('base', varName, param);
                        varNames{end+1} = varName;
                        lines = {
                            sprintf('%% 枚举参数: %s', varName);
                            sprintf('%s = Simulink.Parameter;', varName);
                            sprintf('%s.DataType = ''Enum: %s'';', varName, enumClassName);
                            };
                        if ~isempty(description)
                            lines{end+1} = sprintf('%s.Description = ''%s'';', varName, strrep(description, '''', ''''''));
                        end
                        lines{end+1} = sprintf('%s.Value = %s.%s;', varName, enumClassName, char(enumValue));
                        lines{end+1} = sprintf('assignin(''base'', ''%s'', %s);', varName, varName);
                        lines{end+1} = '';
                        recordScriptLine(varName, lines);
                        fprintf('   ✅ 创建枚举参数: %s\n', varName);
                    catch ME
                        errors{end+1} = sprintf('创建枚举参数失败 %s: %s', varName, ME.message);
                    end
                else
                    % 普通参数
                    try
                        param = Simulink.Parameter;
                        [baseType, isBuiltin] = resolveBaseTypeWithFlag(dataTypeRaw);
                        if isBuiltin
                            param.DataType = baseType;
                        else
                            param.DataType = dataTypeRaw;
                        end
                        if width > 1 && ~isArray && isnumeric(defaultValue) && isscalar(defaultValue)
                            defaultValue = defaultValue * ones(1, width);
                            isArray = true;
                        end
                        if ~isArray
                            valueNum = castScalar(defaultValue, baseType);
                        else
                            valueNum = castArray(defaultValue, baseType);
                        end
                        param.Value = valueNum;
                        if ~isempty(description)
                            param.Description = description;
                        end
                        assignin('base', varName, param);
                        varNames{end+1} = varName;
                        lines = {
                            sprintf('%% 参数: %s', varName);
                            sprintf('%s = Simulink.Parameter;', varName);
                            sprintf('%s.DataType = ''%s'';', varName, param.DataType);
                            };
                        if ~isempty(description)
                            lines{end+1} = sprintf('%s.Description = ''%s'';', varName, strrep(description, '''', ''''''));
                        end
                        lines{end+1} = sprintf('%s.Value = %s;', varName, mat2str(valueNum));
                        lines{end+1} = sprintf('assignin(''base'', ''%s'', %s);', varName, varName);
                        lines{end+1} = '';
                        recordScriptLine(varName, lines);
                        fprintf('   ✅ 创建参数: %s\n', varName);
                    catch ME
                        errors{end+1} = sprintf('创建参数失败 %s: %s', varName, ME.message);
                    end
                end
            end
        end

        function [varNames, errors, warnings] = processSignalSheet(rawData, srcFile)
            varNames = {};
            errors = {};
            warnings = {};
            if isempty(rawData) || size(rawData,1) < 2
                return;
            end
            headers = rawData(1, :);
            for i = 1:length(headers)
                if isnumeric(headers{i}) && isnan(headers{i})
                    headers{i} = '';
                end
            end
            nameCol = findColumnIndex(headers, {'Name'});
            typeCol = findColumnIndex(headers, {'typedef', 'DataType'});
            initCol = findColumnIndex(headers, {'defaultvalue', 'default', 'InitialValue'});
            descCol = findColumnIndex(headers, {'Description', '描述'});
            if nameCol == 0
                warnings{end+1} = sprintf('%s: 未找到Name列，跳过', srcFile);
                return;
            end
            dataRows = rawData(2:end, :);
            for row = 1:size(dataRows, 1)
                if nameCol > size(dataRows, 2), break; end
                sigName = dataRows{row, nameCol};
                if isempty(sigName) || ~ischar(sigName), continue; end
                sigName = matlab.lang.makeValidName(sigName);
                dataType = 'double';
                if typeCol > 0 && typeCol <= size(dataRows, 2)
                    dt = dataRows{row, typeCol};
                    if ~isempty(dt) && ischar(dt)
                        dataType = strtrim(dt);
                    end
                end
                % 数据类型校验
                [valid, errMsg] = validateDataType(dataType);
                if ~valid
                    errors{end+1} = sprintf('信号 %s 数据类型无效: %s', sigName, errMsg);
                    continue;
                end
                initVal = '0';
                if initCol > 0 && initCol <= size(dataRows, 2)
                    iv = dataRows{row, initCol};
                    if isempty(iv) || (isnumeric(iv) && isnan(iv))
                        initVal = '0';
                    elseif isnumeric(iv)
                        if isscalar(iv)
                            initVal = num2str(iv);
                        else
                            initVal = mat2str(iv);
                        end
                    elseif ischar(iv) && ~isempty(iv)
                        initVal = strtrim(iv);
                        if isempty(str2num(initVal)) && ~strcmp(initVal(1), '[')
                            initVal = ['''' initVal ''''];
                        end
                    end
                end
                description = '';
                if descCol > 0 && descCol <= size(dataRows, 2)
                    d = dataRows{row, descCol};
                    if ischar(d)
                        description = strtrim(d);
                    end
                end
                try
                    sig = Simulink.Signal;
                    sig.DataType = dataType;
                    sig.InitialValue = initVal;
                    if ~isempty(description)
                        sig.Description = description;
                    end
                    assignin('base', sigName, sig);
                    varNames{end+1} = sigName;
                    lines = {
                        sprintf('%% 信号: %s', sigName);
                        sprintf('%s = Simulink.Signal;', sigName);
                        sprintf('%s.DataType = ''%s'';', sigName, dataType);
                        };
                    if ~isempty(description)
                        lines{end+1} = sprintf('%s.Description = ''%s'';', sigName, strrep(description, '''', ''''''));
                    end
                    if isempty(initVal)
                        initValScript = '''0''';
                    elseif isnumeric(initVal)
                        initValScript = sprintf('''%s''', num2str(initVal));
                    elseif ischar(initVal)
                        if (length(initVal) >= 2 && initVal(1) == '''' && initVal(end) == '''')
                            initValScript = initVal;
                        else
                            initValScript = ['''' initVal ''''];
                        end
                    else
                        initValScript = '''0''';
                    end
                    lines{end+1} = sprintf('%s.InitialValue = %s;', sigName, initValScript);
                    lines{end+1} = sprintf('assignin(''base'', ''%s'', %s);', sigName, sigName);
                    lines{end+1} = '';
                    recordScriptLine(sigName, lines);
                    fprintf('   ✅ 创建 Simulink.Signal: %s\n', sigName);
                catch ME
                    errors{end+1} = sprintf('创建信号失败 %s: %s', sigName, ME.message);
                end
            end
        end

        function [varNames, errors, warnings] = processVariableDefinitionFile(excelFile)
            varNames = {};
            errors = {};
            warnings = {};
            try
                [~, sheetNames] = xlsfinfo(excelFile);
                if isempty(sheetNames)
                    warnings{end+1} = sprintf('文件 %s 无有效工作表，跳过', excelFile);
                    return;
                end
                for s = 1:length(sheetNames)
                    sheetName = sheetNames{s};
                    try
                        [numData, ~, rawData] = xlsread(excelFile, sheetName);
                        if isempty(rawData) || size(rawData, 1) < 2
                            continue;
                        end
                        [vars, errs, warns] = processCalNvvSheet(rawData, numData, excelFile);
                        varNames = [varNames, vars];
                        errors = [errors; errs];
                        warnings = [warnings; warns];
                    catch ME
                        errors{end+1} = sprintf('工作表 %s 处理失败: %s', sheetName, ME.message);
                    end
                end
            catch ME
                errors{end+1} = sprintf('处理变量定义文件失败: %s', ME.message);
            end
        end

        function [valid, errMsg] = validateDataType(dataType)
            valid = true;
            errMsg = '';
            dataType = strtrim(dataType);
            % 内置类型
            builtinTypes = {'uint8','uint16','uint32','uint64','int8','int16','int32','int64','single','double','logical','boolean'};
            if ismember(lower(dataType), builtinTypes)
                return;
            end
            % 枚举类型
            if startsWith(dataType, 'Enum:', 'IgnoreCase', true)
                enumName = strtrim(dataType(6:end));
                if exist(enumName, 'class')
                    return;
                else
                    valid = false;
                    errMsg = sprintf('枚举类 %s 不存在', enumName);
                    return;
                end
            end
            % 总线类型
            if startsWith(dataType, 'Bus:', 'IgnoreCase', true)
                busName = strtrim(dataType(5:end));
                if evalin('base', sprintf('exist(''%s'', ''var'')', busName)) && evalin('base', sprintf('isa(%s, ''Simulink.Bus'')', busName))
                    return;
                else
                    valid = false;
                    errMsg = sprintf('Bus对象 %s 不存在', busName);
                    return;
                end
            end
            % 自定义AliasType
            if evalin('base', sprintf('exist(''%s'', ''var'')', dataType)) && evalin('base', sprintf('isa(%s, ''Simulink.AliasType'')', dataType))
                return;
            else
                valid = false;
                errMsg = sprintf('数据类型 %s 不是内置类型、枚举、Bus或已定义的AliasType', dataType);
            end
        end
    end % end of generate

    function mergeLoadScript(scriptPath, scriptMap, scriptOrder, generatedVars)
        % 合并加载脚本：保留旧脚本中独有的变量定义，新生成的变量定义覆盖同名旧定义
        % 不进行备份
        
        % 生成新脚本内容（按顺序）
        newScriptLines = {};
        for i = 1:length(scriptOrder)
            varName = scriptOrder{i};
            if startsWith(varName, '__header__')
                lines = scriptMap(varName);
                if iscell(lines)
                    newScriptLines = [newScriptLines; lines(:)];
                else
                    newScriptLines{end+1} = lines;
                end
            else
                lines = scriptMap(varName);
                if iscell(lines)
                    newScriptLines = [newScriptLines; lines(:)];
                else
                    newScriptLines{end+1} = lines;
                end
            end
        end
        
        if ~exist(scriptPath, 'file')
            % 新文件，直接写入
            fid = fopen(scriptPath, 'w');
            if fid == -1, error('无法创建脚本文件'); end
            for i = 1:length(newScriptLines)
                fprintf(fid, '%s\n', newScriptLines{i});
            end
            fclose(fid);
            fprintf('✅ 已生成加载脚本: %s\n', scriptPath);
            return;
        end
        
        % 读取旧脚本内容
        oldContent = fileread(scriptPath);
        lines = strsplit(oldContent, '\n');
        
        % 新生成的变量名集合（去重）
        newVarSet = unique(generatedVars);
        
        % 逐行分析，保留旧脚本中不在新变量集合中的定义块
        keepLines = {};
        i = 1;
        while i <= length(lines)
            line = lines{i};
            tokens = regexp(line, '^\s*(\w+)\s*=', 'tokens');
            if ~isempty(tokens)
                varName = tokens{1}{1};
                if ismember(varName, newVarSet)
                    % 跳过整个定义块
                    i = i + 1;
                    while i <= length(lines)
                        nextLine = lines{i};
                        if ~isempty(regexp(nextLine, '^\s*(\w+)\s*=', 'tokens'))
                            break;
                        end
                        i = i + 1;
                    end
                    continue;
                else
                    % 保留该变量定义及其后续关联行
                    keepLines{end+1} = line;
                    i = i + 1;
                    while i <= length(lines)
                        nextLine = lines{i};
                        if ~isempty(regexp(nextLine, '^\s*(\w+)\s*=', 'tokens'))
                            break;
                        end
                        keepLines{end+1} = nextLine;
                        i = i + 1;
                    end
                end
            else
                keepLines{end+1} = line;
                i = i + 1;
            end
        end
        
        % 写入合并后的脚本
        fid = fopen(scriptPath, 'w');
        if fid == -1, error('无法写入脚本文件'); end
        for i = 1:length(keepLines)
            fprintf(fid, '%s\n', keepLines{i});
        end
        fprintf(fid, '\n%% ========== 以下为新生成的内容 ==========\n');
        for i = 1:length(newScriptLines)
            fprintf(fid, '%s\n', newScriptLines{i});
        end
        fclose(fid);
        fprintf('✅ 已合并生成加载脚本: %s\n', scriptPath);
    end
end

%% ======================== 全局辅助函数（独立） ========================
function [headerRowIdx, headers] = findHeaderRow(rawData, requiredColNames)
    if isempty(rawData)
        headerRowIdx = 0;
        headers = {};
        return;
    end
    for row = 1:size(rawData, 1)
        rowData = rawData(row, :);
        foundAll = true;
        for j = 1:length(requiredColNames)
            colFound = false;
            for col = 1:length(rowData)
                cellVal = rowData{col};
                if ischar(cellVal) && ~isempty(strtrim(cellVal))
                    if strcmpi(strtrim(cellVal), requiredColNames{j})
                        colFound = true;
                        break;
                    end
                end
            end
            if ~colFound
                foundAll = false;
                break;
            end
        end
        if foundAll
            headerRowIdx = row;
            headers = rowData;
            return;
        end
    end
    headerRowIdx = 0;
    headers = {};
end

function colIdx = findColumnIndex(headers, possibleNames)
    colIdx = 0;
    for i = 1:length(headers)
        if ~isempty(headers{i}) && ischar(headers{i})
            hdr = strtrim(headers{i});
            for j = 1:length(possibleNames)
                if strcmpi(hdr, possibleNames{j})
                    colIdx = i;
                    return;
                end
            end
        end
    end
end

function [baseType, isBuiltin] = resolveBaseTypeWithFlag(typeName)
    baseType = lower(strtrim(typeName));
    builtinTypes = {'uint8','uint16','uint32','uint64','int8','int16','int32','int64','single','double','logical','boolean'};
    if ismember(baseType, builtinTypes)
        isBuiltin = true;
        return;
    end
    if strcmp(baseType, 'boolean') || strcmp(baseType, 'bool')
        baseType = 'boolean';
        isBuiltin = true;
        return;
    end
    try
        if evalin('base', sprintf('exist(''%s'', ''var'')', baseType))
            obj = evalin('base', baseType);
            if isa(obj, 'Simulink.AliasType')
                [baseType, isBuiltin] = resolveBaseTypeWithFlag(obj.BaseType);
                return;
            end
        end
    catch
    end
    isBuiltin = false;
end

function val = castScalar(val, dataType)
    if ~isnumeric(val), return; end
    switch dataType
        case 'uint8',   val = uint8(val);
        case 'uint16',  val = uint16(val);
        case 'uint32',  val = uint32(val);
        case 'uint64',  val = uint64(val);
        case 'int8',    val = int8(val);
        case 'int16',   val = int16(val);
        case 'int32',   val = int32(val);
        case 'int64',   val = int64(val);
        case 'single',  val = single(val);
        case 'double',  val = double(val);
        case 'logical', val = logical(val);
        case 'boolean', val = logical(val);
        otherwise
    end
end

function arr = castArray(arr, dataType)
    if ~isnumeric(arr), return; end
    switch dataType
        case 'uint8',   arr = uint8(arr);
        case 'uint16',  arr = uint16(arr);
        case 'uint32',  arr = uint32(arr);
        case 'uint64',  arr = uint64(arr);
        case 'int8',    arr = int8(arr);
        case 'int16',   arr = int16(arr);
        case 'int32',   arr = int32(arr);
        case 'int64',   arr = int64(arr);
        case 'single',  arr = single(arr);
        case 'double',  arr = double(arr);
        case 'logical', arr = logical(arr);
        case 'boolean', arr = logical(arr);
        otherwise
    end
end