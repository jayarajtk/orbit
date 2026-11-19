package com.orbit.media.application;

import java.awt.image.BufferedImage;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * Reads the EXIF orientation tag (0x0112) from a JPEG and applies it to pixels. Reads only the
 * first IFD of the APP1 segment; anything malformed or missing counts as "already upright".
 */
final class ExifOrientation {

  /** Pixels are stored upright. */
  static final int UPRIGHT = 1;

  private static final int ORIENTATION_TAG = 0x0112;
  private static final int SHORT_TYPE = 3;
  private static final int IFD_ENTRY_BYTES = 12;
  private static final int MARKER_PREFIX = 0xFF;
  private static final int APP1 = 0xE1;
  private static final int START_OF_SCAN = 0xDA;
  private static final byte[] EXIF_HEADER = "Exif\0\0".getBytes(StandardCharsets.US_ASCII);

  private ExifOrientation() {}

  /** The orientation (1–8) recorded in {@code jpeg}, or {@link #UPRIGHT}. */
  static int read(byte[] jpeg) {
    if (jpeg.length < 4 || (jpeg[0] & 0xFF) != 0xFF || (jpeg[1] & 0xFF) != 0xD8) {
      return UPRIGHT;
    }
    int offset = 2;
    while (offset + 4 <= jpeg.length) {
      if ((jpeg[offset] & 0xFF) != MARKER_PREFIX) {
        return UPRIGHT;
      }
      int marker = jpeg[offset + 1] & 0xFF;
      if (marker == START_OF_SCAN) {
        return UPRIGHT;
      }
      int length = ((jpeg[offset + 2] & 0xFF) << 8) | (jpeg[offset + 3] & 0xFF);
      int segment = offset + 4;
      int end = offset + 2 + length;
      if (length < 2 || end > jpeg.length) {
        return UPRIGHT;
      }
      if (marker == APP1 && startsWith(jpeg, segment, end, EXIF_HEADER)) {
        return fromTiff(jpeg, segment + EXIF_HEADER.length, end);
      }
      offset = end;
    }
    return UPRIGHT;
  }

  private static int fromTiff(byte[] bytes, int start, int end) {
    if (end - start < 8) {
      return UPRIGHT;
    }
    ByteBuffer tiff = ByteBuffer.wrap(bytes, start, end - start).slice();
    if (bytes[start] == 'I' && bytes[start + 1] == 'I') {
      tiff.order(ByteOrder.LITTLE_ENDIAN);
    } else if (bytes[start] == 'M' && bytes[start + 1] == 'M') {
      tiff.order(ByteOrder.BIG_ENDIAN);
    } else {
      return UPRIGHT;
    }
    long ifd = Integer.toUnsignedLong(tiff.getInt(4));
    if (ifd + 2 > tiff.limit()) {
      return UPRIGHT;
    }
    int entries = Short.toUnsignedInt(tiff.getShort((int) ifd));
    for (int i = 0; i < entries; i++) {
      int entry = (int) ifd + 2 + i * IFD_ENTRY_BYTES;
      if (entry + IFD_ENTRY_BYTES > tiff.limit()) {
        return UPRIGHT;
      }
      if (Short.toUnsignedInt(tiff.getShort(entry)) == ORIENTATION_TAG
          && Short.toUnsignedInt(tiff.getShort(entry + 2)) == SHORT_TYPE) {
        int value = Short.toUnsignedInt(tiff.getShort(entry + 8));
        return value >= 1 && value <= 8 ? value : UPRIGHT;
      }
    }
    return UPRIGHT;
  }

  private static boolean startsWith(byte[] bytes, int from, int end, byte[] prefix) {
    return end - from >= prefix.length
        && Arrays.equals(bytes, from, from + prefix.length, prefix, 0, prefix.length);
  }

  /** {@code image} as it should be displayed for {@code orientation}. */
  static BufferedImage apply(BufferedImage image, int orientation) {
    if (orientation == UPRIGHT || orientation < 1 || orientation > 8) {
      return image;
    }
    int w = image.getWidth();
    int h = image.getHeight();
    boolean swap = orientation >= 5;
    BufferedImage out = new BufferedImage(swap ? h : w, swap ? w : h, BufferedImage.TYPE_INT_RGB);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int rgb = image.getRGB(x, y);
        switch (orientation) {
          case 2 -> out.setRGB(w - 1 - x, y, rgb); // mirror
          case 3 -> out.setRGB(w - 1 - x, h - 1 - y, rgb); // rotate 180°
          case 4 -> out.setRGB(x, h - 1 - y, rgb); // flip
          case 5 -> out.setRGB(y, x, rgb); // transpose
          case 6 -> out.setRGB(h - 1 - y, x, rgb); // rotate 90° clockwise
          case 7 -> out.setRGB(h - 1 - y, w - 1 - x, rgb); // transverse
          default -> out.setRGB(y, w - 1 - x, rgb); // 8: rotate 90° counter-clockwise
        }
      }
    }
    return out;
  }
}
