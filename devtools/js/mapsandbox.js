const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.MAP_SANDBOX_PORT || 3000);

if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
  console.error(`Nieprawidłowy port "${process.env.MAP_SANDBOX_PORT}". Ustaw MAP_SANDBOX_PORT na liczbę od 1 do 65535.`);
  process.exit(1);
}

// 1. Wczytanie tokena z konfiguracji serwera sandboxa
const configPath = path.join(__dirname, 'config.json');
let mapboxAccessToken = '';

try {
  const rawConfig = fs.readFileSync(configPath, 'utf-8');
  const config = JSON.parse(rawConfig);
  mapboxAccessToken = config.mapbox_access_token;

  if (!mapboxAccessToken) {
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
      JSON.stringify(mapboxAccessToken),
    );
    res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
    res.end(clientScript);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 - Nie znaleziono strony');
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} jest już zajęty. Zatrzymaj poprzedni serwer sandboxa albo ustaw MAP_SANDBOX_PORT na inny port.`);
    process.exitCode = 1;
    return;
  }

  console.error('Nie udało się uruchomić serwera HTTP:');
  console.error(err);
  process.exitCode = 1;
});

server.listen(PORT, () => {
  console.log('Token wczytany poprawnie z devtools/js/config.json');
  console.log(`Serwer działa pod adresem: http://localhost:${PORT}`);
});