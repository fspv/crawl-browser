const testPages = {
  // Simple HTML page for basic tests
  simple: `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Test Page</title>
      </head>
      <body>
        <h1>Test Content</h1>
        <p class="content">This is a test paragraph.</p>
        <div id="dynamic"></div>
      </body>
    </html>
  `,
  
  // Page with ads simulation
  withAds: `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Page with Ads</title>
      </head>
      <body>
        <div class="ad-banner" data-ad-provider="doubleclick">
          <script src="https://doubleclick.net/ad.js"></script>
        </div>
        <article>
          <h1>Main Article</h1>
          <p>This is the main content that should be extracted.</p>
        </article>
        <div class="sidebar-ad">
          <iframe src="https://adsystem.com/banner"></iframe>
        </div>
      </body>
    </html>
  `,
  
  // Page with cookie banner
  withCookieBanner: `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Page with Cookie Banner</title>
      </head>
      <body>
        <div id="cookie-consent" style="position: fixed; bottom: 0; width: 100%; background: #000; color: #fff; padding: 20px;">
          <p>We use cookies to improve your experience.</p>
          <button id="accept-cookies">Accept</button>
        </div>
        <main>
          <h1>Main Content</h1>
          <p>This content should be accessible without accepting cookies.</p>
        </main>
      </body>
    </html>
  `,
  
  // Page with paywall
  withPaywall: `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Premium Content</title>
      </head>
      <body>
        <article>
          <h1>Premium Article</h1>
          <p class="preview">This is the preview text...</p>
          <div class="paywall-overlay" style="position: fixed; top: 50%; left: 0; right: 0; bottom: 0; background: rgba(255,255,255,0.95);">
            <div class="paywall-message">
              <h2>Subscribe to continue reading</h2>
              <button>Subscribe Now</button>
            </div>
          </div>
          <p class="premium-content" style="display: none;">This is the full article content that should be accessible.</p>
        </article>
      </body>
    </html>
  `,
  
  // Dynamic JavaScript content
  dynamic: `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Dynamic Page</title>
        <script>
          window.addEventListener('load', () => {
            setTimeout(() => {
              document.getElementById('content').innerHTML = '<p>Dynamically loaded content</p>';
            }, 1000);
          });
        </script>
      </head>
      <body>
        <h1>Dynamic Content Test</h1>
        <div id="content">Loading...</div>
      </body>
    </html>
  `
};

const testUrls = {
  // Known good test URLs
  example: 'https://example.com',
  httpBin: 'https://httpbin.org',
  
  // URLs for specific test scenarios
  redirect: 'https://httpbin.org/redirect/2',
  status404: 'https://httpbin.org/status/404',
  status500: 'https://httpbin.org/status/500',
  delay: 'https://httpbin.org/delay/5',
  
  // Sites with known behaviors (use carefully in tests)
  newsWithPaywall: 'https://www.wsj.com',
  siteWithAds: 'https://www.cnn.com',
  siteWithCookies: 'https://www.theguardian.com'
};

module.exports = {
  testPages,
  testUrls
};