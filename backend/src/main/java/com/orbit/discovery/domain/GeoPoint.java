package com.orbit.discovery.domain;

/**
 * A WGS-84 position in degrees.
 *
 * @param lat latitude, -90..90
 * @param lng longitude, -180..180
 */
public record GeoPoint(double lat, double lng) {

  private static final double EARTH_RADIUS_METERS = 6_371_008.8;

  public GeoPoint {
    if (!Double.isFinite(lat) || lat < -90 || lat > 90) {
      throw new IllegalArgumentException("Latitude out of range");
    }
    if (!Double.isFinite(lng) || lng < -180 || lng > 180) {
      throw new IllegalArgumentException("Longitude out of range");
    }
  }

  /** Great-circle distance in metres (haversine). */
  public double metersTo(GeoPoint other) {
    double dLat = Math.toRadians(other.lat - lat);
    double dLng = Math.toRadians(other.lng - lng);
    double a =
        Math.pow(Math.sin(dLat / 2), 2)
            + Math.cos(Math.toRadians(lat))
                * Math.cos(Math.toRadians(other.lat))
                * Math.pow(Math.sin(dLng / 2), 2);
    return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(a)));
  }

  /** The point {@code meters} away along {@code bearingDegrees} (0 = north). */
  public GeoPoint offset(double bearingDegrees, double meters) {
    double angular = meters / EARTH_RADIUS_METERS;
    double bearing = Math.toRadians(bearingDegrees);
    double lat1 = Math.toRadians(lat);
    double lng1 = Math.toRadians(lng);
    double lat2 =
        Math.asin(
            Math.sin(lat1) * Math.cos(angular)
                + Math.cos(lat1) * Math.sin(angular) * Math.cos(bearing));
    double lng2 =
        lng1
            + Math.atan2(
                Math.sin(bearing) * Math.sin(angular) * Math.cos(lat1),
                Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2));
    double normalizedLng = ((Math.toDegrees(lng2) + 540) % 360) - 180;
    return new GeoPoint(Math.toDegrees(lat2), normalizedLng);
  }
}
