function SignalEnumGeneratorV15()
% 信号和枚举生成工具（支持枚举、总线、自定义数值类型、信号/参数、变量定义文件）
% 支持生成加载脚本，一键恢复所有工作区对象（含描述信息）
% 优化：总线生成不再产生临时变量，工作区更干净
% 新增：可缩放UI、多文件管理、数据类型校验、加载脚本合并、单例模式
% 兼容性：优先使用 uifigure 系现代控件；缺少网格布局时回退到现代控件+像素布局

% 单例模式：关闭已有实例
persistent FIG_HANDLE
if ~isempty(FIG_HANDLE) && isvalid(FIG_HANDLE)
    delete(FIG_HANDLE);
end

% 创建主窗口
baseRowHeights = [24 26 26 26 26 30 10 24 26 26 26 26 10 24 26 26 26 26 10 24 26 26 26 26 30 36];
basePadding = 10;
baseRowSpacing = 4;
baseFigureHeight = 2 * basePadding + sum(baseRowHeights) + baseRowSpacing * (length(baseRowHeights) - 1);
legacyLayout = createLegacyLayout(baseFigureHeight);
legacyHandles = struct();
uiText = buildUIText();
hasModernControls = hasModernFigureControls();
hasModernGrid = hasModernControls && hasModernGridLayout();
if hasModernControls && ~hasModernGrid
    hasModernControls = false;
end
isLegacyUI = ~hasModernControls;
if hasModernControls
    fig = uifigure('Name', uiText.appTitle, 'Position', [300 150 980 baseFigureHeight], ...
        'NumberTitle', 'off', 'Resize', 'on');
    if ~hasModernGrid && isprop(fig, 'AutoResizeChildren')
        fig.AutoResizeChildren = 'off';
    end
else
    fig = figure('Name', uiText.appTitle, 'Position', [300 150 980 baseFigureHeight], ...
        'NumberTitle', 'off', 'Resize', 'on', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Color', get(0, 'DefaultUicontrolBackgroundColor'));
end
setFigureClientSize([980, baseFigureHeight]);
FIG_HANDLE = fig;

if hasModernGrid
    mainGrid = uigridlayout(fig, [26, 3], ...
        'RowHeight', num2cell(baseRowHeights), ...
        'ColumnWidth', {180, '1x', 110}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 4, 'ColumnSpacing', 6);

    lblEnum = uilabel(mainGrid, 'Text', uiText.enumLabel, 'FontWeight', 'bold', ...
        'Tooltip', uiText.enumLabelTooltip);
    lblEnum.Layout.Row = 1; lblEnum.Layout.Column = 1;
    lblEnumDesc = uilabel(mainGrid, 'Text', uiText.enumDesc, 'FontColor', [0.45 0.45 0.45]);
    lblEnumDesc.Layout.Row = 1; lblEnumDesc.Layout.Column = 2;

    enumListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', uiText.enumListTooltip);
    enumListBox.Layout.Row = [2, 5];
    enumListBox.Layout.Column = 2;

    btnAddEnumFile = uibutton(mainGrid, 'Text', uiText.addFile, ...
        'ButtonPushedFcn', @(src,event) addFiles('enum'));
    btnAddEnumFile.Layout.Row = 2; btnAddEnumFile.Layout.Column = 3;
    btnAddEnumFolder = uibutton(mainGrid, 'Text', uiText.addFolder, ...
        'ButtonPushedFcn', @(src,event) addFolder('enum'));
    btnAddEnumFolder.Layout.Row = 3; btnAddEnumFolder.Layout.Column = 3;
    btnDelEnum = uibutton(mainGrid, 'Text', uiText.deleteSelected, ...
        'ButtonPushedFcn', @(src,event) deleteSelected('enum'));
    btnDelEnum.Layout.Row = 4; btnDelEnum.Layout.Column = 3;
    btnClearEnum = uibutton(mainGrid, 'Text', uiText.clearAll, ...
        'ButtonPushedFcn', @(src,event) clearAll('enum'));
    btnClearEnum.Layout.Row = 5; btnClearEnum.Layout.Column = 3;

    lblTargetPath = uilabel(mainGrid, 'Text', uiText.enumTargetPathLabel, 'FontWeight', 'bold');
    lblTargetPath.Layout.Row = 6; lblTargetPath.Layout.Column = 1;
    enumTargetPathEdit = uieditfield(mainGrid, 'text', 'Value', '');
    enumTargetPathEdit.Layout.Row = 6; enumTargetPathEdit.Layout.Column = 2;
    btnBrowsePath = uibutton(mainGrid, 'Text', uiText.browse, ...
        'ButtonPushedFcn', @(src,event) selectEnumTargetFolder());
    btnBrowsePath.Layout.Row = 6; btnBrowsePath.Layout.Column = 3;

    lblIntf = uilabel(mainGrid, 'Text', uiText.interfaceLabel, 'FontWeight', 'bold');
    lblIntf.Layout.Row = 8; lblIntf.Layout.Column = 1;
    lblIntfDesc = uilabel(mainGrid, 'Text', uiText.interfaceDesc, 'FontColor', [0.45 0.45 0.45]);
    lblIntfDesc.Layout.Row = 8; lblIntfDesc.Layout.Column = 2;

    interfaceListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', uiText.interfaceListTooltip);
    interfaceListBox.Layout.Row = [9, 12];
    interfaceListBox.Layout.Column = 2;

    btnAddIntf = uibutton(mainGrid, 'Text', uiText.addFile, ...
        'ButtonPushedFcn', @(src,event) addFiles('interface'));
    btnAddIntf.Layout.Row = 9; btnAddIntf.Layout.Column = 3;
    btnAddIntfFolder = uibutton(mainGrid, 'Text', uiText.addFolder, ...
        'ButtonPushedFcn', @(src,event) addFolder('interface'));
    btnAddIntfFolder.Layout.Row = 10; btnAddIntfFolder.Layout.Column = 3;
    btnDelIntf = uibutton(mainGrid, 'Text', uiText.deleteSelected, ...
        'ButtonPushedFcn', @(src,event) deleteSelected('interface'));
    btnDelIntf.Layout.Row = 11; btnDelIntf.Layout.Column = 3;
    btnClearIntf = uibutton(mainGrid, 'Text', uiText.clearAll, ...
        'ButtonPushedFcn', @(src,event) clearAll('interface'));
    btnClearIntf.Layout.Row = 12; btnClearIntf.Layout.Column = 3;

    lblVar = uilabel(mainGrid, 'Text', uiText.varLabel, 'FontWeight', 'bold');
    lblVar.Layout.Row = 14; lblVar.Layout.Column = 1;
    lblVarDesc = uilabel(mainGrid, 'Text', uiText.varDesc, 'FontColor', [0.45 0.45 0.45]);
    lblVarDesc.Layout.Row = 14; lblVarDesc.Layout.Column = 2;

    varListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', uiText.varListTooltip);
    varListBox.Layout.Row = [15, 18];
    varListBox.Layout.Column = 2;

    btnAddVar = uibutton(mainGrid, 'Text', uiText.addFile, ...
        'ButtonPushedFcn', @(src,event) addFiles('var'));
    btnAddVar.Layout.Row = 15; btnAddVar.Layout.Column = 3;
    btnAddVarFolder = uibutton(mainGrid, 'Text', uiText.addFolder, ...
        'ButtonPushedFcn', @(src,event) addFolder('var'));
    btnAddVarFolder.Layout.Row = 16; btnAddVarFolder.Layout.Column = 3;
    btnDelVar = uibutton(mainGrid, 'Text', uiText.deleteSelected, ...
        'ButtonPushedFcn', @(src,event) deleteSelected('var'));
    btnDelVar.Layout.Row = 17; btnDelVar.Layout.Column = 3;
    btnClearVar = uibutton(mainGrid, 'Text', uiText.clearAll, ...
        'ButtonPushedFcn', @(src,event) clearAll('var'));
    btnClearVar.Layout.Row = 18; btnClearVar.Layout.Column = 3;

    lblOtherM = uilabel(mainGrid, 'Text', uiText.otherScriptLabel, 'FontWeight', 'bold');
    lblOtherM.Layout.Row = 20; lblOtherM.Layout.Column = 1;
    lblOtherMDesc = uilabel(mainGrid, 'Text', uiText.otherScriptDesc, 'FontColor', [0.45 0.45 0.45]);
    lblOtherMDesc.Layout.Row = 20; lblOtherMDesc.Layout.Column = 2;

    otherMListBox = uilistbox(mainGrid, 'Items', {}, 'Multiselect', 'on', ...
        'Tooltip', uiText.otherScriptTooltip);
    otherMListBox.Layout.Row = [21, 24];
    otherMListBox.Layout.Column = 2;

    btnAddOtherM = uibutton(mainGrid, 'Text', uiText.addFile, ...
        'ButtonPushedFcn', @(src,event) addFiles('script'));
    btnAddOtherM.Layout.Row = 21; btnAddOtherM.Layout.Column = 3;
    btnAddOtherMFolder = uibutton(mainGrid, 'Text', uiText.addFolder, ...
        'ButtonPushedFcn', @(src,event) addFolder('script'));
    btnAddOtherMFolder.Layout.Row = 22; btnAddOtherMFolder.Layout.Column = 3;
    btnDelOtherM = uibutton(mainGrid, 'Text', uiText.deleteSelected, ...
        'ButtonPushedFcn', @(src,event) deleteSelected('script'));
    btnDelOtherM.Layout.Row = 23; btnDelOtherM.Layout.Column = 3;
    btnClearOtherM = uibutton(mainGrid, 'Text', uiText.clearAll, ...
        'ButtonPushedFcn', @(src,event) clearAll('script'));
    btnClearOtherM.Layout.Row = 24; btnClearOtherM.Layout.Column = 3;

    lblScript = uilabel(mainGrid, 'Text', uiText.scriptNameLabel, 'FontWeight', 'bold');
    lblScript.Layout.Row = 25; lblScript.Layout.Column = 1;
    scriptNameEdit = uieditfield(mainGrid, 'text', 'Value', 'LoadWorkspaceData.m');
    scriptNameEdit.Layout.Row = 25; scriptNameEdit.Layout.Column = [2,3];

    btnPanel = uigridlayout(mainGrid, [1,2], 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 8);
    btnPanel.Layout.Row = 26; btnPanel.Layout.Column = [1,3];
    btnGenerate = uibutton(btnPanel, 'Text', uiText.generate, 'BackgroundColor', [0.3 0.7 0.3], ...
        'FontColor','w','FontWeight','bold','FontSize',12, ...
        'ButtonPushedFcn', @(src,event) generate());
    btnGenerate.Layout.Row = 1; btnGenerate.Layout.Column = 1;
    btnExit = uibutton(btnPanel, 'Text', uiText.exit, 'BackgroundColor', [0.8 0.3 0.3], ...
        'FontColor','w','FontWeight','bold','FontSize',12, ...
        'ButtonPushedFcn', @(src,event) delete(fig));
    btnExit.Layout.Row = 1; btnExit.Layout.Column = 2;

else
    if isLegacyUI
        set(fig, 'Color', legacyLayout.figureColor);

        legacyHandles.lblEnum = uicontrol(fig, 'Style', 'text', 'String', uiText.enumLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        legacyHandles.lblEnumDesc = uicontrol(fig, 'Style', 'text', 'String', uiText.enumDesc, ...
            'HorizontalAlignment', 'left', 'ForegroundColor', legacyLayout.descColor, 'BackgroundColor', legacyLayout.figureColor);
        enumListBox = uicontrol(fig, 'Style', 'listbox', 'String', {}, 'Max', 2, 'Min', 0, ...
            'BackgroundColor', legacyLayout.fieldColor, 'HorizontalAlignment', 'left');
        legacyHandles.enumButtons(1) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFile, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFiles('enum'));
        legacyHandles.enumButtons(2) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFolder, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFolder('enum'));
        legacyHandles.enumButtons(3) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.deleteSelected, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) deleteSelected('enum'));
        legacyHandles.enumButtons(4) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.clearAll, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) clearAll('enum'));

        legacyHandles.lblTargetPath = uicontrol(fig, 'Style', 'text', 'String', uiText.enumTargetPathLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        enumTargetPathEdit = uicontrol(fig, 'Style', 'edit', 'String', '', 'HorizontalAlignment', 'left', ...
            'BackgroundColor', legacyLayout.fieldColor);
        legacyHandles.btnBrowsePath = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.browse, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) selectEnumTargetFolder());

        legacyHandles.lblIntf = uicontrol(fig, 'Style', 'text', 'String', uiText.interfaceLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        legacyHandles.lblIntfDesc = uicontrol(fig, 'Style', 'text', 'String', uiText.interfaceDesc, ...
            'HorizontalAlignment', 'left', 'ForegroundColor', legacyLayout.descColor, 'BackgroundColor', legacyLayout.figureColor);
        interfaceListBox = uicontrol(fig, 'Style', 'listbox', 'String', {}, 'Max', 2, 'Min', 0, ...
            'BackgroundColor', legacyLayout.fieldColor, 'HorizontalAlignment', 'left');
        legacyHandles.intfButtons(1) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFile, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFiles('interface'));
        legacyHandles.intfButtons(2) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFolder, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFolder('interface'));
        legacyHandles.intfButtons(3) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.deleteSelected, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) deleteSelected('interface'));
        legacyHandles.intfButtons(4) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.clearAll, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) clearAll('interface'));

        legacyHandles.lblVar = uicontrol(fig, 'Style', 'text', 'String', uiText.varLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        legacyHandles.lblVarDesc = uicontrol(fig, 'Style', 'text', 'String', uiText.varDesc, ...
            'HorizontalAlignment', 'left', 'ForegroundColor', legacyLayout.descColor, 'BackgroundColor', legacyLayout.figureColor);
        varListBox = uicontrol(fig, 'Style', 'listbox', 'String', {}, 'Max', 2, 'Min', 0, ...
            'BackgroundColor', legacyLayout.fieldColor, 'HorizontalAlignment', 'left');
        legacyHandles.varButtons(1) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFile, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFiles('var'));
        legacyHandles.varButtons(2) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFolder, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFolder('var'));
        legacyHandles.varButtons(3) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.deleteSelected, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) deleteSelected('var'));
        legacyHandles.varButtons(4) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.clearAll, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) clearAll('var'));

        legacyHandles.lblOtherM = uicontrol(fig, 'Style', 'text', 'String', uiText.otherScriptLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        legacyHandles.lblOtherMDesc = uicontrol(fig, 'Style', 'text', 'String', uiText.otherScriptDesc, ...
            'HorizontalAlignment', 'left', 'ForegroundColor', legacyLayout.descColor, 'BackgroundColor', legacyLayout.figureColor);
        otherMListBox = uicontrol(fig, 'Style', 'listbox', 'String', {}, 'Max', 2, 'Min', 0, ...
            'BackgroundColor', legacyLayout.fieldColor, 'HorizontalAlignment', 'left');
        legacyHandles.otherButtons(1) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFile, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFiles('script'));
        legacyHandles.otherButtons(2) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.addFolder, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) addFolder('script'));
        legacyHandles.otherButtons(3) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.deleteSelected, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) deleteSelected('script'));
        legacyHandles.otherButtons(4) = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.clearAll, ...
            'FontWeight', 'normal', 'BackgroundColor', legacyLayout.buttonColor, 'ForegroundColor', legacyLayout.buttonTextColor, ...
            'Callback', @(src,event) clearAll('script'));

        legacyHandles.lblScript = uicontrol(fig, 'Style', 'text', 'String', uiText.scriptNameLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.figureColor);
        scriptNameEdit = uicontrol(fig, 'Style', 'edit', 'String', 'LoadWorkspaceData.m', ...
            'HorizontalAlignment', 'left', 'BackgroundColor', legacyLayout.fieldColor);

        legacyHandles.btnGenerate = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.generate, ...
            'BackgroundColor', [0.3 0.7 0.3], 'ForegroundColor', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
            'Callback', @(src,event) generate());
        legacyHandles.btnExit = uicontrol(fig, 'Style', 'pushbutton', 'String', uiText.exit, ...
            'BackgroundColor', [0.8 0.3 0.3], 'ForegroundColor', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
            'Callback', @(src,event) delete(fig));

        set(fig, 'ResizeFcn', @(src,event) relayoutLegacyUI());
    else
        fig.Color = legacyLayout.figureColor;

        legacyHandles.lblEnum = uilabel(fig, 'Text', uiText.enumLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        legacyHandles.lblEnumDesc = uilabel(fig, 'Text', uiText.enumDesc, ...
            'HorizontalAlignment', 'left', 'FontColor', legacyLayout.descColor);
        enumListBox = uilistbox(fig, 'Items', {}, 'Multiselect', 'on');
        legacyHandles.enumButtons(1) = uibutton(fig, 'Text', uiText.addFile, ...
            'ButtonPushedFcn', @(src,event) addFiles('enum'));
        legacyHandles.enumButtons(2) = uibutton(fig, 'Text', uiText.addFolder, ...
            'ButtonPushedFcn', @(src,event) addFolder('enum'));
        legacyHandles.enumButtons(3) = uibutton(fig, 'Text', uiText.deleteSelected, ...
            'ButtonPushedFcn', @(src,event) deleteSelected('enum'));
        legacyHandles.enumButtons(4) = uibutton(fig, 'Text', uiText.clearAll, ...
            'ButtonPushedFcn', @(src,event) clearAll('enum'));

        legacyHandles.lblTargetPath = uilabel(fig, 'Text', uiText.enumTargetPathLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        enumTargetPathEdit = uieditfield(fig, 'text', 'Value', '');
        legacyHandles.btnBrowsePath = uibutton(fig, 'Text', uiText.browse, ...
            'ButtonPushedFcn', @(src,event) selectEnumTargetFolder());

        legacyHandles.lblIntf = uilabel(fig, 'Text', uiText.interfaceLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        legacyHandles.lblIntfDesc = uilabel(fig, 'Text', uiText.interfaceDesc, ...
            'HorizontalAlignment', 'left', 'FontColor', legacyLayout.descColor);
        interfaceListBox = uilistbox(fig, 'Items', {}, 'Multiselect', 'on');
        legacyHandles.intfButtons(1) = uibutton(fig, 'Text', uiText.addFile, ...
            'ButtonPushedFcn', @(src,event) addFiles('interface'));
        legacyHandles.intfButtons(2) = uibutton(fig, 'Text', uiText.addFolder, ...
            'ButtonPushedFcn', @(src,event) addFolder('interface'));
        legacyHandles.intfButtons(3) = uibutton(fig, 'Text', uiText.deleteSelected, ...
            'ButtonPushedFcn', @(src,event) deleteSelected('interface'));
        legacyHandles.intfButtons(4) = uibutton(fig, 'Text', uiText.clearAll, ...
            'ButtonPushedFcn', @(src,event) clearAll('interface'));

        legacyHandles.lblVar = uilabel(fig, 'Text', uiText.varLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        legacyHandles.lblVarDesc = uilabel(fig, 'Text', uiText.varDesc, ...
            'HorizontalAlignment', 'left', 'FontColor', legacyLayout.descColor);
        varListBox = uilistbox(fig, 'Items', {}, 'Multiselect', 'on');
        legacyHandles.varButtons(1) = uibutton(fig, 'Text', uiText.addFile, ...
            'ButtonPushedFcn', @(src,event) addFiles('var'));
        legacyHandles.varButtons(2) = uibutton(fig, 'Text', uiText.addFolder, ...
            'ButtonPushedFcn', @(src,event) addFolder('var'));
        legacyHandles.varButtons(3) = uibutton(fig, 'Text', uiText.deleteSelected, ...
            'ButtonPushedFcn', @(src,event) deleteSelected('var'));
        legacyHandles.varButtons(4) = uibutton(fig, 'Text', uiText.clearAll, ...
            'ButtonPushedFcn', @(src,event) clearAll('var'));

        legacyHandles.lblOtherM = uilabel(fig, 'Text', uiText.otherScriptLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        legacyHandles.lblOtherMDesc = uilabel(fig, 'Text', uiText.otherScriptDesc, ...
            'HorizontalAlignment', 'left', 'FontColor', legacyLayout.descColor);
        otherMListBox = uilistbox(fig, 'Items', {}, 'Multiselect', 'on');
        legacyHandles.otherButtons(1) = uibutton(fig, 'Text', uiText.addFile, ...
            'ButtonPushedFcn', @(src,event) addFiles('script'));
        legacyHandles.otherButtons(2) = uibutton(fig, 'Text', uiText.addFolder, ...
            'ButtonPushedFcn', @(src,event) addFolder('script'));
        legacyHandles.otherButtons(3) = uibutton(fig, 'Text', uiText.deleteSelected, ...
            'ButtonPushedFcn', @(src,event) deleteSelected('script'));
        legacyHandles.otherButtons(4) = uibutton(fig, 'Text', uiText.clearAll, ...
            'ButtonPushedFcn', @(src,event) clearAll('script'));

        legacyHandles.lblScript = uilabel(fig, 'Text', uiText.scriptNameLabel, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left');
        scriptNameEdit = uieditfield(fig, 'text', 'Value', 'LoadWorkspaceData.m');

        legacyHandles.btnGenerate = uibutton(fig, 'Text', uiText.generate, ...
            'BackgroundColor', [0.3 0.7 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
            'ButtonPushedFcn', @(src,event) generate());
        legacyHandles.btnExit = uibutton(fig, 'Text', uiText.exit, ...
            'BackgroundColor', [0.8 0.3 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
            'ButtonPushedFcn', @(src,event) delete(fig));

        if isprop(fig, 'AutoResizeChildren')
            fig.AutoResizeChildren = 'off';
        end
        fig.SizeChangedFcn = @(src,event) relayoutLegacyUI();
    end

    relayoutLegacyUI();
    if isLegacyUI
        drawnow;
        rmappdata(fig, 'LegacyLastFigureSize');
        relayoutLegacyUI();
    end
end

% 存储数据
appData = struct();
appData.enumFiles = {};
appData.targetPath = '';
appData.interfaceFiles = {};
appData.varFiles = {};
appData.otherMFiles = {};
appData.enumListBox = enumListBox;
appData.interfaceListBox = interfaceListBox;
appData.varListBox = varListBox;
appData.otherMListBox = otherMListBox;
set(fig, 'UserData', appData);

    function tf = hasModernFigureControls()
        tf = exist('uifigure', 'file') == 2 && ...
            exist('uilabel', 'file') == 2 && ...
            exist('uilistbox', 'file') == 2 && ...
            exist('uibutton', 'file') == 2 && ...
            exist('uieditfield', 'file') == 2;
    end

    function tf = hasModernGridLayout()
        tf = exist('uigridlayout', 'file') == 2;
    end

    function layout = createLegacyLayout(figureHeight)
        layout = struct();
        layout.baseFigureSize = [980, figureHeight];
        layout.padding = 10;
        layout.rowSpacing = 4;
        layout.columnSpacing = 6;
        layout.baseRowHeights = baseRowHeights;
        layout.baseColumnWidths = [180 658 110];
        layout.figureColor = [0.94 0.94 0.94];
        layout.fieldColor = [1 1 1];
        layout.descColor = [0.45 0.45 0.45];
        layout.buttonColor = [0.97 0.97 0.97];
        layout.buttonTextColor = [0.15 0.15 0.15];
        layout.compatFrameInsets = [16 39];
    end

    function texts = buildUIText()
        mk = @(codes) char(uint16(codes));
        texts = struct();
        texts.appTitle = mk([27169 22411 23450 20041 21019 24314 24037 20855]);
        texts.enumLabel = mk([26522 20030 23450 20041 25991 20214 21015 34920 58]);
        texts.enumDesc = mk([23450 20041 26522 20030 12289 66 85 83 12289 21333 20301]);
        texts.addFile = mk([28155 21152 25991 20214 46 46 46]);
        texts.addFolder = mk([28155 21152 25991 20214 22841 46 46 46]);
        texts.deleteSelected = mk([21024 38500 36873 20013]);
        texts.clearAll = mk([28165 31354 20840 37096]);
        texts.enumTargetPathLabel = mk([26522 20030 25991 20214 23384 25918 36335 24452 58]);
        texts.browse = mk([27983 35272 46 46 46]);
        texts.interfaceLabel = mk([73 110 116 101 114 102 97 99 101 25991 20214 21015 34920 58]);
        texts.interfaceDesc = mk([23450 20041 35266 27979 37327 12289 26631 23450 37327]);
        texts.varLabel = mk([20854 20182 21464 37327 23450 20041 25991 20214 21015 34920 58]);
        texts.varDesc = mk([20165 23450 20041 26631 23450 37327]);
        texts.otherScriptLabel = mk([20854 20182 32 46 109 32 25991 20214 58]);
        texts.otherScriptDesc = mk([21487 21512 24182 20854 20182 33050 26412 20869 23481]);
        texts.scriptNameLabel = mk([21152 36733 33050 26412 25991 20214 21517 58]);
        texts.generate = mk([29983 25104]);
        texts.exit = mk([36864 20986]);
        texts.enumLabelTooltip = mk([25903 25345 22810 20010 32 69 120 99 101 108 32 25991 20214 65292 25353 39034 24207 21512 24182 65292 37325 22797 23450 20041 20197 26368 21518 20026 20934]);
        texts.enumListTooltip = mk([24050 36873 25321 30340 26522 20030 23450 20041 25991 20214 65288 23436 25972 36335 24452 65289]);
        texts.interfaceListTooltip = mk([24050 36873 25321 30340 32 73 110 116 101 114 102 97 99 101 32 25991 20214 65288 23436 25972 36335 24452 65289]);
        texts.varListTooltip = mk([24050 36873 25321 30340 20854 20182 21464 37327 23450 20041 25991 20214 65288 23436 25972 36335 24452 65289]);
        texts.otherScriptTooltip = mk([36825 20123 33050 26412 20869 23481 20250 36861 21152 21040 29983 25104 33050 26412 30340 26411 23614]);
        texts.promptTitle = mk([25552 31034]);
        texts.errorTitle = mk([38169 35823]);
        texts.warningTitle = mk([35686 21578]);
        texts.doneTitle = mk([23436 25104]);
        texts.selectEnumTargetFolder = mk([36873 25321 26522 20030 31867 29983 25104 30446 26631 36335 24452]);
        texts.selectEnumFiles = mk([36873 25321 19968 20010 25110 22810 20010 26522 20030 32 69 120 99 101 108 32 25991 20214]);
        texts.selectInterfaceFiles = mk([36873 25321 19968 20010 25110 22810 20010 32 73 110 116 101 114 102 97 99 101 32 69 120 99 101 108 32 25991 20214]);
        texts.selectVarFiles = mk([36873 25321 19968 20010 25110 22810 20010 21464 37327 23450 20041 32 69 120 99 101 108 32 25991 20214]);
        texts.selectScriptFiles = mk([36873 25321 19968 20010 25110 22810 20010 33050 26412 25991 20214]);
        texts.selectEnumFolder = mk([36873 25321 21253 21547 26522 20030 32 69 120 99 101 108 32 25991 20214 30340 26681 25991 20214 22841]);
        texts.selectInterfaceFolder = mk([36873 25321 21253 21547 32 73 110 116 101 114 102 97 99 101 32 69 120 99 101 108 32 25991 20214 30340 26681 25991 20214 22841]);
        texts.selectVarFolder = mk([36873 25321 21253 21547 21464 37327 23450 20041 32 69 120 99 101 108 32 25991 20214 30340 26681 25991 20214 22841]);
        texts.selectScriptFolder = mk([36873 25321 21253 21547 33050 26412 25991 20214 30340 26681 25991 20214 22841]);
    end

    function relayoutLegacyUI()
        if hasModernGrid || isempty(fieldnames(legacyHandles)) || ~isvalid(fig)
            return;
        end

        metrics = getLegacyMetrics();
        currentFigureSize = [metrics.figureWidth, metrics.figureHeight];
        lastFigureSize = getappdata(fig, 'LegacyLastFigureSize');
        if isequal(lastFigureSize, currentFigureSize)
            return;
        end
        setappdata(fig, 'LegacyLastFigureSize', currentFigureSize);

        setLegacyControl(legacyHandles.lblEnum, legacyGridRect(metrics, 1, 1, 1, 1), 11, 'bold');
        setLegacyControl(legacyHandles.lblEnumDesc, legacyGridRect(metrics, 1, 1, 2, 2), 9, 'normal');
        setLegacyControl(enumListBox, legacyGridRect(metrics, 2, 5, 2, 2), 10, 'normal');
        layoutButtonColumn(legacyHandles.enumButtons, metrics, 2, 'normal');

        setLegacyControl(legacyHandles.lblTargetPath, legacyGridRect(metrics, 6, 6, 1, 1), 11, 'bold');
        setLegacyControl(enumTargetPathEdit, legacyGridRect(metrics, 6, 6, 2, 2), 10, 'normal');
        setLegacyControl(legacyHandles.btnBrowsePath, legacyGridRect(metrics, 6, 6, 3, 3), 10, 'normal');

        setLegacyControl(legacyHandles.lblIntf, legacyGridRect(metrics, 8, 8, 1, 1), 11, 'bold');
        setLegacyControl(legacyHandles.lblIntfDesc, legacyGridRect(metrics, 8, 8, 2, 2), 9, 'normal');
        setLegacyControl(interfaceListBox, legacyGridRect(metrics, 9, 12, 2, 2), 10, 'normal');
        layoutButtonColumn(legacyHandles.intfButtons, metrics, 9, 'normal');

        setLegacyControl(legacyHandles.lblVar, legacyGridRect(metrics, 14, 14, 1, 1), 11, 'bold');
        setLegacyControl(legacyHandles.lblVarDesc, legacyGridRect(metrics, 14, 14, 2, 2), 9, 'normal');
        setLegacyControl(varListBox, legacyGridRect(metrics, 15, 18, 2, 2), 10, 'normal');
        layoutButtonColumn(legacyHandles.varButtons, metrics, 15, 'normal');

        setLegacyControl(legacyHandles.lblOtherM, legacyGridRect(metrics, 20, 20, 1, 1), 11, 'bold');
        setLegacyControl(legacyHandles.lblOtherMDesc, legacyGridRect(metrics, 20, 20, 2, 2), 9, 'normal');
        setLegacyControl(otherMListBox, legacyGridRect(metrics, 21, 24, 2, 2), 10, 'normal');
        layoutButtonColumn(legacyHandles.otherButtons, metrics, 21, 'normal');

        setLegacyControl(legacyHandles.lblScript, legacyGridRect(metrics, 25, 25, 1, 1), 11, 'bold');
        setLegacyControl(scriptNameEdit, legacyGridRect(metrics, 25, 25, 2, 3), 10, 'normal');

        buttonPanelRect = legacyGridRect(metrics, 26, 26, 1, 3);
        buttonGap = metrics.columnSpacing + 2;
        buttonWidth = floor((buttonPanelRect(3) - buttonGap) / 2);
        setLegacyControl(legacyHandles.btnGenerate, [buttonPanelRect(1), buttonPanelRect(2), buttonWidth, buttonPanelRect(4)], 11, 'bold');
        setLegacyControl(legacyHandles.btnExit, [buttonPanelRect(1) + buttonWidth + buttonGap, buttonPanelRect(2), buttonWidth, buttonPanelRect(4)], 11, 'bold');
    end

    function metrics = getLegacyMetrics()
        figPos = getFigureClientPosition();
        metrics.figureWidth = figPos(3);
        metrics.figureHeight = figPos(4);

        baseHeight = 2 * legacyLayout.padding + sum(legacyLayout.baseRowHeights) + legacyLayout.rowSpacing * (length(legacyLayout.baseRowHeights) - 1);
        metrics.paddingX = legacyLayout.padding;
        metrics.paddingY = legacyLayout.padding;
        metrics.columnSpacing = legacyLayout.columnSpacing;
        metrics.rowSpacing = legacyLayout.rowSpacing;

        minMiddleColumnWidth = 260;
        fixedSideColumnsWidth = legacyLayout.baseColumnWidths(1) + legacyLayout.baseColumnWidths(3);
        availableMiddleWidth = metrics.figureWidth - 2 * metrics.paddingX - 2 * metrics.columnSpacing - fixedSideColumnsWidth;
        metrics.columnWidths = [legacyLayout.baseColumnWidths(1), max(minMiddleColumnWidth, availableMiddleWidth), legacyLayout.baseColumnWidths(3)];

        metrics.rowHeights = legacyLayout.baseRowHeights;
        flexibleRows = [2:5, 9:12, 15:18, 21:24];
        extraHeight = metrics.figureHeight - baseHeight;
        if extraHeight ~= 0
            rowDelta = floor(extraHeight / numel(flexibleRows));
            remainder = extraHeight - rowDelta * numel(flexibleRows);
            metrics.rowHeights(flexibleRows) = max(18, metrics.rowHeights(flexibleRows) + rowDelta);

            if remainder ~= 0
                rowStep = sign(remainder);
                remainder = abs(remainder);
                for rowIdx = 1:numel(flexibleRows)
                    if remainder == 0
                        break;
                    end
                    targetRow = flexibleRows(rowIdx);
                    if rowStep > 0 || metrics.rowHeights(targetRow) > 18
                        metrics.rowHeights(targetRow) = metrics.rowHeights(targetRow) + rowStep;
                        remainder = remainder - 1;
                    end
                end
            end
        end
    end

    function rect = legacyGridRect(metrics, rowStart, rowEnd, colStart, colEnd)
        x = metrics.paddingX;
        for colIdx = 1:(colStart - 1)
            x = x + metrics.columnWidths(colIdx) + metrics.columnSpacing;
        end

        width = sum(metrics.columnWidths(colStart:colEnd)) + metrics.columnSpacing * (colEnd - colStart);
        usedHeight = metrics.paddingY;
        for rowIdx = 1:rowEnd
            usedHeight = usedHeight + metrics.rowHeights(rowIdx);
            if rowIdx < rowEnd
                usedHeight = usedHeight + metrics.rowSpacing;
            end
        end
        height = sum(metrics.rowHeights(rowStart:rowEnd)) + metrics.rowSpacing * (rowEnd - rowStart);
        y = metrics.figureHeight - usedHeight;
        rect = [x, y, width, height];
    end

    function layoutButtonColumn(buttonHandles, metrics, startRow, fontWeight)
        if nargin < 4
            fontWeight = 'normal';
        end
        for btnIdx = 1:length(buttonHandles)
            setLegacyControl(buttonHandles(btnIdx), legacyGridRect(metrics, startRow + btnIdx - 1, startRow + btnIdx - 1, 3, 3), 10, fontWeight);
        end
    end

    function setFigureClientSize(contentSize)
        drawnow;
        if isprop(fig, 'InnerPosition')
            outerPos = fig.Position;
            innerPos = fig.InnerPosition;
            chromeWidth = max(0, outerPos(3) - innerPos(3));
            chromeHeight = max(0, outerPos(4) - innerPos(4));
            fig.Position = [outerPos(1), outerPos(2), contentSize(1) + chromeWidth, contentSize(2) + chromeHeight];
        elseif isLegacyUI
            outerPos = get(fig, 'Position');
            set(fig, 'Position', [outerPos(1), outerPos(2), ...
                contentSize(1) + legacyLayout.compatFrameInsets(1), ...
                contentSize(2) + legacyLayout.compatFrameInsets(2)]);
        elseif ~isLegacyUI && ~hasModernGrid
            outerPos = fig.Position;
            fig.Position = [outerPos(1), outerPos(2), ...
                contentSize(1) + legacyLayout.compatFrameInsets(1), ...
                contentSize(2) + legacyLayout.compatFrameInsets(2)];
        end
    end

    function figPos = getFigureClientPosition()
        if isprop(fig, 'InnerPosition')
            figPos = fig.InnerPosition;
        elseif ~isLegacyUI && ~hasModernGrid
            outerPos = fig.Position;
            figPos = [1, 1, ...
                max(1, outerPos(3) - legacyLayout.compatFrameInsets(1)), ...
                max(1, outerPos(4) - legacyLayout.compatFrameInsets(2))];
        elseif isLegacyUI
            figPos = getpixelposition(fig);
        else
            figPos = fig.Position;
        end
    end

    function setLegacyControl(handleObj, rect, fontSize, fontWeight)
        if isempty(handleObj) || ~isvalid(handleObj)
            return;
        end
        layoutCache = getappdata(handleObj, 'LegacyLayoutCache');
        needsPositionUpdate = isempty(layoutCache) || ~isequal(layoutCache.Position, rect);
        needsFontSizeUpdate = isempty(layoutCache) || layoutCache.FontSize ~= fontSize;
        needsFontWeightUpdate = isempty(layoutCache) || ~strcmp(layoutCache.FontWeight, fontWeight);
        if isLegacyUI
            props = {};
            if isempty(layoutCache)
                props = [props, {'Units', 'pixels'}];
            end
            if needsPositionUpdate
                props = [props, {'Position', rect}];
            end
            if needsFontSizeUpdate
                props = [props, {'FontSize', fontSize}];
            end
            if needsFontWeightUpdate
                props = [props, {'FontWeight', fontWeight}];
            end
            if ~isempty(props)
                set(handleObj, props{:});
            end
        else
            if needsPositionUpdate
                handleObj.Position = rect;
            end
            if needsFontSizeUpdate
                handleObj.FontSize = fontSize;
            end
            if needsFontWeightUpdate
                handleObj.FontWeight = fontWeight;
            end
        end
        if needsPositionUpdate || needsFontSizeUpdate || needsFontWeightUpdate || isempty(layoutCache)
            setappdata(handleObj, 'LegacyLayoutCache', struct('Position', rect, 'FontSize', fontSize, 'FontWeight', fontWeight));
        end
    end

% ==================== 回调函数 ====================
    function selectEnumTargetFolder()
        folder = uigetdir(pwd, uiText.selectEnumTargetFolder);
        pause(0.01);
        focusMainWindow();
        appData = get(fig, 'UserData');
        updateListBox(appData.enumListBox, appData.enumFiles);
        if folder ~= 0
            setEditFieldValue(enumTargetPathEdit, folder);
            appData.targetPath = folder;
            set(fig, 'UserData', appData);
            setStatus(sprintf('枚举文件存放路径: %s', folder), [0 0 0]);
        end
    end

    function addFiles(type)
        switch type
            case 'enum'
                [files, path] = uigetfile('*.xlsx', uiText.selectEnumFiles, ...
                    pwd, 'MultiSelect', 'on');
            case 'interface'
                [files, path] = uigetfile('*.xlsx', uiText.selectInterfaceFiles, ...
                    pwd, 'MultiSelect', 'on');
            case 'var'
                [files, path] = uigetfile('*.xlsx', uiText.selectVarFiles, ...
                    pwd, 'MultiSelect', 'on');
            case 'script'
                [files, path] = uigetfile('*.m', uiText.selectScriptFiles, ...
                    pwd, 'MultiSelect', 'on');
        end
        pause(0.01);
        focusMainWindow();
        if isequal(files, 0), return; end
        if ischar(files), files = {files}; end

        validFiles = {};
        for i = 1:length(files)
            if ~startsWith(files{i}, '~')
                validFiles{end+1} = files{i};
            end
        end

        if isempty(validFiles)
            setStatus('未选择有效的文件（临时文件已被过滤）', [0.8 0.4 0]);
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
                setStatus(sprintf('已添加 %d 个枚举文件，共 %d 个', length(newPaths), length(allFiles)), [0 0 0]);
            case 'interface'
                allFiles = [appData.interfaceFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.interfaceFiles = allFiles;
                updateListBox(appData.interfaceListBox, allFiles);
                setStatus(sprintf('已添加 %d 个 Interface 文件，共 %d 个', length(newPaths), length(allFiles)), [0 0 0]);
            case 'var'
                allFiles = [appData.varFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.varFiles = allFiles;
                updateListBox(appData.varListBox, allFiles);
                setStatus(sprintf('已添加 %d 个其他变量定义文件，共 %d 个', length(newPaths), length(allFiles)), [0 0 0]);
            case 'script'
                allFiles = [appData.otherMFiles, newPaths];
                allFiles = unique(allFiles, 'stable');
                appData.otherMFiles = allFiles;
                updateListBox(appData.otherMListBox, allFiles);
                setStatus(sprintf('已添加 %d 个其他 .m 文件，共 %d 个', length(newPaths), length(allFiles)), [0 0 0]);
        end
        set(fig, 'UserData', appData);
    end

    function addFolder(type)
        switch type
            case 'enum'
                folder = uigetdir(pwd, uiText.selectEnumFolder);
            case 'interface'
                folder = uigetdir(pwd, uiText.selectInterfaceFolder);
            case 'var'
                folder = uigetdir(pwd, uiText.selectVarFolder);
            case 'script'
                folder = uigetdir(pwd, uiText.selectScriptFolder);
        end
        pause(0.01);
        focusMainWindow();
        if folder == 0, return; end
        setStatus('正在扫描文件夹...', [0.5 0 0]);
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                updateListBox(appData.enumListBox, appData.enumFiles);
            case 'interface'
                updateListBox(appData.interfaceListBox, appData.interfaceFiles);
            case 'var'
                updateListBox(appData.varListBox, appData.varFiles);
            case 'script'
                updateListBox(appData.otherMListBox, appData.otherMFiles);
        end
        switch type
            case 'enum'
                excelFiles = findAllExcelFiles(folder);
                allFiles = [appData.enumFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.enumFiles = allFiles;
                updateListBox(appData.enumListBox, allFiles);
                setStatus(sprintf('从文件夹中添加了 %d 个枚举文件，共 %d 个', length(excelFiles), length(allFiles)), [0 0 0]);
            case 'interface'
                excelFiles = findAllExcelFiles(folder);
                allFiles = [appData.interfaceFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.interfaceFiles = allFiles;
                updateListBox(appData.interfaceListBox, allFiles);
                setStatus(sprintf('从文件夹中添加了 %d 个 Interface 文件，共 %d 个', length(excelFiles), length(allFiles)), [0 0 0]);
            case 'var'
                excelFiles = findAllExcelFiles(folder);
                allFiles = [appData.varFiles, excelFiles];
                allFiles = unique(allFiles, 'stable');
                appData.varFiles = allFiles;
                updateListBox(appData.varListBox, allFiles);
                setStatus(sprintf('从文件夹中添加了 %d 个其他变量定义文件，共 %d 个', length(excelFiles), length(allFiles)), [0 0 0]);
            case 'script'
                scriptFiles = findAllScriptFiles(folder);
                allFiles = [appData.otherMFiles, scriptFiles];
                allFiles = unique(allFiles, 'stable');
                appData.otherMFiles = allFiles;
                updateListBox(appData.otherMListBox, allFiles);
                setStatus(sprintf('从文件夹中添加了 %d 个其他 .m 文件，共 %d 个', length(scriptFiles), length(allFiles)), [0 0 0]);
        end
        set(fig, 'UserData', appData);
    end

    function deleteSelected(type)
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                if isempty(appData.enumFiles), return; end
                selected = getListBoxSelection(appData.enumListBox);
                if isempty(selected), return; end
                [~, idx] = intersect(appData.enumFiles, selected);
                appData.enumFiles(idx) = [];
                updateListBox(appData.enumListBox, appData.enumFiles);
                setStatus(sprintf('已删除 %d 个枚举文件，剩余 %d 个', length(idx), length(appData.enumFiles)), [0 0 0]);
            case 'interface'
                if isempty(appData.interfaceFiles), return; end
                selected = getListBoxSelection(appData.interfaceListBox);
                if isempty(selected), return; end
                [~, idx] = intersect(appData.interfaceFiles, selected);
                appData.interfaceFiles(idx) = [];
                updateListBox(appData.interfaceListBox, appData.interfaceFiles);
                setStatus(sprintf('已删除 %d 个 Interface 文件，剩余 %d 个', length(idx), length(appData.interfaceFiles)), [0 0 0]);
            case 'var'
                if isempty(appData.varFiles), return; end
                selected = getListBoxSelection(appData.varListBox);
                if isempty(selected), return; end
                [~, idx] = intersect(appData.varFiles, selected);
                appData.varFiles(idx) = [];
                updateListBox(appData.varListBox, appData.varFiles);
                setStatus(sprintf('已删除 %d 个其他变量定义文件，剩余 %d 个', length(idx), length(appData.varFiles)), [0 0 0]);
            case 'script'
                if isempty(appData.otherMFiles), return; end
                selected = getListBoxSelection(appData.otherMListBox);
                if isempty(selected), return; end
                [~, idx] = intersect(appData.otherMFiles, selected);
                appData.otherMFiles(idx) = [];
                updateListBox(appData.otherMListBox, appData.otherMFiles);
                setStatus(sprintf('已删除 %d 个其他 .m 文件，剩余 %d 个', length(idx), length(appData.otherMFiles)), [0 0 0]);
        end
        set(fig, 'UserData', appData);
    end

    function clearAll(type)
        appData = get(fig, 'UserData');
        switch type
            case 'enum'
                appData.enumFiles = {};
                updateListBox(appData.enumListBox, {});
                setStatus('已清空枚举文件列表', [0 0 0]);
            case 'interface'
                appData.interfaceFiles = {};
                updateListBox(appData.interfaceListBox, {});
                setStatus('已清空 Interface 文件列表', [0 0 0]);
            case 'var'
                appData.varFiles = {};
                updateListBox(appData.varListBox, {});
                setStatus('已清空其他变量定义文件列表', [0 0 0]);
            case 'script'
                appData.otherMFiles = {};
                updateListBox(appData.otherMListBox, {});
                setStatus('已清空其他 .m 文件列表', [0 0 0]);
        end
        set(fig, 'UserData', appData);
    end

    function updateListBox(listbox, filePaths)
        if isLegacyUI
            if isempty(filePaths)
                set(listbox, 'String', {}, 'Value', []);
            else
                set(listbox, 'String', filePaths, 'Value', []);
            end
            return;
        end
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

    function scriptFiles = findAllScriptFiles(rootFolder)
        scriptFiles = {};
        items = dir(rootFolder);
        for i = 1:length(items)
            if items(i).isdir && ~ismember(items(i).name, {'.', '..'})
                subFiles = findAllScriptFiles(fullfile(rootFolder, items(i).name));
                scriptFiles = [scriptFiles, subFiles];
            elseif ~items(i).isdir && endsWith(items(i).name, '.m', 'IgnoreCase', true)
                scriptFiles{end+1} = fullfile(rootFolder, items(i).name);
            end
        end
    end

    function focusMainWindow()
        if isLegacyUI
            figure(fig);
        end
        drawnow;
    end

    function setEditFieldValue(handleObj, value)
        if isLegacyUI
            set(handleObj, 'String', value);
        else
            handleObj.Value = value;
        end
    end

    function value = getEditFieldValue(handleObj)
        if isLegacyUI
            value = get(handleObj, 'String');
        else
            value = handleObj.Value;
        end
    end

    function selected = getListBoxSelection(listbox)
        if isLegacyUI
            items = get(listbox, 'String');
            idx = get(listbox, 'Value');
            if isempty(items) || isempty(idx)
                selected = {};
                return;
            end
            if ischar(items)
                items = cellstr(items);
            end
            idx = idx(idx >= 1 & idx <= numel(items));
            selected = items(idx);
            return;
        end
        selected = listbox.Value;
        if ischar(selected)
            selected = {selected};
        end
    end

    function setStatus(message, color)
        unusedArgs = {message, color};
        if isempty(unusedArgs)
            return;
        end
    end

    function showAlert(level, message, titleText)
        dialogTitle = uiText.promptTitle;
        if nargin >= 3 && ~isempty(titleText)
            dialogTitle = titleText;
        end
        if ~isLegacyUI
            iconType = 'info';
            switch lower(level)
                case 'error'
                    iconType = 'error';
                    if nargin < 3 || isempty(titleText), dialogTitle = uiText.errorTitle; end
                case 'warning'
                    iconType = 'warning';
                    if nargin < 3 || isempty(titleText), dialogTitle = uiText.warningTitle; end
                case 'success'
                    iconType = 'success';
                    if nargin < 3 || isempty(titleText), dialogTitle = uiText.doneTitle; end
            end
            uialert(fig, message, dialogTitle, 'Icon', iconType);
        else
            switch lower(level)
                case 'error'
                    errordlg(message, dialogTitle);
                case 'warning'
                    warndlg(message, dialogTitle);
                otherwise
                    msgbox(message, dialogTitle);
            end
        end
    end

% ==================== 生成主函数 ====================
    function generate()
        appData = get(fig, 'UserData');
        if ~isempty(appData.enumFiles) && isempty(appData.targetPath)
            showAlert('error', '选择了枚举文件，请选择枚举文件存放路径！', uiText.errorTitle);
            return;
        end

        errorLog = cell(0, 1);
        warningLog = cell(0, 1);
        generatedVarNames = cell(0, 1);

        scriptMap = containers.Map();
        scriptOrder = {};
        function recordScriptLine(varName, lines)
            if ischar(lines), lines = {lines}; end
            if ~scriptMap.isKey(varName), scriptOrder{end+1} = varName; end
            scriptMap(varName) = lines;
        end

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
        for headerLineIdx = 1:length(headerLines)
            recordScriptLine(['__header__' num2str(headerLineIdx)], headerLines{headerLineIdx});
        end

        setStatus('正在生成...', [0.5 0 0]);
        drawnow;

        try
            for enumIdx = 1:length(appData.enumFiles)
                enumFile = appData.enumFiles{enumIdx};
                fprintf('\n--- 处理枚举文件 (%d/%d): %s ---\n', enumIdx, length(appData.enumFiles), enumFile);
                try
                    [newVars, errors, warnings] = processEnumFile(enumFile, appData.targetPath);
                    generatedVarNames = appendCellRow(generatedVarNames, newVars);
                    errorLog = appendCellColumn(errorLog, errors);
                    warningLog = appendCellColumn(warningLog, warnings);
                catch ME
                    errorLog = appendCellMessage(errorLog, sprintf('枚举文件处理失败: %s - %s', enumFile, ME.message));
                end
            end

            if ~isempty(appData.enumFiles) && ~isempty(appData.targetPath)
                addpath(appData.targetPath);
                rehash;
            end

            for intfIdx = 1:length(appData.interfaceFiles)
                intfFile = appData.interfaceFiles{intfIdx};
                fprintf('\n--- 处理 Interface 文件 (%d/%d): %s ---\n', intfIdx, length(appData.interfaceFiles), intfFile);
                try
                    [newVars, errors, warnings] = processInterfaceFile(intfFile);
                    generatedVarNames = appendCellRow(generatedVarNames, newVars);
                    errorLog = appendCellColumn(errorLog, errors);
                    warningLog = appendCellColumn(warningLog, warnings);
                catch ME
                    errorLog = appendCellMessage(errorLog, sprintf('Interface文件处理失败: %s - %s', intfFile, ME.message));
                end
            end

            for varIdx = 1:length(appData.varFiles)
                varFile = appData.varFiles{varIdx};
                fprintf('\n--- 处理变量定义文件 (%d/%d): %s ---\n', varIdx, length(appData.varFiles), varFile);
                try
                    [newVars, errors, warnings] = processVariableDefinitionFile(varFile);
                    generatedVarNames = appendCellRow(generatedVarNames, newVars);
                    errorLog = appendCellColumn(errorLog, errors);
                    warningLog = appendCellColumn(warningLog, warnings);
                catch ME
                    errorLog = appendCellMessage(errorLog, sprintf('变量定义文件处理失败: %s - %s', varFile, ME.message));
                end
            end

            scriptFileName = strtrim(getEditFieldValue(scriptNameEdit));
            if isempty(scriptFileName), scriptFileName = 'LoadWorkspaceData.m'; end
            if ~endsWith(scriptFileName, '.m'), scriptFileName = [scriptFileName, '.m']; end
            scriptPath = fullfile(pwd, scriptFileName);
            extraScriptLines = buildMergedScriptLines(appData.otherMFiles);
            mergeLoadScript(scriptPath, scriptMap, scriptOrder, generatedVarNames, extraScriptLines);

            if ~isempty(warningLog)
                fprintf('\n[WARN] 警告信息汇总:\n');
                for warningIdx = 1:length(warningLog)
                    fprintf('   %s\n', warningLog{warningIdx});
                end
            end
            if ~isempty(errorLog)
                fprintf('\n[ERROR] 错误信息汇总:\n');
                for errorIdx = 1:length(errorLog)
                    fprintf('   %s\n', errorLog{errorIdx});
                end
                setStatus('生成完成，但存在错误', [0.8 0.5 0]);
                showAlert('warning', sprintf('生成过程中发生 %d 个错误，请查看命令窗口', length(errorLog)), uiText.warningTitle);
            else
                fprintf('\n[OK] 生成完成，所有处理成功。\n');
                setStatus('[OK] 生成完成', [0 0.5 0]);
                showAlert('success', sprintf('生成成功！\n加载脚本已保存至:\n%s', scriptPath), uiText.doneTitle);
            end
        catch ME
            setStatus('[FAIL] 生成失败', [0.8 0 0]);
            showAlert('error', sprintf('生成失败:\n%s', ME.message), uiText.errorTitle);
            rethrow(ME);
        end

        function lines = buildMergedScriptLines(filePaths)
            lines = {};
            for fileIdx = 1:length(filePaths)
                scriptFile = filePaths{fileIdx};
                if ~exist(scriptFile, 'file')
                    warningLog = appendCellMessage(warningLog, sprintf('附加脚本不存在，已跳过: %s', scriptFile));
                    continue;
                end
                try
                    scriptContent = fileread(scriptFile);
                    scriptLines = regexp(scriptContent, '\r\n|\n|\r', 'split');
                    lines{end+1} = sprintf('%% ===== 合并脚本: %s =====', scriptFile);
                    lines = [lines; scriptLines(:)];
                    lines{end+1} = sprintf('%% ===== 结束: %s =====', scriptFile);
                    lines{end+1} = '';
                catch ME
                    warningLog = appendCellMessage(warningLog, sprintf('读取附加脚本失败 %s: %s', scriptFile, ME.message));
                end
            end
        end

        % ==================== 嵌套辅助函数 ====================
        function [varNames, errors, warnings] = processEnumFile(excelFile, targetPath)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            try
                [enumGroups, enumErrors] = parseEnumSheet(excelFile);
                errors = appendCellColumn(errors, enumErrors);
                if ~isempty(enumGroups)
                    if ~exist(targetPath, 'dir'), mkdir(targetPath); end
                    for enumGroupIdx = 1:length(enumGroups)
                        enumInfo = enumGroups{enumGroupIdx};
                        className = matlab.lang.makeValidName(enumInfo.Name);
                        filePath = fullfile(targetPath, [className, '.m']);
                        fid = fopen(filePath, 'w');
                        if fid == -1
                            errors = appendCellMessage(errors, sprintf('无法创建枚举文件: %s', className));
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
                        fprintf('   [OK] 生成枚举: %s.m\n', className);
                    end
                end
            catch ME
                errors = appendCellMessage(errors, sprintf('解析枚举sheet失败: %s', ME.message));
            end
            try
                [aliasVars, aliasErrors, aliasWarnings] = processNumericSheet(excelFile);
                varNames = appendCellRow(varNames, aliasVars);
                errors = appendCellColumn(errors, aliasErrors);
                warnings = appendCellColumn(warnings, aliasWarnings);
            catch ME
                errors = appendCellMessage(errors, sprintf('处理numeric sheet失败: %s', ME.message));
            end
            try
                [busVars, busErrors, busWarnings] = processBusSheet(excelFile);
                varNames = appendCellRow(varNames, busVars);
                errors = appendCellColumn(errors, busErrors);
                warnings = appendCellColumn(warnings, busWarnings);
            catch ME
                errors = appendCellMessage(errors, sprintf('处理bus sheet失败: %s', ME.message));
            end
        end

        function [enumGroups, errors] = parseEnumSheet(excelFile)
            enumGroups = {}; errors = cell(0, 1);
            try
                [~, ~, rawData] = xlsread(excelFile, 'enumeration');
                if isempty(rawData)
                    errors = appendCellMessage(errors, '无法读取 "enumeration" sheet');
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'ConvName'});
                if headerRowIdx == 0
                    errors = appendCellMessage(errors, '未找到 ConvName 列');
                    return;
                end
                convNameCol = findColumnIndex(headers, {'ConvName'});
                descCol = findColumnIndex(headers, {'Description', '描述'});
                if convNameCol == 0
                    errors = appendCellMessage(errors, '未找到 ConvName 列');
                    return;
                end
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
                errors = appendCellMessage(errors, sprintf('解析枚举sheet异常: %s', ME.message));
            end
        end

        function [varNames, errors, warnings] = processNumericSheet(excelFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            try
                [~, ~, rawData] = xlsread(excelFile, 'numeric');
                if isempty(rawData) || size(rawData, 1) < 2
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'ConvName', 'DataType'});
                if headerRowIdx == 0
                    warnings = appendCellMessage(warnings, sprintf('%s: numeric sheet 未找到 ConvName/DataType 列，跳过', excelFile));
                    return;
                end
                convNameCol = findColumnIndex(headers, {'ConvName'});
                dataTypeCol = findColumnIndex(headers, {'DataType'});
                descCol = findColumnIndex(headers, {'Description', '描述'});
                if convNameCol == 0 || dataTypeCol == 0
                    warnings = appendCellMessage(warnings, sprintf('%s: numeric sheet 缺少必需列，跳过', excelFile));
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
                        varNames = appendCellRow(varNames, {typeName});
                        lines = {
                            sprintf('%% 自定义类型: %s', typeName);
                            sprintf('%s = Simulink.AliasType;', typeName);
                            sprintf('%s.BaseType = ''%s'';', typeName, baseType);
                            sprintf('%s.Description = ''%s'';', typeName, strrep(aliasObj.Description, '''', ''''''));
                            sprintf('assignin(''base'', ''%s'', %s);', typeName, typeName);
                            ''};
                        recordScriptLine(typeName, lines);
                        fprintf('   [OK] 创建自定义类型: %s (本质类型: %s)\n', typeName, baseType);
                    catch ME
                        errors = appendCellMessage(errors, sprintf('创建AliasType失败 %s: %s', typeName, ME.message));
                    end
                end
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:xlsread:SheetNotFound')
                    errors = appendCellMessage(errors, sprintf('处理numeric sheet失败: %s', ME.message));
                end
            end
        end

        function [varNames, errors, warnings] = processBusSheet(excelFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            try
                [~, ~, rawData] = xlsread(excelFile, 'bus');
                if isempty(rawData) || size(rawData, 1) < 2
                    return;
                end
                [headerRowIdx, headers] = findHeaderRow(rawData, {'BusName', 'ElementName', 'Typedef'});
                if headerRowIdx == 0
                    warnings = appendCellMessage(warnings, sprintf('%s: bus sheet 未找到 BusName/ElementName/Typedef 列，跳过', excelFile));
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
                    warnings = appendCellMessage(warnings, sprintf('%s: bus sheet 缺少必需列，跳过', excelFile));
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
                for busIdx = 1:length(busNames)
                    busName = busNames{busIdx};
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
                    varNames = appendCellRow(varNames, {busName});
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
                        varNames = appendCellRow(varNames, {signalName});
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
                        fprintf('   [OK] 创建总线成员信号: %s (所属总线: %s)\n', signalName, busName);
                    end
                    fprintf('   [OK] 创建总线对象: %s (包含 %d 个元素)\n', busName, length(elements));
                end
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:xlsread:SheetNotFound')
                    errors = appendCellMessage(errors, sprintf('处理bus sheet失败: %s', ME.message));
                end
            end
        end

        function [varNames, errors, warnings] = processInterfaceFile(excelFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            sheets = {'CAL', 'NVV', 'IN', 'OUT', 'MP'};
            for sheetIdx = 1:length(sheets)
                sheetName = sheets{sheetIdx};
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
                    varNames = appendCellRow(varNames, vars);
                    errors = appendCellColumn(errors, errs);
                    warnings = appendCellColumn(warnings, warns);
                catch ME
                    errors = appendCellMessage(errors, sprintf('工作表 %s 处理失败: %s', sheetName, ME.message));
                end
            end
        end

        function [varNames, errors, warnings] = processCalNvvSheet(rawData, numData, srcFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            if isempty(rawData) || size(rawData,1) < 2
                return;
            end
            headers = rawData(1, :);
            for numericHeaderIdx = 1:length(headers)
                if isnumeric(headers{numericHeaderIdx}) && isnan(headers{numericHeaderIdx})
                    headers{numericHeaderIdx} = '';
                end
            end
            nameCol = findColumnIndex(headers, {'Name'});
            typeCol = findColumnIndex(headers, {'typedef', 'DataType'});
            defaultCol = findColumnIndex(headers, {'defaultvalue', 'default', 'Value'});
            widthCol = findColumnIndex(headers, {'width'});
            descCol = findColumnIndex(headers, {'Description', '描述'});
            if nameCol == 0
                warnings = appendCellMessage(warnings, sprintf('%s: 未找到Name列，跳过', srcFile));
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
                [valid, errMsg] = validateDataType(dataTypeRaw);
                if ~valid
                    errors = appendCellMessage(errors, sprintf('参数 %s 数据类型无效: %s', varName, errMsg));
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
                if startsWith(dataTypeRaw, 'Enum:', 'IgnoreCase', true)
                    enumClassName = strtrim(dataTypeRaw(6:end));
                    enumClassName = matlab.lang.makeValidName(enumClassName);
                    try
                        if ~exist(enumClassName, 'class')
                            errors = appendCellMessage(errors, sprintf('枚举类 %s 未找到，参数 %s 创建失败', enumClassName, varName));
                            continue;
                        end
                        param = Simulink.Parameter;
                        param.DataType = ['Enum: ', enumClassName];
                        if ~isempty(description)
                            param.Description = description;
                        end
                        if isnumeric(defaultValue)
                            members = enumeration(enumClassName);
                            if ~isempty(members)
                                memberValues = arrayfun(@(m) int32(m), members);
                                idx = find(memberValues == defaultValue, 1);
                                if ~isempty(idx)
                                    enumValue = members(idx);
                                else
                                    warnings = appendCellMessage(warnings, sprintf('数值 %d 未匹配枚举 %s，使用第一个成员', defaultValue, enumClassName));
                                    enumValue = members(1);
                                end
                            else
                                errors = appendCellMessage(errors, sprintf('枚举类 %s 无成员', enumClassName));
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
                                    errors = appendCellMessage(errors, sprintf('枚举类 %s 中未找到成员 %s', enumClassName, memberName));
                                    continue;
                                end
                            end
                        else
                            errors = appendCellMessage(errors, sprintf('参数 %s 默认值类型不支持', varName));
                            continue;
                        end
                        param.Value = enumValue;
                        assignin('base', varName, param);
                        varNames = appendCellRow(varNames, {varName});
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
                        fprintf('   [OK] 创建枚举参数: %s\n', varName);
                    catch ME
                        errors = appendCellMessage(errors, sprintf('创建枚举参数失败 %s: %s', varName, ME.message));
                    end
                else
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
                        varNames = appendCellRow(varNames, {varName});
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
                        fprintf('   [OK] 创建参数: %s\n', varName);
                    catch ME
                        errors = appendCellMessage(errors, sprintf('创建参数失败 %s: %s', varName, ME.message));
                    end
                end
            end
        end

        function [varNames, errors, warnings] = processSignalSheet(rawData, srcFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            if isempty(rawData) || size(rawData,1) < 2
                return;
            end
            headers = rawData(1, :);
            for signalHeaderIdx = 1:length(headers)
                if isnumeric(headers{signalHeaderIdx}) && isnan(headers{signalHeaderIdx})
                    headers{signalHeaderIdx} = '';
                end
            end
            nameCol = findColumnIndex(headers, {'Name'});
            typeCol = findColumnIndex(headers, {'typedef', 'DataType'});
            initCol = findColumnIndex(headers, {'defaultvalue', 'default', 'InitialValue'});
            descCol = findColumnIndex(headers, {'Description', '描述'});
            if nameCol == 0
                warnings = appendCellMessage(warnings, sprintf('%s: 未找到Name列，跳过', srcFile));
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
                [valid, errMsg] = validateDataType(dataType);
                if ~valid
                    errors = appendCellMessage(errors, sprintf('信号 %s 数据类型无效: %s', sigName, errMsg));
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
                    varNames = appendCellRow(varNames, {sigName});
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
                    fprintf('   [OK] 创建 Simulink.Signal: %s\n', sigName);
                catch ME
                    errors = appendCellMessage(errors, sprintf('创建信号失败 %s: %s', sigName, ME.message));
                end
            end
        end

        function [varNames, errors, warnings] = processVariableDefinitionFile(excelFile)
            varNames = cell(1, 0); errors = cell(0, 1); warnings = cell(0, 1);
            try
                [~, sheetNames] = xlsfinfo(excelFile);
                if isempty(sheetNames)
                    warnings = appendCellMessage(warnings, sprintf('文件 %s 无有效工作表，跳过', excelFile));
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
                        varNames = appendCellRow(varNames, vars);
                        errors = appendCellColumn(errors, errs);
                        warnings = appendCellColumn(warnings, warns);
                    catch ME
                        errors = appendCellMessage(errors, sprintf('工作表 %s 处理失败: %s', sheetName, ME.message));
                    end
                end
            catch ME
                errors = appendCellMessage(errors, sprintf('处理变量定义文件失败: %s', ME.message));
            end
        end

        function [valid, errMsg] = validateDataType(dataType)
            valid = true; errMsg = '';
            dataType = strtrim(dataType);
            builtinTypes = {'uint8','uint16','uint32','uint64','int8','int16','int32','int64','single','double','logical','boolean'};
            if ismember(lower(dataType), builtinTypes), return; end
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
            if evalin('base', sprintf('exist(''%s'', ''var'')', dataType)) && evalin('base', sprintf('isa(%s, ''Simulink.AliasType'')', dataType))
                return;
            else
                valid = false;
                errMsg = sprintf('数据类型 %s 不是内置类型、枚举、Bus或已定义的AliasType', dataType);
            end
        end
    end

    function mergeLoadScript(scriptPath, scriptMap, scriptOrder, generatedVars, extraScriptLines)
        generatedMarker = '%% ========== 以下为新生成的内容 ==========';
        mergedMarker = '%% ========== 以下为合并的其他脚本内容 ==========';
        generatedScriptLines = {};
        for scriptIdx = 1:length(scriptOrder)
            varName = scriptOrder{scriptIdx};
            lines = scriptMap(varName);
            if iscell(lines)
                generatedScriptLines = [generatedScriptLines; lines(:)];
            else
                generatedScriptLines{end+1} = lines;
            end
        end

        newVarSet = unique([generatedVars, extractAssignedVarNames(extraScriptLines)]);

        if isempty(newVarSet) && exist(scriptPath, 'file')
            fprintf('[OK] 未检测到新的变量或附加脚本，保持现有加载脚本不变: %s\n', scriptPath);
            return;
        end

        if ~exist(scriptPath, 'file')
            fid = fopen(scriptPath, 'w');
            if fid == -1, error('无法创建脚本文件'); end
            fprintf(fid, '%s\n', generatedMarker);
            for i = 1:length(generatedScriptLines), fprintf(fid, '%s\n', generatedScriptLines{i}); end
            if ~isempty(extraScriptLines)
                fprintf(fid, '%s\n', mergedMarker);
                for i = 1:length(extraScriptLines), fprintf(fid, '%s\n', extraScriptLines{i}); end
            end
            fclose(fid);
            fprintf('[OK] 已生成加载脚本: %s\n', scriptPath);
            return;
        end

        oldContent = fileread(scriptPath);
        lines = regexp(oldContent, '\r\n|\n|\r', 'split');
        keepGeneratedLines = {};
        keepMergedLines = {};
        inMergedSection = false;
        i = 1;
        while i <= length(lines)
            line = lines{i};
            if strcmp(line, generatedMarker)
                i = i + 1;
                continue;
            end
            if strcmp(line, mergedMarker)
                inMergedSection = true;
                i = i + 1;
                continue;
            end
            tokens = regexp(line, '^\s*(\w+)\s*=', 'tokens');
            if ~isempty(tokens)
                varName = tokens{1}{1};
                if ismember(varName, newVarSet)
                    i = i + 1;
                    while i <= length(lines)
                        nextLine = lines{i};
                        if strcmp(nextLine, generatedMarker) || strcmp(nextLine, mergedMarker), break; end
                        if ~isempty(regexp(nextLine, '^\s*(\w+)\s*=', 'tokens')), break; end
                        i = i + 1;
                    end
                    continue;
                else
                    if inMergedSection
                        keepMergedLines{end+1} = line;
                    else
                        keepGeneratedLines{end+1} = line;
                    end
                    i = i + 1;
                    while i <= length(lines)
                        nextLine = lines{i};
                        if strcmp(nextLine, generatedMarker) || strcmp(nextLine, mergedMarker), break; end
                        if ~isempty(regexp(nextLine, '^\s*(\w+)\s*=', 'tokens')), break; end
                        if inMergedSection
                            keepMergedLines{end+1} = nextLine;
                        else
                            keepGeneratedLines{end+1} = nextLine;
                        end
                        i = i + 1;
                    end
                end
            else
                if inMergedSection
                    keepMergedLines{end+1} = line;
                else
                    keepGeneratedLines{end+1} = line;
                end
                i = i + 1;
            end
        end

        fid = fopen(scriptPath, 'w');
        if fid == -1, error('无法写入脚本文件'); end
        for i = 1:length(keepGeneratedLines), fprintf(fid, '%s\n', keepGeneratedLines{i}); end
        if ~isempty(keepGeneratedLines)
            fprintf(fid, '\n');
        end
        fprintf(fid, '%s\n', generatedMarker);
        for i = 1:length(generatedScriptLines), fprintf(fid, '%s\n', generatedScriptLines{i}); end
        finalMergedLines = [keepMergedLines(:); extraScriptLines(:)];
        if ~isempty(finalMergedLines)
            fprintf(fid, '%s\n', mergedMarker);
            for i = 1:length(finalMergedLines), fprintf(fid, '%s\n', finalMergedLines{i}); end
        end
        fclose(fid);
        fprintf('[OK] 已合并生成加载脚本: %s\n', scriptPath);
    end

    function varNames = extractAssignedVarNames(lines)
        varNames = {};
        if isempty(lines)
            return;
        end
        for lineIdx = 1:length(lines)
            line = lines{lineIdx};
            if ~ischar(line)
                continue;
            end
            tokens = regexp(line, '^\s*(\w+)\s*=', 'tokens', 'once');
            if ~isempty(tokens)
                varNames = appendCellRow(varNames, {tokens{1}});
            end
        end
        if ~isempty(varNames)
            varNames = unique(varNames, 'stable');
        end
    end

% 兼容模式布局计算（嵌套函数，供 else 分支调用）
    function pos = getPosCompat(rowSpan, colSpan, rowHeights, colWidths)
        if isscalar(rowSpan)
            r1 = rowSpan; r2 = rowSpan;
        else
            r1 = rowSpan(1); r2 = rowSpan(2);
        end
        h = sum(rowHeights(r1:r2));
        y = sum(rowHeights(r2+1:end));
        if isscalar(colSpan)
            c1 = colSpan; c2 = colSpan;
        else
            c1 = colSpan(1); c2 = colSpan(2);
        end
        x = sum(colWidths(1:c1-1));
        w = sum(colWidths(c1:c2));
        pos = [x, y, w, h];
    end
end

%% ======================== 全局辅助函数 ========================
function [headerRowIdx, headers] = findHeaderRow(rawData, requiredColNames)
if isempty(rawData), headerRowIdx = 0; headers = {}; return; end
for row = 1:size(rawData, 1)
    rowData = rawData(row, :);
    foundAll = true;
    for j = 1:length(requiredColNames)
        colFound = false;
        for col = 1:length(rowData)
            cellVal = rowData{col};
            if ischar(cellVal) && ~isempty(strtrim(cellVal))
                if strcmpi(strtrim(cellVal), requiredColNames{j}), colFound = true; break; end
            end
        end
        if ~colFound, foundAll = false; break; end
    end
    if foundAll, headerRowIdx = row; headers = rowData; return; end
end
headerRowIdx = 0; headers = {};
end

function colIdx = findColumnIndex(headers, possibleNames)
colIdx = 0;
for i = 1:length(headers)
    if ~isempty(headers{i}) && ischar(headers{i})
        hdr = strtrim(headers{i});
        for j = 1:length(possibleNames)
            if strcmpi(hdr, possibleNames{j}), colIdx = i; return; end
        end
    end
end
end

function [baseType, isBuiltin] = resolveBaseTypeWithFlag(typeName)
baseType = lower(strtrim(typeName));
builtinTypes = {'uint8','uint16','uint32','uint64','int8','int16','int32','int64','single','double','logical','boolean'};
if ismember(baseType, builtinTypes), isBuiltin = true; return; end
if strcmp(baseType, 'boolean') || strcmp(baseType, 'bool'), baseType = 'boolean'; isBuiltin = true; return; end
try
    if evalin('base', sprintf('exist(''%s'', ''var'')', baseType))
        obj = evalin('base', baseType);
        if isa(obj, 'Simulink.AliasType'), [baseType, isBuiltin] = resolveBaseTypeWithFlag(obj.BaseType); return; end
    end
catch
end
isBuiltin = false;
end

function items = appendCellColumn(items, newItems)
if isempty(items), items = cell(0, 1); else items = items(:); end
if isempty(newItems), return; end
items = [items; newItems(:)];
end

function items = appendCellRow(items, newItems)
if isempty(items), items = cell(1, 0); else items = reshape(items, 1, []); end
if isempty(newItems), return; end
items = [items, reshape(newItems, 1, [])];
end

function items = appendCellMessage(items, message)
if isempty(items), items = cell(0, 1); else items = items(:); end
items{end+1, 1} = message;
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