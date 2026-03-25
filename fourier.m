% 傅里叶级数展开 - 从图片提取曲线并计算展开系数
% 逐行精准提取+手动辅助修正
% 输出每个an/bn对应的角频率数据，并写入Excel/CSV
clear; clc; close all;

%% ====================== 1. 图片选择与预处理 ======================
[imgFile, imgPath] = uigetfile({'*.png;*.jpg;*.bmp;*.tif','所有图片文件'}, '选择包含曲线的图片');
if isequal(imgFile, 0)
    disp('用户取消了图片选择，程序退出');
    return;
end
imgFullPath = fullfile(imgPath, imgFile);
img = imread(imgFullPath);
if size(img, 3) == 3
    imgGray = rgb2gray(img);
else
    imgGray = img;
end
% 显示原始图片
figure('Name','原始图片','Position', [100, 100, size(imgGray,2), size(imgGray,1)]); 
imshow(imgGray); title('原始图片');

%% ====================== 2. 坐标标定（像素坐标→物理坐标） ======================
disp('请在图片上完成坐标标定，步骤如下：');
disp('1. 点击X轴的两个刻度点（先左后右），例如X=0和X=0.8对应的位置');
disp('2. 点击Y轴的两个刻度点（先下后上），例如Y=0和Y=1.0对应的位置');
disp('注：点击时请精准点击刻度线与坐标轴的交点！');

% X轴标定
figure('Name','X轴标定','Position', [100, 100, size(imgGray,2), size(imgGray,1)]); 
imshow(imgGray); title('请依次点击X轴的两个刻度点（先左后右）');
[x_pixel_x, y_pixel_x] = ginput(2); 
x_physical_input = inputdlg({'请输入第一个X刻度点的物理值（如0）：','请输入第二个X刻度点的物理值（如0.8）：'},...
    'X轴物理值输入', 1, {'0','0.8'});
if isempty(x_physical_input)
    disp('用户取消X轴标定，程序退出');
    return;
end
x1_phy = str2double(x_physical_input{1});
x2_phy = str2double(x_physical_input{2});
if isnan(x1_phy) || isnan(x2_phy)
    error('X轴物理值输入无效，请输入数字！');
end

% Y轴标定
figure('Name','Y轴标定','Position', [100, 100, size(imgGray,2), size(imgGray,1)]); 
imshow(imgGray); title('请依次点击Y轴的两个刻度点（先下后上）');
[x_pixel_y, y_pixel_y] = ginput(2); 
y_physical_input = inputdlg({'请输入第一个Y刻度点的物理值（如0）：','请输入第二个Y刻度点的物理值（如1.0）：'},...
    'Y轴物理值输入', 1, {'0','1.0'});
if isempty(y_physical_input)
    disp('用户取消Y轴标定，程序退出');
    return;
end
y1_phy = str2double(y_physical_input{1});
y2_phy = str2double(y_physical_input{2});
if isnan(y1_phy) || isnan(y2_phy)
    error('Y轴物理值输入无效，请输入数字！');
end

% 建立像素坐标→物理坐标的线性映射
kx = (x2_phy - x1_phy) / (x_pixel_x(2) - x_pixel_x(1));
bx = x1_phy - kx * x_pixel_x(1);
ky = (y2_phy - y1_phy) / (y_pixel_y(2) - y_pixel_y(1)); 
by = y1_phy - ky * y_pixel_y(1);

%% ====================== 3. 曲线提取 ======================
% --- 3.1 第一步：手动框选曲线的X范围（仅选曲线的左右边界） ---
figure('Name','框选曲线X范围','Position', [100, 100, size(imgGray,2), size(imgGray,1)]);
imshow(imgGray); title('请框选曲线的X范围（左右边界，上下尽量覆盖曲线）');
rect = getrect(gcf); 
x_start = round(rect(1));
x_end = round(rect(1) + rect(3));
y_start = round(rect(2));
y_end = round(rect(2) + rect(4));
% 裁剪到目标区域
imgROI = imgGray(y_start:y_end, x_start:x_end);

% --- 3.2 第二步：逐行提取曲线点（核心逻辑） ---
disp('正在逐行提取曲线点...');
x_pixel = []; % 提取的X像素坐标
y_pixel = []; % 提取的Y像素坐标

% 先判断曲线颜色（黑曲线/白曲线）
mean_bg = mean(imgROI(:)); % 背景平均灰度
% 逐行处理每个X坐标
for x = 1:size(imgROI, 2)
    % 获取当前列的灰度值
    col_data = imgROI(:, x);
    % 找到灰度值与背景差异最大的点（曲线点）
    if mean_bg > 128 % 白背景，曲线是黑色（灰度值小）
        [~, y_idx] = min(col_data); % 找最黑的点（曲线点）
    else % 黑背景，曲线是白色（灰度值大）
        [~, y_idx] = max(col_data); % 找最白的点（曲线点）
    end
    % 转换为原始图片的像素坐标
    x_pixel = [x_pixel, x_start + x - 1];
    y_pixel = [y_pixel, y_start + y_idx - 1];
end

% --- 3.3 第三步：手动修正（关键！确保曲线精准） ---
figure('Name','手动修正曲线','Position', [100, 100, size(imgGray,2), size(imgGray,1)]);
imshow(imgGray); hold on;
plot(x_pixel, y_pixel, 'r-', 'LineWidth', 1, 'DisplayName', '初步提取曲线');
title('请点击曲线的关键修正点（至少3个，按X顺序点击，右键结束）');
disp('提示：1. 点击曲线的关键位置（如起点、拐点、终点）；2. 右键点击结束选择');
% 让用户手动选点修正
[manual_x, manual_y] = ginput(0); % 0表示右键结束
hold off;

% --- 3.4 第四步：融合手动点与自动提取点 ---
if ~isempty(manual_x)
    disp('正在融合手动修正点...');
    % 按X坐标排序手动点
    [manual_x_sorted, idx] = sort(manual_x);
    manual_y_sorted = manual_y(idx);
    % 用手动点插值生成最终曲线
    x_unique = linspace(min(x_pixel), max(x_pixel), length(x_pixel));
    y_unique = interp1(manual_x_sorted, manual_y_sorted, x_unique, 'cubic');
else
    % 无手动修正，用自动提取的点
    [x_unique, idx] = sort(x_pixel);
    y_unique = y_pixel(idx);
end

% 去除NaN值（插值可能产生）
valid_idx = ~isnan(y_unique);
xUnique_pixel = x_unique(valid_idx);
yUnique_pixel = y_unique(valid_idx);

% 转换为物理坐标
xUnique_phy = kx * xUnique_pixel + bx; 
yUnique_phy = ky * yUnique_pixel + by; 

%% ====================== 4. 显示提取的曲线（像素坐标） ======================
figure('Name','提取的曲线（像素坐标）','Position', [100, 100, size(imgGray,2), size(imgGray,1)]);
imshow(imgGray); hold on;
plot(xUnique_pixel, yUnique_pixel, 'r-', 'LineWidth', 2);
title('提取的曲线（红色）- 像素坐标'); 
xlabel('像素X'); ylabel('像素Y'); 
set(gca, 'YDir', 'reverse'); 
hold off;

%% ====================== 5. 显示提取的曲线（物理坐标） ======================
figure('Name','提取的曲线（物理坐标）','Position', [100, 100, size(imgGray,2), size(imgGray,1)], 'Color', 'white');
axis image; hold on;
plot(xUnique_pixel, yUnique_pixel, 'b-', 'LineWidth', 2);

% 生成程序标定后的刻度
xticks_pixel = linspace(min(xUnique_pixel), max(xUnique_pixel), 5);
xticks_phy = round(kx * xticks_pixel + bx, 2); 
yticks_pixel = linspace(min(yUnique_pixel), max(yUnique_pixel), 5);
yticks_phy = round(ky * yticks_pixel + by, 2); 

set(gca, ...
    'XTick', xticks_pixel, 'XTickLabel', xticks_phy, ...
    'YTick', yticks_pixel, 'YTickLabel', yticks_phy, ...
    'XLim', [1, size(imgGray,2)], 'YLim', [1, size(imgGray,1)], 'YDir', 'reverse', ...
    'Color', 'white', 'XGrid', 'off', 'YGrid', 'off', 'Box', 'on', 'GridAlpha', 0);

title('提取的曲线（蓝色）- 物理坐标');
xlabel('X（物理刻度）'); 
ylabel('Y（物理刻度）');
hold off;

%% ====================== 6. 傅里叶级数展开计算 ======================
while true
    orderInput = inputdlg('请输入傅里叶展开的阶数（正整数）：', '傅里叶阶数设置', 1, {'5'});
    if isempty(orderInput)
        disp('用户取消阶数输入，程序退出');
        return;
    end
    N = str2double(orderInput{1});
    if ~isnan(N) && N > 0 && mod(N,1) == 0
        break;
    else
        msgbox('输入无效！请输入正整数（如1,3,5,10等）', '错误', 'error');
    end
end

% 计算傅里叶系数
x = xUnique_phy;
y = yUnique_phy;
L = max(x) - min(x); % X轴物理范围
x0 = min(x);
xNorm = x - x0; 

a0 = (2/L) * trapz(xNorm, y); 
an = zeros(1, N); 
bn = zeros(1, N); 
wn = zeros(1, N); % 存储每个阶数的角频率

% 计算各阶系数和对应的角频率
for n = 1:N
    cosTerm = y .* cos(2*pi*n*xNorm/L);
    an(n) = (2/L) * trapz(xNorm, cosTerm);
    sinTerm = y .* sin(2*pi*n*xNorm/L);
    bn(n) = (2/L) * trapz(xNorm, sinTerm);
    wn(n) = 2 * pi * n / L; % 核心：计算第n阶的角频率 ωₙ = 2πn/L
end

%% ====================== 7. 结果输出与展示（新增角频率） ======================
disp('==================== 傅里叶展开系数（基于物理坐标） ====================');
fprintf('0阶系数 (a0)：%.6f (直流分量为 a0/2 = %.6f)，角频率 ω₀ = 0\\n', a0, a0/2);
for n = 1:N
    fprintf('第%d阶：余弦系数an = %.6f，正弦系数bn = %.6f，角频率 ωₙ = %.6f\\n', ...
        n, an(n), bn(n), wn(n));
end

% 还原展开后的曲线
yFourier_phy = a0/2 * ones(size(xNorm));
for n = 1:N
    yFourier_phy = yFourier_phy + an(n)*cos(2*pi*n*xNorm/L) + bn(n)*sin(2*pi*n*xNorm/L);
end
yFourier_pixel = (yFourier_phy - by) / ky;

% 显示对比曲线
figure('Name','原始曲线 vs 傅里叶展开曲线','Position', [100, 100, size(imgGray,2), size(imgGray,1)], 'Color', 'white');
axis image; hold on;
plot(xUnique_pixel, yUnique_pixel, 'b-', 'LineWidth', 2, 'DisplayName', '原始曲线');
plot(xUnique_pixel, yFourier_pixel, 'r--', 'LineWidth', 2, 'DisplayName', [num2str(N) '阶傅里叶展开曲线']);

set(gca, ...
    'XTick', xticks_pixel, 'XTickLabel', xticks_phy, ...
    'YTick', yticks_pixel, 'YTickLabel', yticks_phy, ...
    'XLim', [1, size(imgGray,2)], 'YLim', [1, size(imgGray,1)], 'YDir', 'reverse', ...
    'Color', 'white', 'XGrid', 'off', 'YGrid', 'off', 'Box', 'on', 'GridAlpha', 0);

xlabel('X（物理刻度）'); ylabel('Y（物理刻度）');
title('原始曲线 vs 傅里叶展开曲线对比');
legend; 
hold off;

%% ====================== 8. 保存系数（新增角频率列） ======================
saveChoice = questdlg('是否将傅里叶系数保存为文件？', '保存系数', '是', '否', '是');
if strcmp(saveChoice, '是')
    saveDir = pwd;
    if ~exist(saveDir, 'dir'); mkdir(saveDir); end
    
    % 构造表格（新增角频率列）
    header = {'阶数', '角频率ωₙ', 'an系数（余弦项）', 'bn系数（正弦项）', '备注'};
    dataRows = cell(N+1, 5);
    
    % 0阶数据（直流分量，角频率为0）
    dataRows{1,1} = 0;
    dataRows{1,2} = 0;
    dataRows{1,3} = a0;
    dataRows{1,4} = 0;
    dataRows{1,5} = sprintf('直流分量 = %.6f', a0/2);
    
    % 1~N阶数据（包含角频率）
    for n = 1:N
        dataRows{n+1,1} = n;
        dataRows{n+1,2} = wn(n);
        dataRows{n+1,3} = an(n);
        dataRows{n+1,4} = bn(n);
        dataRows{n+1,5} = sprintf('ωₙ = 2π*%d/%.6f = %.6f', n, L, wn(n));
    end
    
    % 合并表头和数据
    tableContent = cell(N+2, 5);
    tableContent(1,:) = header;
    tableContent(2:end,:) = dataRows;
    
    % 保存CSV（包含角频率）
    csvFileName = '傅里叶系数_完整标注.csv';
    csvFullPath = fullfile(saveDir, csvFileName);
    fid = fopen(csvFullPath, 'w', 'n', 'UTF-8');
    if fid ~= -1
        % 写入表头
        fprintf(fid, '%s,%s,%s,%s,%s\n', header{1}, header{2}, header{3}, header{4}, header{5});
        % 写入数据
        for i = 1:N+1
            fprintf(fid, '%d,%.6f,%.6f,%.6f,%s\n', ...
                dataRows{i,1}, dataRows{i,2}, dataRows{i,3}, dataRows{i,4}, dataRows{i,5});
        end
        fclose(fid);
    end
    
    % 保存Excel（包含角频率）
    excelFileName = '傅里叶系数_完整标注.xlsx';
    excelFullPath = fullfile(saveDir, excelFileName);
    try
        % 新增角频率说明
        explainText = {
            '傅里叶级数展开系数表（基于图片提取的物理坐标）';
            '展开公式：f(x) = a0/2 + Σ(an*cos(ωₙx) + bn*sin(ωₙx)) (n=1到N)';
            sprintf('参数说明：L = X轴物理范围 = %.6f', L);
            sprintf('         x0 = X轴最小值 = %.6f', x0);
            '         a0 = 0阶系数（直流分量系数），直流分量 = a0/2';
            '         an = 余弦项系数，bn = 正弦项系数（决定谐波成分）';
            '         ωₙ = 第n阶角频率 = 2πn/L（单位：1/物理坐标单位）';
            '';
        };
        xlswrite(excelFullPath, explainText, 1, 'A1');
        xlswrite(excelFullPath, tableContent, 1, 'A10');
        disp(['✅ Excel文件生成成功：', excelFullPath]);
    catch ME
        disp(['⚠️ Excel文件生成失败（原因：', ME.message, '），已生成CSV文件']);
    end
    
    if exist(csvFullPath, 'file')
        disp(['✅ CSV文件已生成：', csvFullPath]);
        if ispc; winopen(csvFullPath); end
    end
end

disp('程序执行完成！');