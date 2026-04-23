classdef SerialDevice < handle
    properties
        PortObj         % serialport 对象
        DataCallback    % 注入 App 的数据处理回调
        StatusCallback  % 用于向App传递文本消息的回调函数
        IsRecording = false
    end
    
    methods
        function obj = SerialDevice(portName, baudRate)
            try
                obj.PortObj = serialport(portName, baudRate);
                configureTerminator(obj.PortObj, "LF");
                % 开启硬件中断回调，一旦收到 \n 立即执行
                configureCallback(obj.PortObj, "terminator", @obj.readSerialData);
            catch ME
                error(['无法打开串口: ', ME.message]);
            end
        end
        
        function StartRecording(obj)
            if ~isempty(obj.PortObj) && isvalid(obj.PortObj)
                obj.IsRecording = true;
                writeline(obj.PortObj, "S"); 
            end
        end
        
        function StopRecording(obj)
            if ~isempty(obj.PortObj) && isvalid(obj.PortObj)
                writeline(obj.PortObj, "E");
                obj.IsRecording = false;
            end
        end

        function readSerialData(obj, ~, ~)
            try
                rawStr = readline(obj.PortObj);
                rawStr = strip(rawStr); % 去除首尾不可见字符（如 \r）

                % 1. 优先识别特定成功字段
                if strcmpi(rawStr, "All scale tared")
                    if ~isempty(obj.StatusCallback)
                        obj.StatusCallback("TareSuccess");
                    end
                    return;
                end

                % 2. 原有的数值数据解析逻辑
                if obj.IsRecording && ~isempty(obj.DataCallback)
                    dataVector = str2double(split(rawStr, ','));
                    if length(dataVector) == 12 && ~any(isnan(dataVector))
                        obj.DataCallback(dataVector');
                    end
                end
            catch ME
                fprintf("串口读取错误: %s\n", ME.message);
            end
        end

        function SendCommand(obj, cmdStr)
            if ~isempty(obj.PortObj) && isvalid(obj.PortObj)
                writeline(obj.PortObj, cmdStr);
                disp(['已发送指令: ', char(cmdStr)]); % 在命令行打印调试信息
            end
        end

        function delete(obj)
            if ~isempty(obj.PortObj) && isvalid(obj.PortObj)
                obj.StopRecording();
                configureCallback(obj.PortObj, "off");
                delete(obj.PortObj);
            end
        end
    end
end