classdef SerialDevice < handle
    properties
        PortObj         % serialport 对象
        DataCallback    % 注入 App 的数据处理回调
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
                writeline(obj.PortObj, "RECORD,1"); 
            end
        end
        
        function StopRecording(obj)
            if ~isempty(obj.PortObj) && isvalid(obj.PortObj)
                writeline(obj.PortObj, "RECORD,0");
                obj.IsRecording = false;
            end
        end
        
        function readSerialData(obj, ~, ~)
            if ~obj.IsRecording || isempty(obj.DataCallback)
                readline(obj.PortObj); % 丢弃非记录状态数据
                return;
            end
            
            try
                rawStr = readline(obj.PortObj);
                % 解析格式: Timestamp,Angle,L1..L5,R1..R5 (共12位)
                dataVector = str2double(split(rawStr, ','));
                
                if length(dataVector) == 12 && ~any(isnan(dataVector))
                    obj.DataCallback(dataVector'); % 转换为行向量推送到 App
                end
            catch
                % 串口误码处理，跳过坏帧
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