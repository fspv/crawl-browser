const { waitForChrome } = require('./utils/wait-for-chrome');

async function globalSetup() {
  console.log('🚀 Starting global test setup...');
  
  // Wait for Chrome to be fully ready
  await waitForChrome({
    host: 'crawl-browser', 
    port: 9222,
    timeout: 60000,
    retryInterval: 2000
  });
  
  console.log('✅ Chrome is ready, tests can start!');
}

module.exports = globalSetup;