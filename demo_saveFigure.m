randseed(1); figure(1); clf;
N = 500; dx = randn(N, 1); dy = randn(N, 1);
h = plot(dx, dy, 'o', 'MarkerFaceColor', [0.6 0.6 1], 'LineWidth', 0.1, 'MarkerEdgeColor', 'w', 'MarkerSize', 8);
setMarkerOpacity(h, 0.5, 0.6);

xlabel('Param 1'); ylabel('Param 2'); title('SaveFigure Demo');
box off; axis equal;

saveFigure('demo.png')