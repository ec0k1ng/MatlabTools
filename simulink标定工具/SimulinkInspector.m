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
        UseLegacyUI = false
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

            obj.UseLegacyUI = obj.shouldUseLegacyUI();

            if obj.UseLegacyUI
                obj.createLegacyUI(data, numCols, initW, initH);
            else
                obj.createModernUI(data, numCols, initW, initH);
            end

            obj.onResize();
        end

        function createModernUI(obj, data, numCols, initW, initH)
            % 创建 Figure 并关闭自动缩放以允许自定义 SizeChangedFcn
            obj.Fig = uifigure('Name', ['快速编辑: ', obj.TableVar], ...
                'Position', [100 100 initW initH], ...
                'Resize', 'on', ...
                'AutoResizeChildren', 'off');
            movegui(obj.Fig, 'center');

            % --- 保存到文件控件 ---
            obj.FileNameEdit = uieditfield(obj.Fig, 'Value', obj.getPreferredFileName(), 'Tooltip', '输入要保存的文件名');
            obj.BtnSaveFile = uibutton(obj.Fig, 'Text', '保存至文件', 'BackgroundColor', [0.2 0.4 0.7], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(src,e) obj.saveToFile());

            % 标题
            obj.TitleLabel = uilabel(obj.Fig, 'Text', obj.TableVar, 'FontWeight', 'bold', 'FontSize', 12, 'HorizontalAlignment', 'left');

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
                obj.MonotonicityLabel = uilabel(obj.Fig, 'Text', '', 'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 11, 'FontColor', 'red', 'Visible', 'off');
            end

            % 表格配置
            colFmt = cell(1, numCols);
            colEditable = true(1, numCols);

            if obj.IsEnum
                startC = 1; if strcmp(obj.Mode, '2D'), startC = 2; end
                for c = startC:numCols, colFmt{c} = obj.EnumMembers; end
            end

            obj.DataTable = uitable(obj.Fig, 'Data', data, 'ColumnEditable', colEditable, 'RowName', {}, 'ColumnName', {}, 'ColumnFormat', colFmt, 'FontSize', 11, 'CellEditCallback', @(src, e) obj.onCellEdit(e), 'Enable', 'on', 'CellSelectionCallback', @(src, e) obj.onCellSelection(e));

            if strcmp(obj.Mode, '2D')
                nonEditableStyle = uistyle('FontColor', [0.5 0.5 0.5], 'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold');
                addStyle(obj.DataTable, nonEditableStyle, 'cell', [1, 1]);
            end

            addStyle(obj.DataTable, uistyle('HorizontalAlignment', 'center'));
            if ~strcmp(obj.Mode, 'Standard')
                obj.checkAxisMonotonicity();
            end

            obj.BtnSave = uibutton(obj.Fig, 'Text', '临时保存', 'BackgroundColor', [0.15 0.45 0.15], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(src,e) obj.saveData());
            obj.BtnCancel = uibutton(obj.Fig, 'Text', '取消', 'ButtonPushedFcn', @(src,e) delete(obj.Fig));

            if ~strcmp(obj.Mode, 'Standard') && ~obj.IsEnum
                obj.BtnInterpX = uibutton(obj.Fig, 'Text', '[X] 横向线性插值', 'Tooltip', '选中一行区域，根据首尾自动填充中间值', 'ButtonPushedFcn', @(src,e) obj.doInterpolate('X'));
                if strcmp(obj.Mode, '2D')
                    obj.BtnInterpY = uibutton(obj.Fig, 'Text', '[Y] 纵向线性插值', 'Tooltip', '选中一列区域，根据首尾自动填充中间值', 'ButtonPushedFcn', @(src,e) obj.doInterpolate('Y'));
                end
            end

            obj.Fig.SizeChangedFcn = @(src, e) obj.onResize();
            obj.DataTable.KeyPressFcn = @(src, event) obj.handleKeyPress(event);
            obj.Fig.KeyPressFcn = @(src, event) obj.handleKeyPress(event);
        end

        function createLegacyUI(obj, data, numCols, initW, initH)
            bgColor = get(0, 'DefaultUicontrolBackgroundColor');
            obj.Fig = figure('Name', ['快速编辑: ', obj.TableVar], ...
                'NumberTitle', 'off', ...
                'Position', [100 100 initW initH], ...
                'Resize', 'on', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Color', bgColor, ...
                'KeyPressFcn', @(src, event) obj.handleKeyPress(event));
            movegui(obj.Fig, 'center');

            obj.FileNameEdit = uicontrol(obj.Fig, 'Style', 'edit', 'String', obj.getPreferredFileName(), 'TooltipString', '输入要保存的文件名', 'BackgroundColor', 'white');
            obj.BtnSaveFile = uicontrol(obj.Fig, 'Style', 'pushbutton', 'String', '保存至文件', 'BackgroundColor', [0.2 0.4 0.7], 'ForegroundColor', 'white', 'FontWeight', 'bold', 'Callback', @(src, e) obj.saveToFile());

            obj.TitleLabel = uicontrol(obj.Fig, 'Style', 'text', 'String', obj.TableVar, 'FontWeight', 'bold', 'FontSize', 12, 'HorizontalAlignment', 'left', 'BackgroundColor', bgColor);

            vObj = evalin('base', obj.TableVar);
            vDesc = ''; if isprop(vObj, 'Description'), vDesc = vObj.Description; end
            obj.DescArea = uicontrol(obj.Fig, 'Style', 'edit', 'String', vDesc, 'Enable', 'inactive', 'Max', 2, 'HorizontalAlignment', 'left', 'BackgroundColor', [0.96 0.96 0.96], 'FontSize', 11);

            if ~strcmp(obj.Mode, 'Standard')
                obj.AxisXLabel = uicontrol(obj.Fig, 'Style', 'text', 'String', obj.getSingleVarInfo(obj.XVar, 'X轴'), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11, 'BackgroundColor', bgColor);
                if strcmp(obj.Mode, '2D')
                    obj.AxisYLabel = uicontrol(obj.Fig, 'Style', 'text', 'String', obj.getSingleVarInfo(obj.YVar, 'Y轴'), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11, 'BackgroundColor', bgColor);
                end
                obj.MonotonicityLabel = uicontrol(obj.Fig, 'Style', 'text', 'String', '', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11, 'ForegroundColor', 'red', 'BackgroundColor', bgColor, 'Visible', 'off');
            end

            colFmt = cell(1, numCols);
            colEditable = true(1, numCols);
            if obj.IsEnum
                startC = 1; if strcmp(obj.Mode, '2D'), startC = 2; end
                for c = startC:numCols, colFmt{c} = obj.EnumMembers; end
            end

            obj.DataTable = uitable('Parent', obj.Fig, 'Data', data, 'ColumnEditable', colEditable, 'RowName', {}, 'ColumnName', {}, 'ColumnFormat', colFmt, 'FontSize', 11, 'CellEditCallback', @(src, e) obj.onCellEdit(e), 'CellSelectionCallback', @(src, e) obj.onCellSelection(e));

            obj.BtnSave = uicontrol(obj.Fig, 'Style', 'pushbutton', 'String', '临时保存', 'BackgroundColor', [0.15 0.45 0.15], 'ForegroundColor', 'white', 'FontWeight', 'bold', 'Callback', @(src, e) obj.saveData());
            obj.BtnCancel = uicontrol(obj.Fig, 'Style', 'pushbutton', 'String', '取消', 'Callback', @(src, e) delete(obj.Fig));

            obj.BtnInterpX = [];
            obj.BtnInterpY = [];

            if ~strcmp(obj.Mode, 'Standard')
                obj.updateMonotonicityWarning();
            end

            set(obj.Fig, 'ResizeFcn', @(src, event) obj.onResize(src));
            obj.onResize(obj.Fig);
        end

        function tf = shouldUseLegacyUI(~)
            tf = verLessThan('matlab', '9.8');
        end

        function onResize(obj, varargin)
            % 手动处理布局自适应逻辑
            figHandle = obj.Fig;
            if nargin >= 2 && ~isempty(varargin{1})
                figHandle = varargin{1};
            end

            if isempty(figHandle) || ~ishandle(figHandle)
                return;
            end

            figPos = obj.getUIPosition(figHandle);
            if isempty(figPos) || numel(figPos) < 4
                return;
            end

            if isempty(obj.FileNameEdit) || isempty(obj.BtnSaveFile) || isempty(obj.TitleLabel) || isempty(obj.DescArea) || isempty(obj.DataTable) || isempty(obj.BtnSave) || isempty(obj.BtnCancel)
                return;
            end

            w = figPos(3); h = figPos(4);

            topControlY = h - 42;
            titleY = topControlY + 3;
            descY = h - 92;
            bottomButtonY = 48;
            bottomFileY = 12;

            % 1. 顶部仅保留标题和状态提示

            % 2. 单调性提示标签居中显示（避开改名框）
            if isprop(obj, 'MonotonicityLabel') && ~isempty(obj.MonotonicityLabel)
                labelWidth = max(min(w-220, 260), 120);
                labelX = max(15, floor((w - labelWidth) / 2));
                obj.setUIPosition(obj.MonotonicityLabel, [labelX topControlY labelWidth 32]);
                obj.setUIProperty(obj.MonotonicityLabel, 'HorizontalAlignment', 'center');
                obj.setUIProperty(obj.MonotonicityLabel, 'FontSize', 12);
                obj.setUIProperty(obj.MonotonicityLabel, 'FontWeight', 'bold');
            end

            % 3. 顶部标题和描述
            obj.setUIPosition(obj.TitleLabel, [15 titleY max(w-345, 140) 24]);
            obj.setUIPosition(obj.DescArea, [15 descY w-30 48]);

            yPtr = descY - 6;
            % 3. 坐标轴信息
            if ~isempty(obj.AxisXLabel)
                obj.setUIPosition(obj.AxisXLabel, [15 yPtr-22 w-30 22]);
                yPtr = yPtr - 22;
            end
            if ~isempty(obj.AxisYLabel)
                obj.setUIPosition(obj.AxisYLabel, [15 yPtr-22 w-30 22]);
                yPtr = yPtr - 22;
            end

            % 3. 表格高度自适应（占据中间所有剩余空间）
            tableBottom = 98;
            tableHeight = yPtr - tableBottom - 10;
            obj.setUIPosition(obj.DataTable, [15 tableBottom w-30 max(tableHeight, 50)]);

            % 4. 按钮固定在底部右侧，保存至文件位于临时保存下方
            obj.setUIPosition(obj.BtnSave, [w-115 bottomButtonY 100 32]);
            obj.setUIPosition(obj.BtnCancel, [w-205 bottomButtonY 80 32]);
            obj.setUIPosition(obj.FileNameEdit, [w-310 bottomFileY 145 26]);
            obj.setUIPosition(obj.BtnSaveFile, [w-155 bottomFileY 140 32]);

            if ~isempty(obj.BtnInterpX)
                obj.setUIPosition(obj.BtnInterpX, [15 12 120 32]);
            end
            if ~isempty(obj.BtnInterpY)
                obj.setUIPosition(obj.BtnInterpY, [140 12 120 32]);
            end
            % 注意：BtnPaste 相关布局代码已删除
        end

        function doInterpolate(obj, direction)
            sel = obj.getTableSelection();
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
                data = cell(length(Y)+1, length(X)+1);
                data{1, 1} = 'Y \ X';
                for j = 1:length(X)
                    data{1, j+1} = num2str(X(j));
                end
                for i = 1:length(Y)
                    data{i+1, 1} = num2str(Y(i));
                end
                for i = 1:length(Y)
                    for j = 1:length(X)
                        val = T(i, j);
                        if obj.IsEnum
                            data{i+1, j+1} = char(val);
                        else
                            data{i+1, j+1} = num2str(val);
                        end
                    end
                end
            elseif strcmp(obj.Mode, '1D')
                data = cell(2, length(X));
                for j = 1:length(X)
                    data{1, j} = num2str(X(j));
                end
                for j = 1:length(X)
                    val = T(j);
                    if obj.IsEnum
                        data{2, j} = char(val);
                    else
                        data{2, j} = num2str(val);
                    end
                end
            else
                if obj.IsEnum, data = {char(T)}; else, data = cellstr(string(T)); end
            end
        end

        function saveData(obj)
            try
                obj.applyTableDataToWorkspace();
                delete(obj.Fig); disp('[OK] 保存成功');
            catch ME
                errordlg(['保存失败: ', ME.message]);
            end
        end

        function saveDataSilent(obj)
            try
                obj.applyTableDataToWorkspace();
            catch
                % 静默模式，不显示错误
            end
        end

        function applyTableDataToWorkspace(obj)
            raw = obj.DataTable.Data;
            [R, C] = size(raw);

            % 使用基于原始变量类型的转换函数，保证写回时保留原始数值类型
            if strcmp(obj.Mode, '2D')
                % X轴：第一行，第2列开始
                newXcell = raw(1, 2:C);
                newX = obj.castToType(newXcell, obj.XVar);

                % Y轴：第一列，第2行开始
                newYcell = raw(2:R, 1);
                newY = obj.castToType(newYcell, obj.YVar);

                % 表格主体
                newT = obj.castToType(raw(2:end, 2:end), obj.TableVar);

                obj.setWValue(obj.XVar, newX);
                obj.setWValue(obj.YVar, newY);
                obj.setWValue(obj.TableVar, newT);
            elseif strcmp(obj.Mode, '1D')
                newXcell = raw(1, 1:C);
                newX = obj.castToType(newXcell, obj.XVar);

                newTcell = raw(2, 1:C);
                newT = obj.castToType(newTcell, obj.TableVar);

                obj.setWValue(obj.XVar, newX);
                obj.setWValue(obj.TableVar, newT);
            else
                obj.setWValue(obj.TableVar, obj.castToType(raw, obj.TableVar));
            end
        end

        function out = castToType(obj, cellData, varName)
            % 将表格元胞数据转换为与工作区变量相同的数据类型并返回
            if nargin < 3, varName = ''; end
            [R, C] = size(cellData);

            % 枚举特殊处理
            if obj.IsEnum
                sample = evalin('base', [obj.EnumClass, '.', cellData{1,1}]);
                out = repmat(sample, R, C);
                for i=1:R
                    for j=1:C
                        out(i,j) = evalin('base', [obj.EnumClass, '.', cellData{i,j}]);
                    end
                end
                return;
            end

            % 先解析为 double（保留 NaN 用于非数值项）
            nums = nan(R, C);
            for i = 1:R
                for j = 1:C
                    v = cellData{i,j};
                    if isempty(v)
                        nums(i,j) = NaN;
                    elseif isnumeric(v)
                        nums(i,j) = double(v);
                    else
                        try
                            s = char(v);
                            n = str2double(s);
                            if ~isnan(n)
                                nums(i,j) = n;
                            else
                                nums(i,j) = NaN;
                            end
                        catch
                            nums(i,j) = NaN;
                        end
                    end
                end
            end

            % 推断目标类型并尽量保留原始语义（支持内置/别名/NumericType）
            targetClass = '';
            try
                if ~isempty(varName) && isvarname(varName) && evalin('base', sprintf('exist(''%s'', ''var'')', varName))
                    orig = evalin('base', varName);

                    if isa(orig, 'Simulink.Parameter')
                        % 优先使用 DataType（若为内置类型）
                        if isprop(orig, 'DataType') && ~isempty(orig.DataType) && ~startsWith(orig.DataType, 'Enum:') && ~strcmpi(orig.DataType, 'auto')
                            dt = strtrim(orig.DataType);
                            dtLower = lower(dt);
                            builtinTypes = {'double','single','int8','int16','int32','int64','uint8','uint16','uint32','uint64','boolean','logical'};
                            if any(strcmp(dtLower, builtinTypes))
                                if strcmp(dtLower, 'boolean')
                                    targetClass = 'logical';
                                else
                                    targetClass = dtLower;
                                end
                            else
                                % 非内置类型（AliasType/NumericType/fixdt等），尽量使用当前 Value 的类作为目标
                                if isprop(orig, 'Value') && ~isempty(orig.Value)
                                    if islogical(orig.Value)
                                        targetClass = 'logical';
                                    else
                                        targetClass = class(orig.Value);
                                    end
                                else
                                    % 尝试使用 Simulink API 解析别名类型（若可用）
                                    aliasName = regexprep(dt, '(?i)^alias:\s*', '');
                                    aliasName = strtrim(aliasName);
                                    try
                                        if exist('Simulink.data.getDataTypeByName', 'file')
                                            dtInfo = Simulink.data.getDataTypeByName(aliasName);
                                        elseif exist('Simulink.getDataTypeByName', 'file')
                                            dtInfo = Simulink.getDataTypeByName(aliasName);
                                        else
                                            dtInfo = [];
                                        end
                                        if ~isempty(dtInfo) && isstruct(dtInfo) && isfield(dtInfo, 'DataType')
                                            dti = lower(dtInfo.DataType);
                                            if strcmp(dti, 'boolean')
                                                targetClass = 'logical';
                                            else
                                                targetClass = dti;
                                            end
                                        end
                                    catch
                                        % 忽略失败，后续会回退到 Value 或 double
                                    end
                                end
                            end

                        else
                            % 无明确 DataType，使用实际 Value 的类型
                            if isprop(orig, 'Value') && ~isempty(orig.Value)
                                if islogical(orig.Value)
                                    targetClass = 'logical';
                                else
                                    targetClass = class(orig.Value);
                                end
                            end
                        end

                    elseif isa(orig, 'Simulink.Signal')
                        % 尝试解析 InitialValue（'true'/'false'）或使用实际值
                        try
                            if isprop(orig, 'InitialValue') && ~isempty(orig.InitialValue)
                                sInit = orig.InitialValue;
                                if ischar(sInit) || isstring(sInit)
                                    sStr = strtrim(lower(char(sInit)));
                                    if strcmp(sStr, 'true') || strcmp(sStr, 'false')
                                        targetClass = 'logical';
                                    else
                                        n = str2double(sStr);
                                        if ~isnan(n)
                                            targetClass = 'double';
                                        else
                                            tmp = obj.getWValue(varName);
                                            if ~isempty(tmp), targetClass = class(tmp); end
                                        end
                                    end
                                else
                                    tmp = obj.getWValue(varName);
                                    if ~isempty(tmp), targetClass = class(tmp); end
                                end
                            end
                        catch
                        end
                    else
                        if isnumeric(orig) || islogical(orig)
                            targetClass = class(orig);
                        end
                    end
                end
            catch
                targetClass = '';
            end

            if isempty(targetClass)
                targetClass = 'double';
            end

            % 根据目标类型进行转换
            intTypes = {'int8','int16','int32','int64','uint8','uint16','uint32','uint64'};
            if any(strcmp(targetClass, intTypes))
                nums(isnan(nums)) = 0;
                rounded = round(nums);
                try
                    minv = double(intmin(targetClass));
                    maxv = double(intmax(targetClass));
                    rounded(rounded < minv) = minv;
                    rounded(rounded > maxv) = maxv;
                catch
                end
                out = cast(rounded, targetClass);
            elseif strcmp(targetClass, 'logical')
                nums(isnan(nums)) = 0;
                out = cast(nums ~= 0, 'logical');
            elseif strcmp(targetClass, 'single')
                out = cast(nums, 'single');
            else
                try
                    out = cast(nums, targetClass);
                catch
                    out = nums; % fallback to double
                end
            end
        end

        function val = getWValue(~, varName)
            if isempty(varName), val=[]; return; end
            v = evalin('base', varName);
            if isa(v, 'Simulink.Parameter')
                val = v.Value;
            elseif isa(v, 'Simulink.Signal')
                sVal = v.InitialValue;
                val = str2num(sVal);
                if isempty(val)
                    val = sVal;
                end
            else
                val = v;
            end
        end

        function setWValue(~, varName, newVal)
            v = evalin('base', varName);
            if isa(v, 'Simulink.Parameter')
                % 尝试在写回前将 newVal 转换为与原始 Parameter 类型一致的形式
                try
                    if isprop(v, 'DataType') && ~isempty(v.DataType) && ~startsWith(v.DataType, 'Enum:')
                        dt = strtrim(v.DataType);
                        dtLower = lower(dt);
                        if strcmp(dtLower, 'boolean') || strcmp(dtLower, 'logical')
                            if ~islogical(newVal)
                                newVal = logical(newVal);
                            end
                        else
                            builtins = {'double','single','int8','int16','int32','int64','uint8','uint16','uint32','uint64'};
                            if any(strcmp(dtLower, builtins))
                                try
                                    newVal = cast(double(newVal), dtLower);
                                catch
                                end
                            else
                                % AliasType / NumericType / fixdt 等，优先参考原来的 Value
                                if isprop(v, 'Value') && ~isempty(v.Value)
                                    try
                                        origVal = v.Value;
                                        if islogical(origVal)
                                            newVal = logical(newVal);
                                        elseif isa(origVal, 'embedded.fi') || isa(origVal, 'fi')
                                            try
                                                nt = numerictype(origVal);
                                                if exist('fi','file')
                                                    newVal = fi(double(newVal), nt, origVal.Fimath);
                                                end
                                            catch
                                                try
                                                    newVal = fi(double(newVal), 'Signed', origVal.Signed, 'WordLength', origVal.WordLength, 'FractionLength', origVal.FractionLength);
                                                catch
                                                end
                                            end
                                        else
                                            try
                                                newVal = cast(double(newVal), class(origVal));
                                            catch
                                            end
                                        end
                                    catch
                                    end
                                end
                            end
                        end
                    else
                        % 无 DataType 信息时，参考现有 Value 的类型
                        if isprop(v, 'Value') && ~isempty(v.Value)
                            try
                                origVal = v.Value;
                                if islogical(origVal)
                                    newVal = logical(newVal);
                                elseif isa(origVal, 'embedded.fi') || isa(origVal, 'fi')
                                    try
                                        nt = numerictype(origVal);
                                        if exist('fi','file')
                                            newVal = fi(double(newVal), nt, origVal.Fimath);
                                        end
                                    catch
                                    end
                                else
                                    try
                                        newVal = cast(double(newVal), class(origVal));
                                    catch
                                    end
                                end
                            catch
                            end
                        end
                    end
                catch
                end

                v.Value = newVal;
            elseif isa(v, 'Simulink.Signal')
                % 对于 Simulink.Signal，如果是 logical 类型，应写入 'true'/'false' 或 logical(...) 表达式，
                % 避免将其写为数字字符串导致类型信息丢失。
                if islogical(newVal)
                    if isscalar(newVal)
                        if newVal
                            v.InitialValue = 'true';
                        else
                            v.InitialValue = 'false';
                        end
                    else
                        % 数组逻辑，转换为 logical([...]) 形式
                        v.InitialValue = ['logical(' mat2str(double(newVal)) ')'];
                    end
                else
                    v.InitialValue = mat2str(newVal);
                end
            else
                v = newVal;
            end
            assignin('base', varName, v);
        end

        function str = getSingleVarInfo(~, varName, label)
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

                filename = obj.getFileNameInputValue();
                if isempty(filename)
                    errordlg('请输入文件名', '文件名为空');
                    return;
                end

                % 确保文件扩展名是.m
                if ~endsWith(filename, '.m')
                    filename = [filename, '.m'];
                end

                obj.rememberPreferredFileName(filename);

                variables = obj.collectVariablesForExport();

                % 保存到文件（采用合并方式）
                obj.writeVariablesToFile(filename, variables);

                % 自动关闭UI（不需要提示）
                delete(obj.Fig);
            catch ME
                errordlg(['保存文件失败: ', ME.message], '保存失败');
            end
        end

        function variables = collectVariablesForExport(obj)
            variables = struct();
            variables.(obj.TableVar) = obj.buildVariableEntry(obj.TableVar, obj.IsEnum);

            if strcmp(obj.Mode, 'Standard')
                return;
            end

            if ~isempty(obj.XVar)
                variables.(obj.XVar) = obj.buildVariableEntry(obj.XVar, false);
            end
            if strcmp(obj.Mode, '2D') && ~isempty(obj.YVar)
                variables.(obj.YVar) = obj.buildVariableEntry(obj.YVar, false);
            end
        end

        function filename = getPreferredFileName(~)
            prefGroup = 'SimulinkInspector';
            prefName = 'LastSaveFileName';
            defaultName = 'ManCal.m';

            if ispref(prefGroup, prefName)
                filename = getpref(prefGroup, prefName);
                if isempty(filename) || ~ischar(filename)
                    filename = defaultName;
                end
            else
                filename = defaultName;
            end
        end

        function rememberPreferredFileName(~, filename)
            if isempty(filename) || ~ischar(filename)
                return;
            end

            setpref('SimulinkInspector', 'LastSaveFileName', filename);
        end

        function entry = buildVariableEntry(obj, varName, isEnum)
            [description, dataType] = obj.getVarMetadata(varName);
            entry = struct( ...
                'value', obj.getWValue(varName), ...
                'description', description, ...
                'dataType', dataType, ...
                'isEnum', isEnum);
        end

        function [desc, dataType] = getVarMetadata(~, varName)
            desc = '';
            dataType = 'single';
            if isempty(varName)
                return;
            end

            try
                vObj = evalin('base', varName);
                if isprop(vObj, 'Description')
                    desc = vObj.Description;
                end
                if isa(vObj, 'Simulink.Parameter')
                    dataType = vObj.DataType;
                end
            catch
                desc = '';
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

            existingVars = obj.parseExistingVariableBlocks(existingContent);

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

        function existingVars = parseExistingVariableBlocks(~, existingContent)
            existingVars = struct();
            if isempty(existingContent)
                return;
            end

            lines = regexp(existingContent, '\r\n|\n|\r', 'split');
            assigninPattern = 'assignin\(''base'',\s*''([^'']+)''\s*,';

            for i = 1:length(lines)
                tokens = regexp(lines{i}, assigninPattern, 'tokens', 'once');
                if isempty(tokens)
                    continue;
                end

                varName = strtrim(tokens{1});
                if isempty(varName) || ~isvarname(varName)
                    continue;
                end

                startIdx = i;
                while startIdx > 1 && ~isempty(strtrim(lines{startIdx-1}))
                    startIdx = startIdx - 1;
                end

                blockText = strjoin(lines(startIdx:i), newline);
                existingVars.(varName) = blockText;
            end
        end

        function checkAxisMonotonicity(obj)
            % 检查坐标轴单调性并设置相应的样式
            if strcmp(obj.Mode, 'Standard')
                return;
            end

            obj.refreshAxesDisplay(obj.getAvailableAxisTypes(), false);
        end

        function applyAxisColors(obj, axisType, axisData)
            % 应用颜色到指定坐标轴 - 优化算法：每个点与后面所有值比较
            if obj.UseLegacyUI || isempty(axisData) || length(axisData) <= 1
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

        function isMonotonic = isMonotonicIncreasing(~, data)
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
                % 强制刷新表格以取消编辑状态
                obj.DataTable.Data = data;
                return;
            end

            try
                % 检查是否为批量编辑（多单元格选择）
                selectedCells = obj.getTableSelection();
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

        function applyValueToSelectedCells(obj, selectedCells, valueStr, ~, ~, ~)
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

                updatedAxes = obj.recordUpdatedAxis(row, col, updatedAxes);
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
                updatedAxes = obj.recordUpdatedAxis(row, col, updatedAxes);
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

        function updatedAxes = recordUpdatedAxis(obj, row, col, updatedAxes)
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
                obj.refreshAxesDisplay(unique(updatedAxes), false);
            end
        end

        function updateRealTimeMonotonicity(obj, row, col, ~)
            % 实时更新单调性检查、颜色和提示（不弹框）
            if strcmp(obj.Mode, 'Standard')
                return; % 标准模式不检查
            end

            % 确定编辑的是哪个坐标轴
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

            obj.refreshAxesDisplay({axisType}, false);
        end

        function updateAxisDataInWorkspace(obj, axisType)
            % 从表格数据更新工作区中的坐标轴数据
            data = obj.DataTable.Data;
            if strcmp(axisType, 'X')
                if strcmp(obj.Mode, '2D')
                    % 2D模式：X轴在第一行，第2列开始
                    xCell = data(1, 2:end);
                else
                    % 1D模式：X轴在第一行
                    xCell = data(1, :);
                end
                newData = obj.castToType(xCell, obj.XVar);
                obj.setWValue(obj.XVar, newData);
            else
                % Y轴：第一列，第2行开始
                yCell = data(2:end, 1);
                newData = obj.castToType(yCell, obj.YVar);
                obj.setWValue(obj.YVar, newData);
            end
        end

        function isMonotonic = isAxisMonotonic(obj, axisType)
            % 检查指定坐标轴是否单调递增
            axisData = obj.getAxisDataFromTable(axisType);

            if isempty(axisData) || length(axisData) <= 1
                isMonotonic = true;
                return;
            end

            isMonotonic = all(diff(axisData) > 0);
        end

        function updateMonotonicityWarning(obj)
            % 更新顶部单调性警告标签
            if strcmp(obj.Mode, 'Standard')
                return;
            end

            isAnyAxisNonMonotonic = false;
            axisTypes = obj.getAvailableAxisTypes();
            for k = 1:length(axisTypes)
                if ~obj.isAxisMonotonic(axisTypes{k})
                    isAnyAxisNonMonotonic = true;
                    break;
                end
            end

            % 动态显示/隐藏警告标签
            if isAnyAxisNonMonotonic
                obj.setMonotonicityLabelState('坐标轴未单调递增！', 'on');
            else
                obj.setMonotonicityLabelState('', 'off');
            end
        end

        function axisTypes = getAvailableAxisTypes(obj)
            axisTypes = {};
            if strcmp(obj.Mode, '2D')
                axisTypes = {'X', 'Y'};
            elseif strcmp(obj.Mode, '1D')
                axisTypes = {'X'};
            end
        end

        function refreshAxesDisplay(obj, axisTypes, syncWorkspace)
            if nargin < 3
                syncWorkspace = true;
            end

            if strcmp(obj.Mode, 'Standard') || isempty(axisTypes)
                return;
            end

            for k = 1:length(axisTypes)
                axisType = axisTypes{k};
                if syncWorkspace
                    obj.updateAxisDataInWorkspace(axisType);
                end

                axisData = obj.getAxisDataFromTable(axisType);
                obj.applyAxisColors(axisType, axisData);
            end

            obj.updateMonotonicityWarning();
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
                selectedCells = obj.getTableSelection();

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
                    obj.setTableSelection(newSelection);
                end

                % 实时更新坐标轴数据和颜色
                if ~strcmp(obj.Mode, 'Standard')
                    obj.refreshAxesDisplay(unique(updatedAxes), false);
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
            sel = obj.getTableSelection();
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

        function filename = getFileNameInputValue(obj)
            if obj.UseLegacyUI
                filename = obj.FileNameEdit.String;
            else
                filename = obj.FileNameEdit.Value;
            end
        end

        function sel = getTableSelection(obj)
            sel = [];
            if ~isempty(obj.CurrentSelection)
                sel = obj.CurrentSelection;
            end

            if obj.UseLegacyUI || isempty(obj.DataTable) || ~ishandle(obj.DataTable)
                return;
            end

            try
                liveSelection = obj.DataTable.Selection;
                if ~isempty(liveSelection)
                    sel = liveSelection;
                end
            catch
            end
        end

        function setTableSelection(obj, newSelection)
            obj.CurrentSelection = newSelection;
            if obj.UseLegacyUI || isempty(obj.DataTable) || ~ishandle(obj.DataTable)
                return;
            end

            try
                obj.DataTable.Selection = newSelection;
            catch
            end
        end

        function setMonotonicityLabelState(obj, textValue, visibleValue)
            if isempty(obj.MonotonicityLabel) || ~ishandle(obj.MonotonicityLabel)
                return;
            end

            if obj.UseLegacyUI
                obj.MonotonicityLabel.String = textValue;
                obj.MonotonicityLabel.Visible = visibleValue;
            else
                obj.MonotonicityLabel.Text = textValue;
                obj.MonotonicityLabel.Visible = visibleValue;
            end
        end

        function axisData = getAxisDataFromTable(obj, axisType)
            axisData = [];
            if isempty(obj.DataTable) || ~ishandle(obj.DataTable)
                return;
            end

            data = obj.DataTable.Data;
            if isempty(data)
                return;
            end

            if strcmp(axisType, 'X')
                if strcmp(obj.Mode, '2D')
                    if size(data, 2) <= 1
                        return;
                    end
                    axisCells = data(1, 2:end);
                else
                    axisCells = data(1, :);
                end
            else
                if ~strcmp(obj.Mode, '2D') || size(data, 1) <= 1
                    return;
                end
                axisCells = data(2:end, 1);
            end

            axisData = zeros(numel(axisCells), 1);
            for idx = 1:numel(axisCells)
                cellValue = axisCells{idx};
                if isnumeric(cellValue)
                    axisData(idx) = cellValue;
                else
                    axisData(idx) = str2double(cellValue);
                end
            end

            if strcmp(axisType, 'X')
                axisData = axisData(:)';
            end
        end

        function pos = getUIPosition(obj, handleRef)
            if obj.UseLegacyUI
                pos = get(handleRef, 'Position');
            else
                pos = handleRef.Position;
            end
        end

        function setUIPosition(obj, handleRef, pos)
            if isempty(handleRef) || ~ishandle(handleRef)
                return;
            end

            if obj.UseLegacyUI
                set(handleRef, 'Position', pos);
            else
                handleRef.Position = pos;
            end
        end

        function setUIProperty(obj, handleRef, propName, propValue)
            if isempty(handleRef) || ~ishandle(handleRef)
                return;
            end

            if obj.UseLegacyUI
                set(handleRef, propName, propValue);
            else
                handleRef.(propName) = propValue;
            end
        end
    end
end