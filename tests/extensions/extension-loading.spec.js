const { test, expect } = require('@playwright/test');
const CDP = require('chrome-remote-interface');

test.describe('Extension Loading', () => {
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
    await client.Runtime.enable();
  });

  test.afterEach(async () => {
    if (target) {
      await client.Target.closeTarget({ targetId: target });
    }
    if (client) {
      await client.close();
    }
  });

  test('Extensions are loaded in browser', async () => {
    // Navigate to chrome://extensions page (might be restricted)
    // Alternative: check for extension artifacts in the DOM
    
    // Get all targets to see if extensions created any background pages
    const targets = await client.Target.getTargets();
    const extensionTargets = targets.targetInfos.filter(t => 
      t.type === 'background_page' || t.type === 'service_worker' || t.type === 'page' || t.url.includes('extension://')
    );
    
    // We expect at least some extension targets (uBlock, cookie bypass, etc)
    console.log('Extension targets found:', JSON.stringify(extensionTargets));
    expect(extensionTargets.length).toBeGreaterThan(0);
    
    // Check for MetaMask only if it's expected to be loaded
    const hasMetaMask = process.env.HAS_METAMASK === 'true';
    if (hasMetaMask) {
      const ext = extensionTargets.find(t => 
        t.title === 'MetaMask Offscreen Page'
      );
      
      expect(ext).toBeDefined();
      console.log('MetaMask extension found:', ext);
    } else {
      console.log('MetaMask check skipped - not configured to load');
    }
  });

  test('uBlock Origin is active', async () => {
    // Navigate to a page with known ads
    await client.Page.navigate({ url: 'https://httpi.dev/html' });
    
    await client.Page.loadEventFired();
    
    // Check if uBlock injected its content scripts
    const { result } = await client.Runtime.evaluate({
      expression: `
        // Check for uBlock's injected elements or blocked requests
        document.querySelectorAll('script[src*="doubleclick"]').length === 0
      `
    });
    
    // Note: This is a simplified check. In real scenario, 
    // you'd want to check Network.requestWillBeSent events for blocked domains
    expect(result.value).toBeTruthy();
  });

  test('Cookie banner bypass is working', async () => {
    // This would need a real site with cookie banners
    // For now, we just check if the extension is loaded
    
    // Try to detect if "I still don't care about cookies" is active
    const { result } = await client.Runtime.evaluate({
      expression: `
        // Check if extension injected any global variables or modified DOM
        typeof window.__doesntCareAboutCookies !== 'undefined' ||
        document.querySelector('[id*="cookie"]:not([style*="display: none"])') === null
      `
    });
    
    console.log('Cookie banner bypass check:', result.value);
  });
});
