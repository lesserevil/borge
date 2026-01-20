/* Phone‑side JavaScript that runs inside the Pebble WebView.
   It fetches the song list from the tablet server running on the host
   and forwards a tiny message to the Pebble watch.
   Adjust the HOST variable if you need to use a different address
   (e.g., 10.0.2.2 when running inside the Android emulator).
*/

(() => {
  // ----------------------------------------------------------------------
  // Configuration
  // ----------------------------------------------------------------------
  // Change this if you need to use a different host/IP.
  // For the Android emulator, use '10.0.2.2'.
  // For a direct connection on the host machine, use 'localhost'.
  const HOST = 'localhost';   // <-- change to 10.0.2.2 if running inside the emulator

  // ----------------------------------------------------------------------
  // Helper: fetch the song list from the tablet server
  // ----------------------------------------------------------------------
  async function fetchSongs() {
    try {
      const response = await fetch(`http://${HOST}:3000/songs`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const songs = await response.json();   // expected: [{id, title, artist}, ...]
      // Extract a small identifier to send to the watch (keep it < 2 KB)
      const tinyMsg = { nowPlaying: songs[0] ? songs[0].id : 'default' };
      return tinyMsg;
    } catch (err) {
      console.error('❌ Failed to fetch songs from tablet:', err);
      throw err;
    }
  }

  // ----------------------------------------------------------------------
  // Send the message to the Pebble watch
  // ----------------------------------------------------------------------
  function sendToWatch(msg) {
    Pebble.sendAppMessage(msg, (e) => {
      if (e.status === 'sent') {
        console.log('✅ Message sent to watch');
      } else {
        console.error('❌ Failed to send message:', e.error);
      }
    });
  }

  // ----------------------------------------------------------------------
  // Main flow
  // ----------------------------------------------------------------------
  async function start() {
    try {
      const msg = await fetchSongs();
      sendToWatch(msg);
    } catch (err) {
      console.error('❌ Unexpected error in start():', err);
    }
  }

  // Run as soon as the Pebble runtime is ready
  Pebble.addEventListener('ready', start);
})();