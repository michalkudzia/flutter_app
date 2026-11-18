fetch('/mapbox-config.json')
  .then((response) => {
    if (!response.ok) {
      throw new Error(`Pobranie konfiguracji Mapbox nie powiodło się: HTTP ${response.status}`);
    }

    return response.json();
  })
  .then(({ mapboxAccessToken }) => {
    if (!mapboxAccessToken) {
      throw new Error('Brak tokena Mapbox w konfiguracji.');
    }

    const MAPBOX_TOKEN = mapboxAccessToken;
    mapboxgl.accessToken = MAPBOX_TOKEN;

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
      document.getElementById('coords').textContent = `Lng: ${lng}, Lat: ${lat}`;
    });
  })
  .catch((error) => {
    console.error('Nie udało się zainicjalizować mapy Mapbox:', error);
  });
