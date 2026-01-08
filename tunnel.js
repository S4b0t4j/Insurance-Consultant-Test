const localtunnel = require('localtunnel');

(async () => {
  console.log('Starting tunnel...');
  try {
    const tunnel = await localtunnel({
      port: 3000,
      allow_invalid_cert: true
    });

    console.log('\n');
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║                                                            ║');
    console.log('║   🌐 YOUR PUBLIC URL:                                      ║');
    console.log('║                                                            ║');
    console.log('║   ' + tunnel.url.padEnd(55) + '║');
    console.log('║                                                            ║');
    console.log('║   Share this link to access D&W Holdings from anywhere!    ║');
    console.log('║                                                            ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('\n');
    console.log('NOTE: First visit may show a confirmation page - click Continue');
    console.log('Keep this terminal open to maintain the connection.\n');

    tunnel.on('close', () => {
      console.log('Tunnel closed');
      process.exit(0);
    });

    tunnel.on('error', (err) => {
      console.error('Tunnel error:', err);
    });

  } catch (err) {
    console.error('Failed to create tunnel:', err.message);
    process.exit(1);
  }
})();
