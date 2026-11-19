package com.orbit.media.application;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Iterator;
import java.util.Locale;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import org.springframework.stereotype.Component;

/**
 * Decodes an uploaded photo and re-encodes it as JPEG at two sizes. Re-encoding from pixels drops
 * every metadata block, so EXIF and GPS never survive even if the app failed to strip them. The one
 * piece of EXIF that matters for display, the orientation, is applied to the pixels first: phones
 * often store photos sideways or upside down and rely on that tag.
 */
@Component
public class ImageProcessor {

  /** Longest side of the full-size variant. */
  public static final int FULL_SIZE = 2048;

  /** Longest side of the thumbnail. */
  public static final int THUMB_SIZE = 480;

  /** Larger images are refused before decoding (decompression bombs). */
  static final int MAX_PIXELS = 50_000_000;

  /**
   * Processes {@code original}.
   *
   * @throws InvalidImageException if it isn't a decodable JPEG or PNG within limits
   */
  public Processed process(byte[] original) {
    BufferedImage image = decode(original);
    int orientation = ExifOrientation.read(original);
    // Scaling first is cheaper and equivalent: the bound is on the longest side either way.
    BufferedImage full = ExifOrientation.apply(scaled(image, FULL_SIZE), orientation);
    BufferedImage thumb = ExifOrientation.apply(scaled(image, THUMB_SIZE), orientation);
    return new Processed(jpeg(full, 0.85f), jpeg(thumb, 0.8f), full.getWidth(), full.getHeight());
  }

  private static BufferedImage decode(byte[] bytes) {
    try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
      if (input == null) {
        throw new InvalidImageException();
      }
      Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) {
        throw new InvalidImageException();
      }
      ImageReader reader = readers.next();
      try {
        reader.setInput(input, true, true);
        String format = reader.getFormatName().toLowerCase(Locale.ROOT);
        if (!format.equals("jpeg") && !format.equals("png")) {
          throw new InvalidImageException();
        }
        long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
        if (pixels <= 0 || pixels > MAX_PIXELS) {
          throw new InvalidImageException();
        }
        return reader.read(0);
      } finally {
        reader.dispose();
      }
    } catch (IOException e) {
      // Corrupt or unsupported data (e.g. CMYK JPEG): treat as invalid, not as a server error.
      throw new InvalidImageException();
    }
  }

  /** Downscales so the longest side is at most {@code max}; draws onto RGB to drop alpha. */
  private static BufferedImage scaled(BufferedImage source, int max) {
    double factor = Math.min(1.0, (double) max / Math.max(source.getWidth(), source.getHeight()));
    int width = Math.max(1, (int) Math.round(source.getWidth() * factor));
    int height = Math.max(1, (int) Math.round(source.getHeight() * factor));
    BufferedImage target = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = target.createGraphics();
    try {
      g.setRenderingHint(
          RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
      g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
      g.setColor(java.awt.Color.WHITE);
      g.fillRect(0, 0, width, height);
      g.drawImage(source, 0, 0, width, height, null);
    } finally {
      g.dispose();
    }
    return target;
  }

  private static byte[] jpeg(BufferedImage image, float quality) {
    ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
    ByteArrayOutputStream bytes = new ByteArrayOutputStream();
    try (ImageOutputStream output = ImageIO.createImageOutputStream(bytes)) {
      writer.setOutput(output);
      ImageWriteParam params = writer.getDefaultWriteParam();
      params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
      params.setCompressionQuality(quality);
      writer.write(null, new IIOImage(image, null, null), params);
    } catch (IOException e) {
      throw new UncheckedIOException("Encoding to an in-memory buffer failed", e);
    } finally {
      writer.dispose();
    }
    return bytes.toByteArray();
  }

  /** Both variants, as JPEG. Width and height are the full variant's. */
  public record Processed(byte[] full, byte[] thumb, int width, int height) {}

  /** Not a usable photo. */
  public static class InvalidImageException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidImageException() {
      super("Invalid image");
    }
  }
}
