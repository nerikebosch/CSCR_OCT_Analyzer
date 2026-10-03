% =========================================================================
% FAKE DATA GENERATION FOR TEMPORAL CONTRAST RATIO PLOT
% =========================================================================

% 1. Setup the X-axis (22 Visits)
visits = 1:22;

% 2. Generate Fake Contrast Ratio (CR) Data
% We want it to dip into the red zone around visits 1, 15, and 22.
% We want it in the green zone around visit 8.
fake_CR = [
    0.62; 0.75; 0.88; 0.92; 0.98; 1.02; 1.08; 1.05; % Visit 1 (Active) -> Visit 8 (Remission)
    1.03; 0.95; 0.88; 0.82; 0.78; 0.68; 0.60;       % Visit 8 -> Visit 15 (Active)
    0.72; 0.85; 0.91; 0.88; 0.75; 0.65; 0.58        % Visit 15 -> Visit 22 (Active)
];

% Identify which visits are clinically "Active" (based on your table)
active_visits = [1, 15, 22];
active_CR = fake_CR(active_visits);

% =========================================================================
% PLOTTING
% =========================================================================
figure('Position', [100, 100, 800, 400]);
hold on;

% 3. Draw Background Color Bands using 'patch'
x_patch = [0, 23, 23, 0];

% Red Band (Active Flare-up: ~0.4 to 0.75)
patch(x_patch, [0.4, 0.4, 0.75, 0.75], [1 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

% Yellow Band (Pre-recurrence: 0.75 to 0.95)
patch(x_patch, [0.75, 0.75, 0.95, 0.95], [1 1 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

% Green Band (Remission: 0.95 to 1.2)
patch(x_patch, [0.95, 0.95, 1.2, 1.2], [0.8 1 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

% 4. Plot the Main Data Line
plot(visits, fake_CR, 'o--', 'Color', [0.2 0.2 0.6], 'LineWidth', 1.5, ...
    'MarkerSize', 6, 'MarkerFaceColor', [0.6 0.6 0.8]);

% 5. Plot the Red Markers for Active Recurrences
plot(active_visits, active_CR, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

% =========================================================================
% FORMATTING
% =========================================================================
title('Temporal Evolution of Localized RPE Contrast Ratio');
xlabel('Clinical Visit Number');
ylabel('Contrast Ratio (\sigma / \mu)');

% Set axis limits
xlim([0 23]);
ylim([0.4 1.2]);

% Adjust X-ticks to show all visits
xticks(1:22);

% Add a legend
legend({'Active Zone', 'Pre-recurrence Zone', 'Remission Zone', ...
    'CR Measurement', 'Clinical Recurrence'}, 'Location', 'southwest');

box on;
grid on;
hold off;