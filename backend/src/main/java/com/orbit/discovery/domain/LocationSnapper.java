package com.orbit.discovery.domain;

import com.uber.h3core.H3Core;
import com.uber.h3core.util.LatLng;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.UUID;

/**
 * Turns an exact position into the only position Orbit stores (ADR-0003): the centre of the H3
 * resolution-8 cell (about 0.7 km²) plus a stable per-member offset. The offset is the same on
 * every update, so averaging many readings never converges on the cell centre or the real spot.
 */
public final class LocationSnapper {

  /** H3 resolution 8: average cell edge ~460 m. */
  public static final int RESOLUTION = 8;

  private static final double MIN_OFFSET_METERS = 60;
  private static final double OFFSET_SPAN_METERS = 240;

  private final H3Core h3;

  public LocationSnapper() {
    try {
      this.h3 = H3Core.newInstance();
    } catch (IOException e) {
      throw new UncheckedIOException("Could not load the H3 native library", e);
    }
  }

  /** The snapped point and its cell for {@code memberId} at {@code exact}. */
  public Snapped snap(UUID memberId, GeoPoint exact) {
    long cell = h3.latLngToCell(exact.lat(), exact.lng(), RESOLUTION);
    LatLng centre = h3.cellToLatLng(cell);
    double bearing = Math.floorMod(memberId.getMostSignificantBits(), 360L);
    double distance =
        MIN_OFFSET_METERS
            + Math.floorMod(memberId.getLeastSignificantBits(), (long) OFFSET_SPAN_METERS);
    GeoPoint point = new GeoPoint(centre.lat, centre.lng).offset(bearing, distance);
    return new Snapped(point, h3.h3ToString(cell));
  }

  /**
   * A stored location.
   *
   * @param point snapped position
   * @param cell H3 cell address
   */
  public record Snapped(GeoPoint point, String cell) {}
}
