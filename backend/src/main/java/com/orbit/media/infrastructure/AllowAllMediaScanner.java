package com.orbit.media.infrastructure;

import com.orbit.media.MediaApi.Kind;
import com.orbit.media.application.MediaScanner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Stand-in until a scanning vendor is chosen: allows everything and says so once at startup. A
 * vendor-backed {@link MediaScanner} bean replaces it. Must be replaced before launch.
 */
class AllowAllMediaScanner implements MediaScanner {

  private static final Logger log = LoggerFactory.getLogger(AllowAllMediaScanner.class);

  AllowAllMediaScanner() {
    log.warn("No media scanner configured: uploads are not checked for illegal content");
  }

  @Override
  public Verdict scan(Kind kind, byte[] content) {
    return Verdict.CLEAN;
  }
}
