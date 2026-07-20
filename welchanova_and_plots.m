data = {C', LP', HP'};
groupNames = {'Control', 'LP', 'HP'};

% Combine for boxplot
allData = vertcat(data{:});
groupLabels = cellstr(repelem(groupNames, cellfun(@numel, data)));

%% --- Welch’s ANOVA ---
groupCount = numel(data);
ni = cellfun(@numel, data);  % group sizes
mi = cellfun(@mean, data);  % group means
vi = cellfun(@var, data);   % group variances

% Welch’s ANOVA test statistic
num = sum(ni .* (mi - mean(allData)).^2 ./ vi);
den = 1 + (2 * sum((1./(ni - 1)) .* (ni .* (vi ./ ni)).^2)) / ...
           (sum(ni .* vi ./ ni)^2);
df = (sum(ni .* vi ./ ni)^2) / sum(((vi ./ ni).^2) ./ (ni - 1));
Fstat = num / (groupCount - 1);
pWelch = 1 - fcdf(Fstat, groupCount - 1, df);

fprintf('Welch’s ANOVA results:\n');
fprintf('F-statistic: %.4f\n', Fstat);
fprintf('Degrees of freedom: %.2f\n', df);
fprintf('p-value: %.4f\n', pWelch);

%% --- Visualization ---
figure('Units', 'inches', 'Position', [1, 1, 1.5, 1.5]);

% Boxplot
h = boxplot(allData, groupLabels, ...
    'Colors', 'k', 'Whisker', 1.5);
hold on;
set(findobj(h, 'type', 'line'), 'LineWidth', 1.5);
set(gca, 'FontSize', 8, 'LineWidth', 1.5, 'TickLength', [0.025 0.025]);

% Add scatter
for i = 1:length(data)
    x = i + (rand(length(data{i}), 1) - 0.5) * 0.1;
    scatter(x, data{i}, 20, 'filled', ...
        'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 0.5);
end

ylabel('Value', 'FontSize', 9);
xlabel('Groups', 'FontSize', 9);
title('Box Plots with Welch''s ANOVA', 'FontSize', 10);

% Add dummy significance note if p < 0.05
rawMaxY = max(allData);
yOffset = 0.1 * rawMaxY;
if pWelch < 0.05
    text(2, rawMaxY + yOffset, '* Welch p < 0.05', ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end

ylim([min(allData) - 0.1 * rawMaxY, rawMaxY + 1.5 * yOffset]);
set(gcf, 'PaperPositionMode', 'auto');
set(gca, 'TickDir', 'out');
print('-dpng', '-r300', 'welch_boxplot.png');
hold off;