classdef SimulinkInspector < handle
    properties
        Fig, DataTable, DescArea, BlockHandle
        TableVar, XVar, YVar
        Mode % '1D', '2D', 'Standard'
        IsEnum = false
        EnumClass = ''
        EnumMembers = {}
        % 内部UI组件引用
        BtnSave, BtnCancel, TitleLabel, AxisXLabel, AxisYLabel
        % --- 新增组件 ---
        BtnInterpX, BtnInterpY
        % --- 保存到文件组件 ---
        BtnSaveFile, FileNameEdit
        % --- 单调性状态标签 ---
        MonotonicityLabel
        % --- 当前选择跟踪 ---
        CurrentSelection = [1, 1]
        % 注意：BtnPaste 已删除（粘贴通过快捷键实现）
    end
    
    methods (Static)
        function launch(hBlock)
            if nargin < 1, hBlock = gcbh; end
            if isempty(hBlock) || hBlock == -1, return; end

            % 单实例控制：如果已经存在实例，先关闭它
            persistent existingInstance;
            if ~isempty(existingInstance) && isvalid(existingInstance)
                delete(existingInstance.Fig);
            end

            % 创建新实例
            newInstance = SimulinkInspector(hBlock);
            existingInstance = newInstance;
        end
    end
    
    methods
        function obj = SimulinkInspector(hBlock)
            obj.BlockHandle = hBlock;
            obj.parseAndShow();
        end
        
        function parseAndShow(obj)
            bType = get_param(obj.BlockHandle, 'BlockType');
            obj.Mode = 'Standard'; obj.XVar = ''; obj.YVar = '';
            
            try
                % 1. 提取变量名逻辑
                if ismember(bType, {'Lookup_n-D', 'Lookup'})
                    obj.TableVar = get_param(obj.BlockHandle, 'Table');
                    if strcmp(bType, 'Lookup_n-D')
                        dims = str2double(get_param(obj.BlockHandle, 'NumberOfTableDimensions'));
                        obj.YVar = get_param(obj.BlockHandle, 'BreakpointsForDimension1');
                        if dims >= 2
                            obj.XVar = get_param(obj.BlockHandle, 'BreakpointsForDimension2');
                            obj.Mode = '2D';
                        else
                            obj.XVar = obj.YVar; obj.YVar = ''; obj.Mode = '1D';
                        end
                    else
                        obj.XVar = get_param(obj.BlockHandle, 'InputValues'); obj.Mode = '1D';
                    end
                else
                    if ismember(bType, {'Constant'}), obj.TableVar = get_param(obj.BlockHandle, 'Value');
                    elseif ismember(bType, {'Inport', 'Outport'})
                        lh = get_param(obj.BlockHandle, 'LineHandles');
                        lH = (strcmp(bType,'Inport'))*lh.Outport + (strcmp(bType,'Outport'))*lh.Inport;
                        if lH ~= -1, obj.TableVar = get_param(lH, 'Name'); end
                    end
                end
                
                % 安全性检查
                if isempty(obj.TableVar) || ~isvarname(obj.TableVar)
                    errordlg('该模块未关联有效变量（可能直接写了数值或表达式）。', '解析失败');
                    return; 
                end

                % 检查变量是否存在于工作区
                if ~evalin('base', sprintf('exist(''%s'', ''var'')', obj.TableVar))
                    errordlg(sprintf('工作区中未找到变量: "%s"。\n请确认该变量是否已在工作区定义。', obj.TableVar), '变量未定义');
                    return;
                end
                
                obj.checkEnumStatus();
                obj.createUI();
            catch ME
                errordlg(['工具运行出错: ', ME.message]);
            end
        end
        
        function checkEnumStatus(obj)
            v = evalin('base', obj.TableVar);
            className = '';
            if isa(v, 'Simulink.Parameter') && startsWith(v.DataType, 'Enum:')
                className = strtrim(v.DataType(6:end));
            elseif isenum(v) || (isa(v, 'Simulink.Parameter') && isenum(v.Value))
                val = v; if isa(v, 'Simulink.Parameter'), val = v.Value; end
                className = class(val);
            end
            if ~isempty(className)
                try
                    m = enumeration(className);
                    if ~isempty(m)
                        obj.IsEnum = true; obj.EnumClass = className;
                        obj.EnumMembers = reshape(cellstr(string(m)), 1, []);
                    end
                catch
                end
            end
        end
        
        function createUI(obj)
            data = obj.prepareData();
            [numRows, numCols] = size(data);
            
            % --- 计算初始动态尺寸 ---
            screen = get(0, 'ScreenSize');
            rowH = 22; colW = 85; 
            descH = 45; 
            axisH = 0; if ~strcmp(obj.Mode, 'Standard'), axisH = 22; if strcmp(obj.Mode, '2D'), axisH = 44; end; end
            
            % 初始宽度：根据列数计算，最小600，最大屏幕80%
            initW = min(max(numCols * colW + 40, 600), screen(3)*0.8);
            % 初始高度：根据行数计算，最小400，最大屏幕70%
            initH = min(max(numRows * rowH + descH + axisH + 150, 400), screen(4)*0.7);

            % 创建 Figure 并关闭自动缩放以允许自定义 SizeChangedFcn
            obj.Fig = uifigure('Name', ['快速编辑: ', obj.TableVar], ...
                'Position', [100 100 initW initH], ...
                'Resize', 'on', ...
                'AutoResizeChildren', 'off');
            movegui(obj.Fig, 'center');

            % --- 保存到文件控件 - 放在右上角，高于标题 ---
            obj.FileNameEdit = uieditfield(obj.Fig, 'Value', 'ManCal.m', 'Tooltip', '输入要保存的文件名');
            obj.BtnSaveFile = uibutton(obj.Fig, 'Text', '保存变量至文件', 'BackgroundColor', [0.2 0.4 0.7], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(src,e) obj.saveToFile());

            % 标题
            obj.TitleLabel = uilabel(obj.Fig, 'Text', obj.TableVar, 'FontWeight', 'bold', 'FontSize', 12);
            
            % 描述区
            vObj = evalin('base', obj.TableVar);
            vDesc = ''; if isprop(vObj, 'Description'), vDesc = vObj.Description; end
            obj.DescArea = uitextarea(obj.Fig, 'Value', vDesc, 'Editable', 'off', 'BackgroundColor', [0.96 0.96 0.96], 'FontSize', 11);
            
            % 轴信息标签
            if ~strcmp(obj.Mode, 'Standard')
                obj.AxisXLabel = uilabel(obj.Fig, 'Text', obj.getSingleVarInfo(obj.XVar, 'X轴'), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
                if strcmp(obj.Mode, '2D')
                    obj.AxisYLabel = uilabel(obj.Fig, 'Text', obj.getSingleVarInfo(obj.YVar, 'Y轴'), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
                end
                % 添加单调性状态标签（初始隐藏）
                obj.MonotonicityLabel = uilabel(obj.Fig, 'Text', '', 'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 11, 'FontColor', 'red', 'Visible', 'off');
            end
            
            % 表格配置
            colFmt = cell(1, numCols);
            colEditable = true(1, numCols);  % 默认所有列都可编辑

            if obj.IsEnum
                startC = 1; if strcmp(obj.Mode, '2D'), startC = 2; end
                for c = startC:numCols, colFmt{c} = obj.EnumMembers; end
            end

            obj.DataTable = uitable(obj.Fig, 'Data', data, 'ColumnEditable', colEditable, 'RowName', {}, 'ColumnName', {}, 'ColumnFormat', colFmt, 'FontSize', 11, 'CellEditCallback', @(src, e) obj.onCellEdit(e), 'Enable', 'on', 'CellSelectionCallback', @(src, e) obj.onCellSelection(e));

            % 2D模式下设置左上角单元格为不可编辑状态（视觉提示）
            if strcmp(obj.Mode, '2D')
                % 为左上角单元格添加特殊样式，表明不可编辑
                nonEditableStyle = uistyle('FontColor', [0.5 0.5 0.5], 'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');
                addStyle(obj.DataTable, nonEditableStyle, 'cell', [1, 1]);
            end

            % 不再设置快捷键粘贴（由KeyPressFcn统一处理）
            addStyle(obj.DataTable, uistyle('HorizontalAlignment', 'center'));
            if ~strcmp(obj.Mode, 'Standard')
                % 检查坐标轴单调性并设置样式
                obj.checkAxisMonotonicity();
            end
            
            % 按钮
            obj.BtnSave = uibutton(obj.Fig, 'Text', '确定保存', 'BackgroundColor', [0.15 0.45 0.15], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(src,e) obj.saveData());
            obj.BtnCancel = uibutton(obj.Fig, 'Text', '取消', 'ButtonPushedFcn', @(src,e) delete(obj.Fig));

            % --- 新增插值按钮 ---
            if ~strcmp(obj.Mode, 'Standard') && ~obj.IsEnum
                obj.BtnInterpX = uibutton(obj.Fig, 'Text', '↔ 横向线性插值', 'Tooltip', '选中一行区域，根据首尾自动填充中间值', 'ButtonPushedFcn', @(src,e) obj.doInterpolate('X'));
                if strcmp(obj.Mode, '2D')
                    obj.BtnInterpY = uibutton(obj.Fig, 'Text', '↕ 纵向线性插值', 'Tooltip', '选中一列区域，根据首尾自动填充中间值', 'ButtonPushedFcn', @(src,e) obj.doInterpolate('Y'));
                end
            end

            % 设置缩放回调并执行一次初始化
            obj.Fig.SizeChangedFcn = @(src, e) obj.onResize();
            obj.onResize();

            % --- 新增：绑定键盘快捷键支持（兼容R2020）---
            obj.DataTable.KeyPressFcn = @(src, event) obj.handleKeyPress(event);
            obj.Fig.KeyPressFcn = @(src, event) obj.handleKeyPress(event); % 备用，确保焦点在表格外也能响应
        end
        
        function onResize(obj)
            % 手动处理布局自适应逻辑
            figPos = obj.Fig.Position;
            w = figPos(3); h = figPos(4);
            
            % 1. 保存控件放在右上角，留出适当边距
            obj.FileNameEdit.Position = [w-260 h-45 120 25];
            obj.BtnSaveFile.Position = [w-125 h-45 120 32];

            % 2. 单调性提示标签居中显示（避开改名框）
            if isprop(obj, 'MonotonicityLabel') && ~isempty(obj.MonotonicityLabel)
                labelWidth = min(w-300, 200);  % 留出改名框空间，最大200
                labelX = max(15, (w-labelWidth-260)/2);  % 居中，但至少留15像素左边距
                obj.MonotonicityLabel.Position = [labelX h-45 labelWidth 32];  % 调整位置和高度
                obj.MonotonicityLabel.HorizontalAlignment = 'center';   % 居中
                obj.MonotonicityLabel.FontSize = 12;                    % 加大字体
                obj.MonotonicityLabel.FontWeight = 'bold';              % 加粗
            end

            % 3. 顶部标题和描述
            obj.TitleLabel.Position = [15 h-60 w-30 25];
            obj.DescArea.Position = [15 h-110 w-30 45];
            
            yPtr = h - 115;
            % 3. 坐标轴信息
            if ~isempty(obj.AxisXLabel)
                obj.AxisXLabel.Position = [15 yPtr-22 w-30 22];
                yPtr = yPtr - 22;
            end
            if ~isempty(obj.AxisYLabel)
                obj.AxisYLabel.Position = [15 yPtr-22 w-30 22];
                yPtr = yPtr - 22;
            end
            
            % 3. 表格高度自适应（占据中间所有剩余空间）
            tableBottom = 60; 
            tableHeight = yPtr - tableBottom - 10;
            obj.DataTable.Position = [15 tableBottom w-30 max(tableHeight, 50)];
            
            % 4. 按钮固定在底部
            obj.BtnSave.Position = [w-115 12 100 32];
            obj.BtnCancel.Position = [w-205 12 80 32];

            if ~isempty(obj.BtnInterpX)
                obj.BtnInterpX.Position = [15 12 120 32];
            end
            if ~isempty(obj.BtnInterpY)
                obj.BtnInterpY.Position = [140 12 120 32];
            end
            % 注意：BtnPaste 相关布局代码已删除
        end

        function doInterpolate(obj, direction)
            sel = obj.DataTable.Selection; % uifigure 返回的是 Nx2 的单元格坐标列表
            if isempty(sel), return; end

            % 计算选中区域的边界 [r1, c1, r2, c2]
            r1 = min(sel(:,1)); r2 = max(sel(:,1));
            c1 = min(sel(:,2)); c2 = max(sel(:,2));

            data = obj.DataTable.Data;
            % 数据起始行列（避开坐标轴标签）
            dataStartR = 1; dataStartC = 1;
            if strcmp(obj.Mode, '2D'), dataStartR = 2; dataStartC = 2; 
            elseif strcmp(obj.Mode, '1D'), dataStartR = 2; end

            if strcmp(direction, 'X')
                % --- 基于 X 轴值的线性插值 ---
                if strcmp(obj.Mode, '2D')
                    xAxis = nan(1, size(data,2)-1);
                    for jj = 2:size(data,2)
                        xAxis(jj-1) = str2double(data{1, jj});
                    end
                    colOffset = 1; % data 列索引 - colOffset 对应 xAxis 索引
                else
                    xAxis = nan(1, size(data,2));
                    for jj = 1:size(data,2)
                        xAxis(jj) = str2double(data{1, jj});
                    end
                    colOffset = 0;
                end

                for r = max(r1, dataStartR) : min(r2, size(data,1))
                    idx1 = max(c1, dataStartC); idx2 = min(c2, size(data,2));
                    if idx2 - idx1 < 2, continue; end

                    vStart = str2double(data{r, idx1});
                    vEnd = str2double(data{r, idx2});
                    if isnan(vStart) || isnan(vEnd), continue; end

                    x1 = xAxis(idx1 - colOffset);
                    x2 = xAxis(idx2 - colOffset);

                    if isnan(x1) || isnan(x2) || x2 == x1
                        % 退回到基于索引的均匀插值（无法使用坐标轴信息）
                        vals = linspace(vStart, vEnd, idx2 - idx1 + 1);
                    else
                        vals = zeros(1, idx2 - idx1 + 1);
                        for kk = idx1:idx2
                            xi = xAxis(kk - colOffset);
                            t = (xi - x1) / (x2 - x1);
                            vals(kk - idx1 + 1) = vStart + (vEnd - vStart) * t;
                        end
                    end

                    for c = idx1+1 : idx2-1
                        data{r, c} = num2str(round(vals(c - idx1 + 1), 6));
                    end
                end
            else
                % --- 基于 Y 轴值的线性插值 ---
                if strcmp(obj.Mode, '2D')
                    yAxis = nan(size(data,1)-1, 1);
                    for ii = 2:size(data,1)
                        yAxis(ii-1) = str2double(data{ii, 1});
                    end
                    rowOffset = 1;
                else
                    yAxis = nan(size(data,1), 1);
                    for ii = 1:size(data,1)
                        yAxis(ii) = str2double(data{ii, 1});
                    end
                    rowOffset = 0;
                end

                for c = max(c1, dataStartC) : min(c2, size(data,2))
                    idx1 = max(r1, dataStartR); idx2 = min(r2, size(data,1));
                    if idx2 - idx1 < 2, continue; end

                    vStart = str2double(data{idx1, c});
                    vEnd = str2double(data{idx2, c});
                    if isnan(vStart) || isnan(vEnd), continue; end

                    y1 = yAxis(idx1 - rowOffset);
                    y2 = yAxis(idx2 - rowOffset);

                    if isnan(y1) || isnan(y2) || y2 == y1
                        vals = linspace(vStart, vEnd, idx2 - idx1 + 1);
                    else
                        vals = zeros(idx2 - idx1 + 1, 1);
                        for kk = idx1:idx2
                            yi = yAxis(kk - rowOffset);
                            t = (yi - y1) / (y2 - y1);
                            vals(kk - idx1 + 1) = vStart + (vEnd - vStart) * t;
                        end
                    end

                    for r = idx1+1 : idx2-1
                        data{r, c} = num2str(round(vals(r - idx1 + 1), 6));
                    end
                end
            end
            obj.DataTable.Data = data;
        end
        
        function data = prepareData(obj)
            T = obj.getWValue(obj.TableVar);
            X = obj.getWValue(obj.XVar); Y = obj.getWValue(obj.YVar);
            if strcmp(obj.Mode, '2D')
                data = cell(length(Y)+1, length(X)+1); data{1, 1} = 'Y \ X'; 
                for j=1:length(X), data{1, j+1} = num2str(X(j)); end
                for i=1:length(Y), data{i+1, 1} = num2str(Y(i)); end
                for i=1:length(Y), for j=1:length(X)
                    val = T(i,j); if obj.IsEnum, data{i+1, j+1} = char(val); else, data{i+1, j+1} = num2str(val); end
                end; end
            elseif strcmp(obj.Mode, '1D')
                data = cell(2, length(X));
                for j=1:length(X), data{1, j} = num2str(X(j)); end
                for j=1:length(X)
                    val = T(j); if obj.IsEnum, data{2, j} = char(val); else, data{2, j} = num2str(val); end
                end
            else
                if obj.IsEnum, data = {char(T)}; else, data = cellstr(string(T)); end
            end
        end
        
        function saveData(obj)
            try
                raw = obj.DataTable.Data; [R, C] = size(raw);
                if strcmp(obj.Mode, '2D')
                    newX = zeros(1, C-1); for j=2:C, newX(j-1) = str2double(raw{1,j}); end
                    newY = zeros(R-1, 1); for i=2:R, newY(i-1) = str2double(raw{i,1}); end
                    newT = obj.castToType(raw(2:end, 2:end));
                    obj.setWValue(obj.XVar, newX); obj.setWValue(obj.YVar, newY); obj.setWValue(obj.TableVar, newT);
                elseif strcmp(obj.Mode, '1D')
                    newX = zeros(1, C); for j=1:C, newX(j) = str2double(raw{1,j}); end
                    newT = obj.castToType(raw(2, :));
                    obj.setWValue(obj.XVar, newX); obj.setWValue(obj.TableVar, newT);
                else
                    obj.setWValue(obj.TableVar, obj.castToType(raw));
                end
                delete(obj.Fig); disp('✅ 保存成功');
            catch ME
                errordlg(['保存失败: ', ME.message]);
            end
        end

        function saveDataSilent(obj)
            try
                raw = obj.DataTable.Data; [R, C] = size(raw);
                if strcmp(obj.Mode, '2D')
                    newX = zeros(1, C-1); for j=2:C, newX(j-1) = str2double(raw{1,j}); end
                    newY = zeros(R-1, 1); for i=2:R, newY(i-1) = str2double(raw{i,1}); end
                    newT = obj.castToType(raw(2:end, 2:end));
                    obj.setWValue(obj.XVar, newX); obj.setWValue(obj.YVar, newY); obj.setWValue(obj.TableVar, newT);
                elseif strcmp(obj.Mode, '1D')
                    newX = zeros(1, C); for j=1:C, newX(j) = str2double(raw{1,j}); end
                    newT = obj.castToType(raw(2, :));
                    obj.setWValue(obj.XVar, newX); obj.setWValue(obj.TableVar, newT);
                else
                    obj.setWValue(obj.TableVar, obj.castToType(raw));
                end
            catch
                % 静默模式，不显示错误
            end
        end
        
        function out = castToType(obj, cellData)
            [R, C] = size(cellData);
            if obj.IsEnum
                sample = evalin('base', [obj.EnumClass, '.', cellData{1,1}]);
                out = repmat(sample, R, C);
                for i=1:R, for j=1:C, out(i,j) = evalin('base', [obj.EnumClass, '.', cellData{i,j}]); end; end
            else
                out = zeros(R, C);
                for i=1:R, for j=1:C, v = str2double(cellData{i,j}); if isnan(v), v=0; end; out(i,j) = v; end; end
            end
        end
        
        function val = getWValue(obj, varName)
            if isempty(varName), val=[]; return; end
            v = evalin('base', varName);
            if isa(v, 'Simulink.Parameter'), val = v.Value;
            elseif isa(v, 'Simulink.Signal'), sVal = v.InitialValue; val = str2num(sVal); if isempty(val), val = sVal; end
            else, val = v; end
        end
        
        function setWValue(obj, varName, newVal)
            v = evalin('base', varName);
            if isa(v, 'Simulink.Parameter'), v.Value = newVal;
            elseif isa(v, 'Simulink.Signal'), v.InitialValue = mat2str(newVal);
            else, v = newVal; 
            end
            assignin('base', varName, v);
        end
        
        function str = getSingleVarInfo(obj, varName, label)
            if isempty(varName), str=''; return; end
            if ~evalin('base', sprintf('exist(''%s'', ''var'')', varName)), str = [label, ': ', varName, ' (未定义)']; return; end
            vObj = evalin('base', varName);
            desc = ''; if isprop(vObj, 'Description'), desc = vObj.Description; end
            str = sprintf('%s: %s (%s)', label, varName, desc);
        end

        function saveToFile(obj)
            try
                % 首先执行确定保存功能（保存当前工作区的值）
                obj.saveDataSilent();

                filename = obj.FileNameEdit.Value;
                if isempty(filename)
                    errordlg('请输入文件名', '文件名为空');
                    return;
                end

                % 确保文件扩展名是.m
                if ~endsWith(filename, '.m')
                    filename = [filename, '.m'];
                end

                % 获取所有需要保存的变量
                variables = struct();

                % 主表变量
                mainVar = obj.getWValue(obj.TableVar);
                variables.(obj.TableVar) = struct('value', mainVar, 'description', obj.getVarDescription(obj.TableVar), 'dataType', obj.getVarDataType(obj.TableVar), 'isEnum', obj.IsEnum);

                % 如果是查表模式，还需要保存坐标轴变量
                if ~strcmp(obj.Mode, 'Standard')
                    if ~isempty(obj.XVar)
                        xVar = obj.getWValue(obj.XVar);
                        variables.(obj.XVar) = struct('value', xVar, 'description', obj.getVarDescription(obj.XVar), 'dataType', obj.getVarDataType(obj.XVar), 'isEnum', false);
                    end
                    if ~isempty(obj.YVar) && strcmp(obj.Mode, '2D')
                        yVar = obj.getWValue(obj.YVar);
                        variables.(obj.YVar) = struct('value', yVar, 'description', obj.getVarDescription(obj.YVar), 'dataType', obj.getVarDataType(obj.YVar), 'isEnum', false);
                    end
                end

                % 保存到文件（采用合并方式）
                obj.writeVariablesToFile(filename, variables);

                % 自动关闭UI（不需要提示）
                delete(obj.Fig);
            catch ME
                errordlg(['保存文件失败: ', ME.message], '保存失败');
            end
        end

        function desc = getVarDescription(obj, varName)
            if isempty(varName), desc = ''; return; end
            try
                vObj = evalin('base', varName);
                if isprop(vObj, 'Description')
                    desc = vObj.Description;
                else
                    desc = '';
                end
            catch
                desc = '';
            end
        end

        function dataType = getVarDataType(obj, varName)
            if isempty(varName), dataType = 'single'; return; end
            try
                vObj = evalin('base', varName);
                if isa(vObj, 'Simulink.Parameter')
                    dataType = vObj.DataType;
                elseif isa(vObj, 'Simulink.Signal')
                    dataType = 'single';
                else
                    dataType = 'single';
                end
            catch
                dataType = 'single';
            end
        end

        function writeVariablesToFile(obj, filename, variables)
            % --- 修复路径问题：始终使用当前工作目录下的完整路径 ---
            % 构造当前目录下的完整文件路径（忽略 MATLAB 搜索路径）
            fullPath = fullfile(pwd, filename);

            % 读取现有文件内容（仅检查当前目录）
            existingContent = '';
            if exist(fullPath, 'file') == 2   % 2 表示文件存在
                fid_read = fopen(fullPath, 'r');
                if fid_read ~= -1
                    existingContent = fread(fid_read, '*char')';
                    fclose(fid_read);
                end
            end

            % 解析现有文件中的变量定义 - 使用逐行解析
            existingVars = struct();
            if ~isempty(existingContent)
                lines = strsplit(existingContent, '\n');
                i = 1;
                while i <= length(lines)
                    line = strtrim(lines{i});
                    % 支持两种注释格式："% 参数:" 和 "% 枚举参数:"
                    if startsWith(line, '% 参数:') || startsWith(line, '% 枚举参数:')
                        % 提取变量名
                        % 提取变量名，格式为 "% 参数: VAR_NAME" 或 "% 枚举参数: VAR_NAME"
                        parts = strsplit(line, ':');
                        if length(parts) >= 2
                            varName = strtrim(parts{2});
                        else
                            varName = '';
                        end
                        % 收集这个变量的所有行直到assignin语句
                        varLines = {lines{i}}; % 开始于%参数行
                        i = i + 1;
                        foundAssignin = false;
                        while i <= length(lines) && ~foundAssignin
                            currentLine = lines{i};
                            varLines{end+1} = currentLine;

                            % 检查是否找到了当前变量的assignin语句
                            if contains(currentLine, ['assignin(''base'', ''' varName ''','])
                                foundAssignin = true;
                            end
                            i = i + 1;
                        end
                        if foundAssignin
                            existingVars.(varName) = strjoin(varLines, '\n');
                        end
                    else
                        i = i + 1;
                    end
                end
            end

            % 写入文件（使用同一个 fullPath）
            fid = fopen(fullPath, 'w');
            if fid == -1
                error('无法创建文件: %s', fullPath);
            end

            % 写入文件头
            fprintf(fid, '%% 自动生成的参数文件\n');
            fprintf(fid, '%% 生成时间: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

            % 获取变量名列表
            existingVarNames = fieldnames(existingVars);
            currentVarNames = fieldnames(variables);

            % 首先写入现有文件中保留的变量（不在当前variables中的）
            for i = 1:length(existingVarNames)
                varName = existingVarNames{i};
                if ~ismember(varName, currentVarNames)
                    fprintf(fid, '%s\n\n', existingVars.(varName));
                end
            end

            % 然后写入当前变量（更新现有或添加新的）
            for i = 1:length(currentVarNames)
                varName = currentVarNames{i};
                varInfo = variables.(varName);

                % 写入变量注释
                if isfield(varInfo, 'isEnum') && varInfo.isEnum && isprop(obj, 'IsEnum') && obj.IsEnum
                    fprintf(fid, '%% 枚举参数: %s\n', varName);
                else
                    fprintf(fid, '%% 参数: %s\n', varName);
                end

                % 创建Simulink.Parameter对象
                fprintf(fid, '%s = Simulink.Parameter;\n', varName);

                % 设置数据类型
                fprintf(fid, '%s.DataType = ''%s'';\n', varName, varInfo.dataType);

                % 设置描述
                if ~isempty(varInfo.description)
                    fprintf(fid, '%s.Description = ''%s'';\n', varName, varInfo.description);
                end

                % 设置值
                if isfield(varInfo, 'isEnum') && varInfo.isEnum && isprop(obj, 'IsEnum') && obj.IsEnum
                    % 枚举类型特殊处理
                    enumValue = varInfo.value;
                    enumClass = class(enumValue);
                    enumMember = char(enumValue);
                    fprintf(fid, '%s.Value = %s.%s;\n', varName, enumClass, enumMember);
                else
                    % 数值类型
                    val = varInfo.value;
                    if isscalar(val)
                        fprintf(fid, '%s.Value = %g;\n', varName, val);
                    else
                        valStr = mat2str(val);
                        fprintf(fid, '%s.Value = %s;\n', varName, valStr);
                    end
                end

                % assignin语句
                fprintf(fid, 'assignin(''base'', ''%s'', %s);\n\n', varName, varName);
            end

            fclose(fid);
        end

        function checkAxisMonotonicity(obj)
            % 检查坐标轴单调性并设置相应的样式
            if strcmp(obj.Mode, 'Standard')
                return;
            end

            % 检查所有坐标轴的单调性
            isAnyAxisNonMonotonic = false;

            if strcmp(obj.Mode, '2D')
                % 2D模式：检查X轴和Y轴
                xData = obj.getWValue(obj.XVar);
                yData = obj.getWValue(obj.YVar);

                if ~obj.isMonotonicIncreasing(xData) || ~obj.isMonotonicIncreasing(yData)
                    isAnyAxisNonMonotonic = true;
                end

                % 应用颜色到坐标轴
                obj.applyAxisColors('X', xData);
                obj.applyAxisColors('Y', yData);

            elseif strcmp(obj.Mode, '1D')
                % 1D模式：检查X轴
                xData = obj.getWValue(obj.XVar);

                if ~obj.isMonotonicIncreasing(xData)
                    isAnyAxisNonMonotonic = true;
                end

                % 应用颜色到坐标轴
                obj.applyAxisColors('X', xData);
            end

            % 更新顶部警告标签
            if isAnyAxisNonMonotonic
                obj.MonotonicityLabel.Text = '坐标轴未单调递增！';
                obj.MonotonicityLabel.Visible = 'on';
            else
                obj.MonotonicityLabel.Text = '';
                obj.MonotonicityLabel.Visible = 'off';
            end
        end

        function applyAxisColors(obj, axisType, axisData)
            % 应用颜色到指定坐标轴 - 优化算法：每个点与后面所有值比较
            if isempty(axisData) || length(axisData) <= 1
                return;
            end

            data = obj.DataTable.Data;

            if strcmp(axisType, 'X')
                % X轴着色
                if strcmp(obj.Mode, '2D')
                    % 2D模式：X轴在第一行，第2列开始
                    for j = 2:size(data, 2)
                        if j-1 <= length(axisData)
                            val = axisData(j-1);
                            % 检查当前值是否大于等于后面任意值（存在非单调）
                            isRed = false;
                            for k = j:length(axisData)  % 与后面所有点比较
                                if val >= axisData(k)
                                    isRed = true;
                                    break;
                                end
                            end

                            if isRed
                                cellStyle = uistyle('BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'white', 'FontWeight', 'bold');
                            else
                                cellStyle = uistyle('BackgroundColor', [0.13 0.35 0.58], 'FontColor', 'white', 'FontWeight', 'bold');
                            end

                            addStyle(obj.DataTable, cellStyle, 'cell', [1, j]);
                        end
                    end
                    % 左上角保持灰色
                    addStyle(obj.DataTable, uistyle('BackgroundColor', [0.8 0.8 0.8]), 'cell', [1,1]);
                else
                    % 1D模式：X轴在第一行
                    for j = 1:size(data, 2)
                        if j <= length(axisData)
                            val = axisData(j);
                            % 检查当前值是否大于等于后面任意值（存在非单调）
                            isRed = false;
                            for k = j+1:length(axisData)  % 与后面所有点比较
                                if val >= axisData(k)
                                    isRed = true;
                                    break;
                                end
                            end

                            if isRed
                                cellStyle = uistyle('BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'white', 'FontWeight', 'bold');
                            else
                                cellStyle = uistyle('BackgroundColor', [0.13 0.35 0.58], 'FontColor', 'white', 'FontWeight', 'bold');
                            end

                            addStyle(obj.DataTable, cellStyle, 'cell', [1, j]);
                        end
                    end
                end

            else % Y轴
                % Y轴着色：Y轴在第一列，第2行开始
                for i = 2:size(data, 1)
                    if i-1 <= length(axisData)
                        val = axisData(i-1);
                        % 检查当前值是否大于等于后面任意值（存在非单调）
                        isRed = false;
                        for k = i:length(axisData)  % 与后面所有点比较
                            if val >= axisData(k)
                                isRed = true;
                                break;
                            end
                        end

                        if isRed
                            cellStyle = uistyle('BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'white', 'FontWeight', 'bold');
                        else
                            cellStyle = uistyle('BackgroundColor', [0.13 0.35 0.58], 'FontColor', 'white', 'FontWeight', 'bold');
                        end

                        addStyle(obj.DataTable, cellStyle, 'cell', [i, 1]);
                    end
                end
            end
        end

        function checkSingleAxisMonotonicity(obj, axisType)
            % 检查单个坐标轴的单调性
            if strcmp(axisType, 'X')
                axisVar = obj.XVar;
                dataIdx = 1; % X轴数据在第一行
                isRow = true;
            else
                axisVar = obj.YVar;
                dataIdx = 1; % Y轴数据在第一列
                isRow = false;
            end

            if isempty(axisVar)
                return;
            end

            % 获取坐标轴数据
            axisData = obj.getWValue(axisVar);
            if isempty(axisData) || length(axisData) <= 1
                return;
            end

            % 检查单调性
            isMonotonic = obj.isMonotonicIncreasing(axisData);

            % 设置样式
            if isMonotonic
                % 单调递增：深蓝色背景
                axisStyle = uistyle('BackgroundColor', [0.13 0.35 0.58], 'FontColor', 'white', 'FontWeight', 'bold');
            else
                % 非单调：红色背景提示
                axisStyle = uistyle('BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'white', 'FontWeight', 'bold');
            end

            % 应用样式到表格
            if strcmp(obj.Mode, '2D')
                if strcmp(axisType, 'X')
                    addStyle(obj.DataTable, axisStyle, 'row', 1);
                    addStyle(obj.DataTable, uistyle('BackgroundColor', [0.8 0.8 0.8]), 'cell', [1,1]);
                else
                    addStyle(obj.DataTable, axisStyle, 'column', 1);
                end
            else
                if strcmp(axisType, 'X')
                    addStyle(obj.DataTable, axisStyle, 'row', 1);
                end
            end
        end

        function isMonotonic = isMonotonicIncreasing(obj, data)
            % 检查数据是否单调递增
            if length(data) <= 1
                isMonotonic = true;
                return;
            end

            isMonotonic = all(diff(data) > 0);
        end

        function onCellSelection(obj, event)
            % 处理单元格选择事件，更新选择范围
            if ~isempty(event.Indices)
                obj.CurrentSelection = event.Indices;
            end
        end

        function onCellEdit(obj, event)
            % 处理单元格编辑事件
            if isempty(event.EditData) || isempty(event.Indices)
                return;
            end

            row = event.Indices(1);
            col = event.Indices(2);

            % 2D模式下禁止编辑左上角单元格（第1行第1列）
            if strcmp(obj.Mode, '2D') && row == 1 && col == 1
                % 立即恢复原始值，不允许编辑
                data = obj.DataTable.Data;
                originalValue = data{row, col};
                % 强制刷新表格以取消编辑状态
                obj.DataTable.Data = data;
                return;
            end

            try
                % 检查是否为批量编辑（多单元格选择）
                selectedCells = obj.DataTable.Selection;
                if ~isempty(selectedCells) && size(selectedCells, 1) > 1
                    % 批量编辑模式
                    obj.handleBatchEdit(event, selectedCells);
                    return;
                end

                % 单个单元格编辑
                newValue = str2double(event.EditData);
                if isnan(newValue)
                    % 检查是否为运算表达式，如果是则忽略（应该由批量编辑处理）
                    if startsWith(event.EditData, {'+', '-', '*', '/', '^'})
                        return; % 运算表达式应该由批量编辑处理，这里忽略
                    end
                    return; % 其他无效输入，忽略
                end

                % 应用新值到表格
                data = obj.DataTable.Data;
                data{row, col} = num2str(newValue);
                obj.DataTable.Data = data;

                % 实时更新坐标轴颜色和单调性检查
                obj.updateRealTimeMonotonicity(row, col, newValue);

            catch ME
                % 编辑出错，显示错误信息
                errordlg(['编辑失败: ', ME.message], '编辑错误');
            end
        end

        function handleBatchEdit(obj, event, selectedCells)
            % 处理批量编辑，支持运算
            editData = event.EditData;
            if isempty(editData)
                return;
            end

            % 临时禁用单元格编辑回调，防止冲突
            originalCallback = obj.DataTable.CellEditCallback;
            obj.DataTable.CellEditCallback = [];

            try
                % 获取编辑发生的位置和原始值
                editRow = event.Indices(1);
                editCol = event.Indices(2);
                previousData = event.PreviousData;   % 编辑前的原始值

                % 解析输入，支持运算表达式
                if startsWith(editData, {'+', '-', '*', '/', '^'})
                    % 运算表达式，如 *2, +5, /3 等
                    obj.applyOperationToSelectedCells(selectedCells, editData, editRow, editCol, previousData);
                else
                    % 普通数值，直接应用
                    newValue = str2double(editData);
                    if ~isnan(newValue)
                        obj.applyValueToSelectedCells(selectedCells, num2str(newValue), editRow, editCol, previousData);
                    end
                end
            catch ME
                errordlg(['批量编辑失败: ', ME.message], '批量编辑错误');
            end

            % 恢复单元格编辑回调
            obj.DataTable.CellEditCallback = originalCallback;
        end

        function applyValueToSelectedCells(obj, selectedCells, valueStr, editRow, editCol, previousData)
            % 将固定值应用到选中的所有单元格
            data = obj.DataTable.Data;
            updatedAxes = {};

            for i = 1:size(selectedCells, 1)
                row = selectedCells(i, 1);
                col = selectedCells(i, 2);

                % 跳过左上角单元格
                if strcmp(obj.Mode, '2D') && row == 1 && col == 1
                    continue;
                end

                % 对于被编辑的单元格，确保即使新值与原始值相同也能正确刷新
                data{row, col} = valueStr;

                obj.recordUpdatedAxis(row, col, updatedAxes);
            end

            % 强制刷新表格以显示相同值的情况
            obj.DataTable.Enable = 'off';
            obj.DataTable.Data = data;
            obj.DataTable.Enable = 'on';
            drawnow;

            obj.updateAxesAfterBatchEdit(updatedAxes);
        end

        function applyOperationToSelectedCells(obj, selectedCells, operationStr, editRow, editCol, previousData)
            % 对选中的单元格应用运算
            data = obj.DataTable.Data;
            updatedAxes = {};

            % 解析运算
            operation = operationStr(1);
            operandStr = operationStr(2:end);
            operand = str2double(operandStr);

            if isnan(operand)
                errordlg('无效的运算表达式', '运算错误');
                return;
            end

            for i = 1:size(selectedCells, 1)
                row = selectedCells(i, 1);
                col = selectedCells(i, 2);

                % 跳过左上角单元格
                if strcmp(obj.Mode, '2D') && row == 1 && col == 1
                    continue;
                end

                % 获取当前值：如果是被编辑的单元格，使用编辑前的原始值；否则使用表格中的当前值
                if row == editRow && col == editCol
                    currentValueStr = previousData;
                else
                    currentValueStr = data{row, col};
                end

                currentValue = str2double(currentValueStr);
                if isnan(currentValue)
                    continue;   % 非数值单元格跳过
                end

                % 应用运算
                newValue = obj.calculateOperation(currentValue, operation, operand);
                data{row, col} = num2str(newValue);

                % 记录更新的坐标轴
                obj.recordUpdatedAxis(row, col, updatedAxes);
            end

            obj.DataTable.Data = data;
            drawnow;
            obj.updateAxesAfterBatchEdit(updatedAxes);
        end

        function newValue = calculateOperation(~, currentValue, operation, operand)
            % 执行数学运算
            switch operation
                case '+'
                    newValue = currentValue + operand;
                case '-'
                    newValue = currentValue - operand;
                case '*'
                    newValue = currentValue * operand;
                case '/'
                    if operand == 0
                        error('除数不能为零');
                    end
                    newValue = currentValue / operand;
                case '^'
                    newValue = currentValue ^ operand;
                otherwise
                    error('不支持的运算符: %s', operation);
            end
        end

        function recordUpdatedAxis(obj, row, col, updatedAxes)
            % 记录哪些坐标轴被更新了
            if strcmp(obj.Mode, '2D')
                if row == 1 && col > 1
                    updatedAxes{end+1} = 'X';
                elseif col == 1 && row > 1
                    updatedAxes{end+1} = 'Y';
                end
            elseif strcmp(obj.Mode, '1D') && row == 1
                updatedAxes{end+1} = 'X';
            end
        end

        function updateAxesAfterBatchEdit(obj, updatedAxes)
            % 批量编辑后更新坐标轴
            if ~strcmp(obj.Mode, 'Standard') && ~isempty(updatedAxes)
                uniqueAxes = unique(updatedAxes);
                for k = 1:length(uniqueAxes)
                    axisType = uniqueAxes{k};
                    % 更新工作区数据
                    obj.updateAxisDataInWorkspace(axisType);
                    % 更新颜色
                    if strcmp(axisType, 'X')
                        axisData = obj.getWValue(obj.XVar);
                        obj.applyAxisColors('X', axisData);
                    else
                        axisData = obj.getWValue(obj.YVar);
                        obj.applyAxisColors('Y', axisData);
                    end
                end
                % 更新警告标签
                obj.updateMonotonicityWarning();
            end
        end

        function validateAxisEdit(obj, row, col, newValue)
            % 验证坐标轴编辑是否符合单调性要求
            if strcmp(obj.Mode, 'Standard')
                return; % 标准模式不检查
            end

            % 2D模式下禁止编辑左上角单元格
            if strcmp(obj.Mode, '2D') && row == 1 && col == 1
                return;
            end

            % 确定编辑的是哪个坐标轴
            axisType = '';
            if strcmp(obj.Mode, '2D')
                if row == 1 && col > 1
                    axisType = 'X';
                    axisCol = col;
                    axisRow = 0;
                elseif col == 1 && row > 1
                    axisType = 'Y';
                    axisCol = 0;
                    axisRow = row;
                end
            elseif strcmp(obj.Mode, '1D') && row == 1
                axisType = 'X';
                axisCol = col;
                axisRow = 0;
            end

            if isempty(axisType)
                return; % 不是坐标轴编辑
            end

            % 应用新值到表格
            data = obj.DataTable.Data;
            data{row, col} = num2str(newValue);
            obj.DataTable.Data = data;

            % 更新实时颜色反馈
            obj.updateAxisColorFeedback(axisType, axisRow, axisCol, newValue);
        end

        function updateRealTimeMonotonicity(obj, row, col, newValue)
            % 实时更新单调性检查、颜色和提示（不弹框）
            if strcmp(obj.Mode, 'Standard')
                return; % 标准模式不检查
            end

            % 确定编辑的是哪个坐标轴
            axisType = '';
            if strcmp(obj.Mode, '2D')
                if row == 1 && col > 1
                    axisType = 'X';
                elseif col == 1 && row > 1
                    axisType = 'Y';
                else
                    return; % 不是坐标轴编辑
                end
            elseif strcmp(obj.Mode, '1D') && row == 1
                axisType = 'X';
            else
                return; % 不是坐标轴编辑
            end

            % 更新工作区变量值
            obj.updateAxisDataInWorkspace(axisType);

            % 重新应用颜色到整个坐标轴
            if strcmp(axisType, 'X')
                axisData = obj.getWValue(obj.XVar);
                obj.applyAxisColors('X', axisData);
            else
                axisData = obj.getWValue(obj.YVar);
                obj.applyAxisColors('Y', axisData);
            end

            % 检查单调性并显示/隐藏顶部警告标签（不再弹框）
            obj.updateMonotonicityWarning();
        end

        function updateAxisDataInWorkspace(obj, axisType)
            % 从表格数据更新工作区中的坐标轴数据
            data = obj.DataTable.Data;

            if strcmp(axisType, 'X')
                if strcmp(obj.Mode, '2D')
                    % 2D模式：X轴在第一行，第2列开始
                    newData = zeros(1, size(data, 2) - 1);
                    for j = 2:size(data, 2)
                        newData(j-1) = str2double(data{1, j});
                    end
                else
                    % 1D模式：X轴在第一行
                    newData = zeros(1, size(data, 2));
                    for j = 1:size(data, 2)
                        newData(j) = str2double(data{1, j});
                    end
                end
                obj.setWValue(obj.XVar, newData);
            else
                % Y轴
                newData = zeros(size(data, 1) - 1, 1);
                for i = 2:size(data, 1)
                    newData(i-1) = str2double(data{i, 1});
                end
                obj.setWValue(obj.YVar, newData);
            end
        end

        function isMonotonic = isAxisMonotonic(obj, axisType)
            % 检查指定坐标轴是否单调递增
            if strcmp(axisType, 'X')
                axisData = obj.getWValue(obj.XVar);
            else
                axisData = obj.getWValue(obj.YVar);
            end

            if isempty(axisData) || length(axisData) <= 1
                isMonotonic = true;
                return;
            end

            isMonotonic = all(diff(axisData) > 0);
        end

        function updateAxisColorFeedback(obj, axisType)
            % 实时更新坐标轴颜色反馈 - 使用applyAxisColors方法
            if strcmp(axisType, 'X')
                axisData = obj.getWValue(obj.XVar);
                obj.applyAxisColors('X', axisData);
                obj.checkMonotonicityViolation('X');
            else
                axisData = obj.getWValue(obj.YVar);
                obj.applyAxisColors('Y', axisData);
                obj.checkMonotonicityViolation('Y');
            end

            % 更新顶部警告标签
            obj.updateMonotonicityWarning();
        end

        function updateMonotonicityWarning(obj)
            % 更新顶部单调性警告标签
            if strcmp(obj.Mode, 'Standard')
                return;
            end

            isAnyAxisNonMonotonic = false;

            if strcmp(obj.Mode, '2D')
                % 检查X轴和Y轴的单调性
                xMonotonic = obj.isAxisMonotonic('X');
                yMonotonic = obj.isAxisMonotonic('Y');

                if ~xMonotonic || ~yMonotonic
                    isAnyAxisNonMonotonic = true;
                end
            elseif strcmp(obj.Mode, '1D')
                % 检查X轴的单调性
                xMonotonic = obj.isAxisMonotonic('X');
                if ~xMonotonic
                    isAnyAxisNonMonotonic = true;
                end
            end

            % 动态显示/隐藏警告标签
            if isAnyAxisNonMonotonic
                obj.MonotonicityLabel.Text = '坐标轴未单调递增！';
                obj.MonotonicityLabel.Visible = 'on';
            else
                obj.MonotonicityLabel.Text = '';
                obj.MonotonicityLabel.Visible = 'off';
            end
        end

        function checkMonotonicityViolation(obj, axisType)
            % 检查是否破坏了原有的单调性（不弹框，仅作内部使用）
            if strcmp(axisType, 'X')
                originalData = obj.getWValue(obj.XVar);
            else
                originalData = obj.getWValue(obj.YVar);
            end

            % 只有当原始数据是单调的时候才检查是否被破坏
            if ~isempty(originalData) && length(originalData) > 1 && obj.isMonotonicIncreasing(originalData)
                % 获取当前数据
                currentData = originalData;
                if strcmp(axisType, 'X')
                    data = obj.DataTable.Data;
                    if strcmp(obj.Mode, '2D')
                        currentData = zeros(1, size(data,2)-1);
                        for j = 2:size(data,2)
                            currentData(j-1) = str2double(data{1, j});
                        end
                    else
                        currentData = zeros(1, size(data,2));
                        for j = 1:size(data,2)
                            currentData(j) = str2double(data{1, j});
                        end
                    end
                else
                    data = obj.DataTable.Data;
                    currentData = zeros(size(data,1)-1, 1);
                    for i = 2:size(data,1)
                        currentData(i-1) = str2double(data{i, 1});
                    end
                end

                % 不再弹框，顶部标签已足够提示
            end
        end

        function isLocalMonotonic = checkLocalMonotonicity(~, data, index)
            % 检查指定位置的局部单调性
            % 规则：当前点比后面所有点都小，且比前面所有点都大
            isLocalMonotonic = true;

            if length(data) <= 1
                return;
            end

            currentValue = data(index);

            % 检查是否比前面所有点都大（如果有前面的点）
            if index > 1
                for i = 1:index-1
                    if data(i) >= currentValue
                        isLocalMonotonic = false;
                        return;
                    end
                end
            end

            % 检查是否比后面所有点都小（如果有后面的点）
            if index < length(data)
                for i = index+1:length(data)
                    if currentValue >= data(i)
                        isLocalMonotonic = false;
                        return;
                    end
                end
            end
        end

        function handlePasteOperation(obj)
            % 处理粘贴操作（通过按钮或快捷键调用）
            try
                % 获取剪贴板内容
                clipboardText = clipboard('paste');
                if isempty(clipboardText)
                    warndlg('剪贴板为空或无法访问', '粘贴失败');
                    return;
                end

                % 解析剪贴板内容（支持制表符分隔的文本）
                lines = strsplit(clipboardText, '\n');
                if isempty(lines)
                    warndlg('无法解析剪贴板内容', '粘贴失败');
                    return;
                end

                % 解析数据
                pasteData = {};
                for i = 1:length(lines)
                    line = strtrim(lines{i});
                    if ~isempty(line)
                        % 按制表符或空格分割
                        values = strsplit(line, {'\t', ' '});
                        rowData = {};
                        for j = 1:length(values)
                            val = strtrim(values{j});
                            if ~isempty(val)
                                numVal = str2double(val);
                                if ~isnan(numVal)
                                    rowData{end+1} = numVal;
                                else
                                    rowData{end+1} = val;
                                end
                            end
                        end
                        if ~isempty(rowData)
                            pasteData{end+1} = rowData;
                        end
                    end
                end

                if isempty(pasteData)
                    warndlg('没有有效的数据可以粘贴', '粘贴失败');
                    return;
                end

                % 获取当前选择范围
                selectedCells = obj.DataTable.Selection;
                if isempty(selectedCells) && ~isempty(obj.CurrentSelection)
                    selectedCells = obj.CurrentSelection;
                end

                if isempty(selectedCells)
                    % 如果没有选择，默认从(1,1)开始（跳过左上角如果是2D模式）
                    startRow = 1;
                    startCol = 1;
                    if strcmp(obj.Mode, '2D')
                        startCol = 2;  % 2D模式跳过第一列
                    end
                else
                    % 使用第一个选中的单元格作为起始位置
                    startRow = selectedCells(1, 1);
                    startCol = selectedCells(1, 2);
                end

                % 验证起始位置
                data = obj.DataTable.Data;
                if startRow > size(data, 1) || startCol > size(data, 2)
                    warndlg('选择的位置超出表格范围', '粘贴失败');
                    return;
                end

                % 应用粘贴数据并记录粘贴区域的行列范围
                updatedAxes = {};  % 记录哪些坐标轴被更新了
                minPasteRow = startRow;
                maxPasteRow = startRow;
                minPasteCol = startCol;
                maxPasteCol = startCol;

                for i = 1:length(pasteData)
                    rowData = pasteData{i};
                    targetRow = startRow + i - 1;

                    if targetRow > size(data, 1)
                        break; % 超出范围
                    end
                    maxPasteRow = max(maxPasteRow, targetRow);

                    for j = 1:length(rowData)
                        targetCol = startCol + j - 1;

                        if targetCol > size(data, 2)
                            break; % 超出范围
                        end
                        maxPasteCol = max(maxPasteCol, targetCol);

                        % 2D模式下禁止编辑左上角单元格
                        if strcmp(obj.Mode, '2D') && targetRow == 1 && targetCol == 1
                            continue; % 跳过左上角单元格的编辑
                        end

                        % 检查是否是坐标轴编辑
                        if strcmp(obj.Mode, '2D')
                            if targetRow == 1 && targetCol > 1
                                updatedAxes{end+1} = 'X';
                            elseif targetCol == 1 && targetRow > 1
                                updatedAxes{end+1} = 'Y';
                            end
                        elseif strcmp(obj.Mode, '1D') && targetRow == 1
                            updatedAxes{end+1} = 'X';
                        end

                        % 应用值
                        if isnumeric(rowData{j})
                            data{targetRow, targetCol} = num2str(rowData{j});
                        else
                            data{targetRow, targetCol} = rowData{j};
                        end
                    end
                end

                % 更新表格数据
                obj.DataTable.Data = data;

                % 将粘贴影响的区域设置为当前选中（高亮显示）
                if maxPasteRow >= minPasteRow && maxPasteCol >= minPasteCol
                    % 生成选中区域的行列索引矩阵
                    [rr, cc] = meshgrid(minPasteRow:maxPasteRow, minPasteCol:maxPasteCol);
                    newSelection = [rr(:), cc(:)];
                    obj.DataTable.Selection = newSelection;
                    obj.CurrentSelection = newSelection;
                end

                % 实时更新坐标轴数据和颜色
                if ~strcmp(obj.Mode, 'Standard')
                    uniqueAxes = unique(updatedAxes);
                    for k = 1:length(uniqueAxes)
                        axisType = uniqueAxes{k};
                        % 更新工作区数据
                        obj.updateAxisDataInWorkspace(axisType);
                        % 更新颜色
                        if strcmp(axisType, 'X')
                            axisData = obj.getWValue(obj.XVar);
                            obj.applyAxisColors('X', axisData);
                        else
                            axisData = obj.getWValue(obj.YVar);
                            obj.applyAxisColors('Y', axisData);
                        end
                    end
                    % 更新警告标签
                    obj.updateMonotonicityWarning();
                end

                % 粘贴成功不再弹框，用户可通过高亮确认

            catch ME
                % 粘贴失败，显示错误信息
                errordlg(['粘贴操作失败: ', ME.message], '粘贴错误');
            end
        end

        % --- 新增：键盘快捷键处理（兼容R2020）---
        function handleKeyPress(obj, event)
            % 处理键盘快捷键：Ctrl+C 复制，Ctrl+V 粘贴
            if isequal(event.Modifier, {'control'})
                switch lower(event.Key)
                    case 'c'
                        obj.copySelectedCells();
                    case 'v'
                        obj.handlePasteOperation();
                end
            end
        end

        function copySelectedCells(obj)
            % 将表格中选中的单元格内容复制到系统剪贴板
            sel = obj.DataTable.Selection;
            if isempty(sel)
                return;
            end

            data = obj.DataTable.Data;
            % 获取选中的行列范围
            rows = unique(sel(:,1));
            cols = unique(sel(:,2));

            % 提取选中区域数据
            selectedData = data(rows, cols);

            % 将元胞数组转换为制表符分隔的字符串（Excel可识别格式）
            strLines = cell(size(selectedData, 1), 1);
            for i = 1:size(selectedData, 1)
                rowVals = selectedData(i, :);
                % 将每个单元格转换为字符串
                strVals = cellfun(@(x) num2str(x), rowVals, 'UniformOutput', false);
                strLines{i} = strjoin(strVals, char(9));  % 制表符分隔
            end
            clipboardText = strjoin(strLines, char(10));   % 换行分隔

            % 写入剪贴板
            clipboard('copy', clipboardText);
        end
    end
end