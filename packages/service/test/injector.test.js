// Test for the Vite CLI injector
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const viteBin = path.join(process.cwd(), 'node_modules', 'vite', 'bin', 'vite.js');
const marker = 'console-inline injected';

describe('Vite CLI Injector', () => {
  it('should inject the vite-hook require into vite.js', () => {
    if (!fs.existsSync(viteBin)) {
      throw new Error('Vite CLI not found for test');
    }
    const content = fs.readFileSync(viteBin, 'utf8');
    assert(content.includes(marker), 'vite-hook was not injected');
  });
});
