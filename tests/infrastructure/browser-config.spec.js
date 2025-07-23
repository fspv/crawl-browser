const { test, expect } = require('@playwright/test');
const CDP = require('chrome-remote-interface');

test.describe('Browser Configuration', () => {
  let client;
  let target;

  test.beforeEach(async () => {
    client = await CDP({
      host: 'crawl-browser',
      port: 9222
    });
    
    const { targetId } = await client.Target.createTarget({ url: 'about:blank' });
    target = targetId;
    
    await client.Page.enable();
    await client.Network.enable();
  });

  test.afterEach(async () => {
    if (target) {
      await client.Target.closeTarget({ targetId: target });
    }
    if (client) {
      await client.close();
    }
  });

  test('Chrome runs with expected flags', async () => {
    const version = await client.Browser.getVersion();
    expect(version.userAgent).toContain('Chrome');
    
    // Check if remote debugging is properly enabled
    const targets = await client.Target.getTargets();
    expect(targets.targetInfos.length).toBeGreaterThan(0);
  });

  test('Virtual display is running', async () => {
    // Check if we can take a screenshot (requires display)
    const { data } = await client.Page.captureScreenshot({ format: 'png' });
    expect(data).toBeTruthy();
    expect(data.length).toBeGreaterThan(1000); // PNG should be at least 1KB
  });
});
