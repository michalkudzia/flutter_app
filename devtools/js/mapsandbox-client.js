const MAPBOX_TOKEN = __MAPBOX_ACCESS_TOKEN__;
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

  const dx = pointB[0] - pointA[0];
  const dy = pointB[1] - pointA[1];
  const length = Math.hypot(dx, dy);
  const ux = dx / length;
  const uy = dy / length;
  const headLength = length * 0.08;
  const wingWidth = headLength * 0.55;
  const base = [
    pointB[0] - ux * headLength,
    pointB[1] - uy * headLength
  ];
  const wingA = [base[0] - uy * wingWidth, base[1] + ux * wingWidth];
  const wingB = [base[0] + uy * wingWidth, base[1] - ux * wingWidth];

  map.addSource('ab-arrowhead', {
    type: 'geojson',
    data: {
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: [wingA, pointB, wingB]
      },
      properties: {}
    }
  });

  map.addLayer({
    id: 'ab-arrowhead',
    type: 'line',
    source: 'ab-arrowhead',
    layout: {
      'line-cap': 'round',
      'line-join': 'round'
    },
    paint: {
      'line-color': '#0066cc',
      'line-width': 5
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
  .setPopup(new mapboxgl.Popup().setHTML('<h4>Punkt startowy</h4><p>Token wczytany z konfiguracji serwera</p>'))
  .addTo(map);

map.on('click', (e) => {
  const lng = e.lngLat.lng.toFixed(5);
  const lat = e.lngLat.lat.toFixed(5);
  document.getElementById('coords').textContent = `Lng: ${lng}, Lat: ${lat}`;
});
