const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

// 1. Wczytanie tokena:
// Wychodzimy z "js" (..), potem z "devtools" (..) i wchodzimy do "assets/config.json"
const configPath = path.join(__dirname, '..', '..', 'assets', 'config.json');
let MAPBOX_TOKEN = '';

try {
  const rawConfig = fs.readFileSync(configPath, 'utf-8');
  const config = JSON.parse(rawConfig);
  MAPBOX_TOKEN = config.mapbox_access_token;

  if (!MAPBOX_TOKEN) {
    throw new Error('Brak pola "mapbox_access_token" lub jest ono puste.');
  }
} catch (err) {
  console.error(`Błąd wczytywania konfiguracji z ${configPath}:`);
  console.error(err.message);
  process.exit(1); // Zatrzymaj serwer, jeśli nie udało się pobrać tokena
}

// 2. Wczytanie HTML i skryptu klienta
const htmlPath = path.join(__dirname, 'mapsandbox.html');
const clientScriptPath = path.join(__dirname, 'mapsandbox-client.js');
let htmlContent;
let clientScriptTemplate;

try {
  htmlContent = fs.readFileSync(htmlPath, 'utf-8');
  clientScriptTemplate = fs.readFileSync(clientScriptPath, 'utf-8');
} catch (err) {
  console.error('Błąd wczytywania plików sandboxa:');
  console.error(err.message);
  process.exit(1);
}

const tokenPlaceholder = '__MAPBOX_ACCESS_TOKEN__';
if (!clientScriptTemplate.includes(tokenPlaceholder)) {
  console.error(`Nie znaleziono placeholdera ${tokenPlaceholder} w ${clientScriptPath}.`);
  process.exit(1);
}

// 3. Uruchomienie serwera HTTP
const server = http.createServer((req, res) => {
  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(htmlContent);
  } else if (req.url === '/mapsandbox-client.js') {
    const clientScript = clientScriptTemplate.replace(
      tokenPlaceholder,
      JSON.stringify(MAPBOX_TOKEN),
    );
    res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
    res.end(clientScript);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 - Nie znaleziono strony');
  }
});

server.listen(PORT, () => {
  console.log('Token wczytany poprawnie z assets/config.json');
  console.log(`Serwer działa pod adresem: http://localhost:${PORT}`);
});