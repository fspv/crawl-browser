const CDP = require('chrome-remote-interface');

async function waitForChrome(options = {}) {
  const {
    host = 'crawl-browser',
    port = 9222,
    timeout = 60000,
    retryInterval = 2000
  } = options;

  const startTime = Date.now();
  let lastError;

  while (Date.now() - startTime < timeout) {
    try {
      // Try to connect to Chrome
      const client = await CDP({ host, port });
      
      // Try to get browser version to ensure it's fully ready
      const version = await client.Browser.getVersion();
      
      // Try to create a target to ensure Chrome can handle requests
      const { targetId } = await client.Target.createTarget({ url: 'about:blank' });
      await client.Target.closeTarget({ targetId });
      
      await client.close();
      
      // The version object contains properties like Browser, Protocol-Version, User-Agent, etc.
      console.log(`Chrome is ready! Version info:`, JSON.stringify(version, null, 2));
      return true;
      
    } catch (error) {
      lastError = error;
      console.log(`Waiting for Chrome... (${error.message})`);
      
      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, retryInterval));
    }
  }
  
  throw new Error(`Chrome not ready after ${timeout}ms. Last error: ${lastError.message}`);
}

module.exports = { waitForChrome };