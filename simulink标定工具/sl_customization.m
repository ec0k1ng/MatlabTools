function sl_customization(cm)
% 注册到右键菜单
cm.addCustomMenuFcn('Simulink:ContextMenu', @getMyItems);
end

function renderItems = getMyItems(callbackInfo)
% 直接返回元胞数组
renderItems = {@getInspectorSchema};
end

function schema = getInspectorSchema(callbackInfo)
schema = sl_action_schema;
schema.label = '快速标定工具';
schema.tag = 'SimulinkInspector:Launch';

% 回调函数
schema.callback = @(callbackInfo) SimulinkInspector.launch(gcbh);
end