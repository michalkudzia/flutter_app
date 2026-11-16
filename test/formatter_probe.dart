void probe() async {
      await mapboxMap.addLayer(
        SymbolLayer(
          id: "marker-layer",
          sourceId: "marker-source",
          iconImage: "custom-icon-id", // Ensure this image is loaded in the style
        ),
      );

      await mapboxMap.addLayer(SymbolLayer(id: "marker-layer", sourceId: "marker-source", iconImage: "custom-icon-id"));

      // Ensure this image is loaded in the style
      await mapboxMap.addLayer(SymbolLayer(id: "marker-layer", sourceId: "marker-source", iconImage: "custom-icon-id"));
}
