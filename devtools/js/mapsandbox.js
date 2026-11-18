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

// 2. Szablon HTML z wstrzykniętym tokenem
const htmlContent = `<!DOCTYPE html>
<html lang="pl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Mapbox Sandbox</title>
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.css" rel="stylesheet" />
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.8.0/mapbox-gl.js"></script>
  <style>
    body { margin: 0; padding: 0; font-family: system-ui, sans-serif; }
    #map { position: absolute; top: 0; bottom: 0; width: 100%; }
    .info-panel {
      position: absolute;
      top: 12px;
      left: 12px;
      z-index: 1;
      background: rgba(255, 255, 255, 0.92);
      padding: 10px 14px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.15);
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="info-panel">
    <strong>Mapbox Sandbox</strong><br />
    Kliknij dowolne miejsce na mapie, aby odczytać współrzędne.
    <div id="coords" style="margin-top: 4px; color: #0066cc; font-weight: 600;"></div>
  </div>
  <div id="map"></div>

  <script>
    mapboxgl.accessToken = '${MAPBOX_TOKEN}';

    const map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [21.0122, 52.2297],
      zoom: 12,
      pitch: 30
    });

    map.addControl(new mapboxgl.NavigationControl(), 'top-right');

    map.once('load', () => {
      const center = map.getCenter();
      const pointA = [center.lng - 0.5, center.lat - 0.5];
      const pointB = [center.lng + 0.5, center.lat + 0.5];

      map.addSource('ab-line', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [pointA, pointB]
          },
          properties: {}
        }
      });

      map.addLayer({
        id: 'ab-line',
        type: 'line',
        source: 'ab-line',
        paint: {
          'line-color': '#0066cc',
          'line-width': 4
        }
      });

      new mapboxgl.Marker({ color: '#2a9d8f' })
        .setLngLat(pointA)
        .setPopup(new mapboxgl.Popup().setText('Punkt A'))
        .addTo(map);

      new mapboxgl.Marker({ color: '#e76f51' })
        .setLngLat(pointB)
        .setPopup(new mapboxgl.Popup().setText('Punkt B'))
        .addTo(map);

      map.fitBounds([pointA, pointB], { padding: 80, maxZoom: 12, duration: 0 });
    });

    new mapboxgl.Marker({ color: '#e63946' })
      .setLngLat([21.0067, 52.2318])
      .setPopup(new mapboxgl.Popup().setHTML('<h4>Punkt startowy</h4><p>Token wczytany z assets/config.json</p>'))
      .addTo(map);

    map.on('click', (e) => {
      const lng = e.lngLat.lng.toFixed(5);
      const lat = e.lngLat.lat.toFixed(5);
      document.getElementById('coords').textContent = \`Lng: \${lng}, Lat: \${lat}\`;
    });
  </script>
</body>
</html>`;

// 3. Uruchomienie serwera HTTP
const server = http.createServer((req, res) => {
  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(htmlContent);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 - Nie znaleziono strony');
  }
});

server.listen(PORT, () => {
  console.log('Token wczytany poprawnie z assets/config.json');
  console.log(`Serwer działa pod adresem: http://localhost:${PORT}`);
});