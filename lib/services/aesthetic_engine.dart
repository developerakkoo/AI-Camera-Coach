class AestheticEngine {
  int calculate({
    required int framing,
    required int lighting,
    required int eye,
    required int jaw,
    required int background,
  }) {
    return (
      framing * 0.3 +
      lighting * 0.25 +
      eye * 0.15 +
      jaw * 0.15 +
      background * 0.15
    ).toInt();
  }
}