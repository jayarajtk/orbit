package com.orbit.discovery.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class LocationRulesTest {

  private static final GeoPoint SAN_FRANCISCO = new GeoPoint(37.7749, -122.4194);

  @Nested
  class Buckets {

    @ParameterizedTest(name = "{0} m -> {1}")
    @CsvSource({"0, 0", "999, 0", "1000, 1", "1999, 1", "9999, 9", "10000, 10", "10001, 11"})
    void bucketsDistances(double meters, int bucket) {
      assertThat(DistanceBucket.of(meters)).isEqualTo(bucket);
    }
  }

  @Nested
  class Points {

    @Test
    void rejectsOutOfRangeCoordinates() {
      assertThatThrownBy(() -> new GeoPoint(91, 0)).isInstanceOf(IllegalArgumentException.class);
      assertThatThrownBy(() -> new GeoPoint(0, 181)).isInstanceOf(IllegalArgumentException.class);
      assertThatThrownBy(() -> new GeoPoint(Double.NaN, 0))
          .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void offsetMovesTheRequestedDistance() {
      GeoPoint moved = SAN_FRANCISCO.offset(90, 1_000);
      assertThat(SAN_FRANCISCO.metersTo(moved)).isBetween(999.0, 1_001.0);
    }
  }

  @Nested
  class Snapping {

    private final LocationSnapper snapper = new LocationSnapper();

    @Test
    void neverStoresTheExactPositionButStaysNearby() {
      UUID member = UUID.randomUUID();
      LocationSnapper.Snapped snapped = snapper.snap(member, SAN_FRANCISCO);

      assertThat(snapped.point()).isNotEqualTo(SAN_FRANCISCO);
      assertThat(SAN_FRANCISCO.metersTo(snapped.point())).isLessThan(1_000);
    }

    @Test
    void isStableForAMemberSoAveragingDoesNotRevealTheCellCentre() {
      UUID member = UUID.randomUUID();
      GeoPoint nearby = SAN_FRANCISCO.offset(10, 20);

      assertThat(snapper.snap(member, SAN_FRANCISCO).point())
          .isEqualTo(snapper.snap(member, nearby).point());
    }

    @Test
    void differsBetweenMembersInTheSameCell() {
      UUID a = new UUID(1, 1);
      UUID b = new UUID(200, 77);

      assertThat(snapper.snap(a, SAN_FRANCISCO).cell())
          .isEqualTo(snapper.snap(b, SAN_FRANCISCO).cell());
      assertThat(snapper.snap(a, SAN_FRANCISCO).point())
          .isNotEqualTo(snapper.snap(b, SAN_FRANCISCO).point());
    }
  }
}
