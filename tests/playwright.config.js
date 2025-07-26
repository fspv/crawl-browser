const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: '.',
  globalSetup: require.resolve('./global-setup.js'),
  fullyParallel: false, // Run all tests sequentially to avoid CDP connection limits
  forbidOnly: !!process.env.CI,
  retries: 2,
  workers: 1, // Force sequential execution to avoid CDP connection conflicts
  reporter: [
    ['html', { outputFolder: '/app/test-results/reports', open: 'never' }],
    ['json', { outputFile: '/app/test-results/results.json' }],
    ['line', { printSteps: true }]
  ],

  timeout: 120000, // Set default test timeout to 120 seconds

  use: {
    baseURL: process.env.CDP_ENDPOINT || 'http://localhost:9222',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'infrastructure',
      testDir: './infrastructure',
      testMatch: '**/*.spec.js',
    },
    {
      name: 'content',
      testDir: './content',
      testMatch: '**/*.spec.js',
    },
    {
      name: 'extensions',
      testDir: './extensions',
      testMatch: '**/*.spec.js',
    },
  ],

  outputDir: '/app/test-results/test-artifacts',
});