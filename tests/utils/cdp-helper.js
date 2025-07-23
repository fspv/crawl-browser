const CDP = require('chrome-remote-interface');

class CDPHelper {
  constructor(host = 'crawl-browser', port = 9222) {
    this.host = host;
    this.port = port;
    this.client = null;
    this.target = null;
  }

  async connect() {
    this.client = await CDP({
      host: this.host,
      port: this.port
    });
    
    return this.client;
  }

  async createPage(url = 'about:blank') {
    if (!this.client) {
      await this.connect();
    }
    
    const { targetId } = await this.client.Target.createTarget({ url });
    this.target = targetId;
    
    // Enable commonly used domains
    await this.client.Page.enable();
    await this.client.Network.enable();
    await this.client.Runtime.enable();
    
    return targetId;
  }

  async navigateTo(url, options = {}) {
    const defaultOptions = {
      timeout: 10000,
      waitUntil: 'load'
    };
    
    const finalOptions = { ...defaultOptions, ...options };
    
    await this.client.Page.navigate({ url });
    
    if (finalOptions.waitUntil === 'load') {
      await this.client.Page.loadEventFired();
    } else if (finalOptions.waitUntil === 'domcontentloaded') {
      await this.client.Page.domContentEventFired();
    }
  }

  async evaluate(expression) {
    const { result, exceptionDetails } = await this.client.Runtime.evaluate({
      expression,
      returnByValue: true
    });
    
    if (exceptionDetails) {
      throw new Error(`Evaluation failed: ${exceptionDetails.text}`);
    }
    
    return result.value;
  }

  async waitForSelector(selector, timeout = 3000) {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
      const exists = await this.evaluate(`
        document.querySelector('${selector}') !== null
      `);
      
      if (exists) {
        return true;
      }
      
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    throw new Error(`Timeout waiting for selector: ${selector}`);
  }

  async screenshot(options = {}) {
    const defaultOptions = {
      format: 'png',
      quality: 80,
      fullPage: false
    };
    
    const finalOptions = { ...defaultOptions, ...options };
    
    const { data } = await this.client.Page.captureScreenshot(finalOptions);
    return Buffer.from(data, 'base64');
  }

  async getNetworkRequests() {
    const requests = [];
    
    this.client.Network.requestWillBeSent((params) => {
      requests.push({
        url: params.request.url,
        method: params.request.method,
        headers: params.request.headers,
        timestamp: params.timestamp
      });
    });
    
    return requests;
  }

  async cleanup() {
    if (this.target) {
      await this.client.Target.closeTarget({ targetId: this.target });
      this.target = null;
    }
    
    if (this.client) {
      await this.client.close();
      this.client = null;
    }
  }
}

module.exports = CDPHelper;