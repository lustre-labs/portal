export function setup_map(selector) {
  const container = document.querySelector(selector);
  const map = leaflet.map(container);

  map.setView([0, 0], 1);
  leaflet
    .tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "© OpenStreetMap",
    })
    .addTo(map);

  return map;
}

export function add_marker(map, lat, lon) {
  const container = document.createElement("div");

  // Add a data attribute to the container so the portal can find it later
  container.setAttribute("data-marker-id", `${lat}-${lon}`);

  // Create an empty popup using the container we just created.
  leaflet
    .popup({ minWidth: 150 })
    .setLatLng([lat, lon])
    .setContent(container)
    .openOn(map);

  map.setView([lat, lon], 10);
}
