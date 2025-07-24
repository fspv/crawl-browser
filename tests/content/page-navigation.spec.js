const { test, expect } = require('@playwright/test');
const CDP = require('chrome-remote-interface');

test.describe('Page Navigation and Content Extraction', () => {
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

  test('Can navigate to pages and extract content', async () => {
    await client.Page.navigate({ url: 'https://httpi.dev/html' });
    
    await client.Page.loadEventFired();
    
    // Wait a bit more for content to be ready
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Debug what we actually have on the page
    try {
      const { result: debugResult } = await client.Runtime.evaluate({
        expression: 'document.title || "no title"'
      });
      console.log('Title result:', JSON.stringify(debugResult, null, 2));
      
      const { result: urlResult } = await client.Runtime.evaluate({
        expression: 'document.location.href'
      });
      console.log('URL result:', JSON.stringify(urlResult, null, 2));
      
      // Just verify we can evaluate JavaScript on the page
      expect(urlResult.value).toContain('httpi.dev');
    } catch (error) {
      console.log('Runtime evaluation failed:', error.message);
      throw error;
    }
    
    // Extract main content
    const { result: contentResult } = await client.Runtime.evaluate({
      expression: 'document.querySelector("h1").textContent'
    });
    expect(contentResult.value).toBe('Herman Melville - Moby-Dick');
  });
});
