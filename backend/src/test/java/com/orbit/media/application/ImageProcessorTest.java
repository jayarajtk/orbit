package com.orbit.media.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.orbit.media.application.ImageProcessor.InvalidImageException;
import com.orbit.media.application.ImageProcessor.Processed;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class ImageProcessorTest {

  private final ImageProcessor processor = new ImageProcessor();

  /** A 200×100 image: red block at the top-left, the rest white. */
  private static byte[] marked() throws IOException {
    BufferedImage image = new BufferedImage(200, 100, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = image.createGraphics();
    g.setColor(Color.WHITE);
    g.fillRect(0, 0, 200, 100);
    g.setColor(Color.RED);
    g.fillRect(0, 0, 40, 40);
    g.dispose();
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "jpeg", out);
    return out.toByteArray();
  }

  /** Inserts an EXIF segment whose only tag is the orientation, as cameras write it. */
  private static byte[] withOrientation(byte[] jpeg, int orientation, boolean bigEndian) {
    ByteArrayOutputStream tiff = new ByteArrayOutputStream();
    if (bigEndian) {
      tiff.writeBytes(new byte[] {'M', 'M', 0, 42, 0, 0, 0, 8}); // header, IFD0 at 8
      tiff.writeBytes(new byte[] {0, 1}); // one entry
      tiff.writeBytes(new byte[] {0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, (byte) orientation, 0, 0});
      tiff.writeBytes(new byte[] {0, 0, 0, 0}); // no next IFD
    } else {
      tiff.writeBytes(new byte[] {'I', 'I', 42, 0, 8, 0, 0, 0});
      tiff.writeBytes(new byte[] {1, 0});
      tiff.writeBytes(new byte[] {0x12, 0x01, 3, 0, 1, 0, 0, 0, (byte) orientation, 0, 0, 0});
      tiff.writeBytes(new byte[] {0, 0, 0, 0});
    }
    byte[] exifHeader = "Exif\0\0".getBytes(StandardCharsets.US_ASCII);
    int length = 2 + exifHeader.length + tiff.size();
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    out.write(jpeg, 0, 2);
    out.writeBytes(new byte[] {(byte) 0xFF, (byte) 0xE1, (byte) (length >> 8), (byte) length});
    out.writeBytes(exifHeader);
    out.writeBytes(tiff.toByteArray());
    out.write(jpeg, 2, jpeg.length - 2);
    return out.toByteArray();
  }

  private static BufferedImage decode(byte[] jpeg) throws IOException {
    return ImageIO.read(new ByteArrayInputStream(jpeg));
  }

  private static boolean redAt(BufferedImage image, int x, int y) {
    Color c = new Color(image.getRGB(x, y));
    return c.getRed() > 200 && c.getGreen() < 80 && c.getBlue() < 80;
  }

  /**
   * After applying the orientation, the red block must be in the corner where a viewer sees it.
   * Expected corner is given for the output image: TL, TR, BL or BR.
   */
  @ParameterizedTest(name = "orientation {0} puts the mark at {1}")
  @CsvSource({
    "1, TL, false",
    "2, TR, false",
    "3, BR, false",
    "4, BL, false",
    "5, TL, true",
    "6, TR, true",
    "7, BR, true",
    "8, BL, true"
  })
  void appliesTheExifOrientation(int orientation, String corner, boolean swapsSides)
      throws IOException {
    for (boolean bigEndian : new boolean[] {true, false}) {
      Processed processed = processor.process(withOrientation(marked(), orientation, bigEndian));

      BufferedImage full = decode(processed.full());
      assertThat(full.getWidth()).isEqualTo(swapsSides ? 100 : 200);
      assertThat(full.getHeight()).isEqualTo(swapsSides ? 200 : 100);
      assertThat(processed.width()).isEqualTo(full.getWidth());
      int right = full.getWidth() - 10;
      int bottom = full.getHeight() - 10;
      int x = corner.endsWith("R") ? right : 10;
      int y = corner.startsWith("B") ? bottom : 10;
      assertThat(redAt(full, x, y)).as("red at %s", corner).isTrue();
      assertThat(new String(processed.full(), StandardCharsets.ISO_8859_1)).doesNotContain("Exif");
    }
  }

  @Test
  void imagesWithoutExifStayAsTheyAre() throws IOException {
    BufferedImage full = decode(processor.process(marked()).full());

    assertThat(full.getWidth()).isEqualTo(200);
    assertThat(redAt(full, 10, 10)).isTrue();
  }

  @Test
  void largePhotosAreScaledDownToTheLongestSide() throws IOException {
    BufferedImage image = new BufferedImage(3000, 1500, BufferedImage.TYPE_INT_RGB);
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "jpeg", out);

    Processed processed = processor.process(out.toByteArray());

    assertThat(processed.width()).isEqualTo(ImageProcessor.FULL_SIZE);
    assertThat(processed.height()).isEqualTo(1024);
    assertThat(decode(processed.thumb()).getWidth()).isEqualTo(ImageProcessor.THUMB_SIZE);
  }

  @Test
  void rejectsWhatIsNotAPhoto() {
    assertThatThrownBy(() -> processor.process("hello".getBytes(StandardCharsets.UTF_8)))
        .isInstanceOf(InvalidImageException.class);
  }
}
