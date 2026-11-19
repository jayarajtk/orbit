package com.orbit.media.infrastructure;

import com.orbit.media.application.ObjectStorage;
import java.time.Duration;
import java.util.OptionalLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/** {@link ObjectStorage} on S3 or any S3-compatible store (MinIO locally). */
class S3ObjectStorage implements ObjectStorage {

  private static final Logger log = LoggerFactory.getLogger(S3ObjectStorage.class);
  private static final int NOT_FOUND = 404;

  private final S3Client s3;
  private final S3Presigner presigner;
  private final String bucket;

  S3ObjectStorage(S3Client s3, S3Presigner presigner, String bucket) {
    this.s3 = s3;
    this.presigner = presigner;
    this.bucket = bucket;
  }

  /** Creates the bucket if it is missing (local and test only). */
  void ensureBucket() {
    try {
      s3.headBucket(b -> b.bucket(bucket));
    } catch (NoSuchBucketException e) {
      log.info("Creating media bucket {}", bucket);
      s3.createBucket(b -> b.bucket(bucket));
    }
  }

  @Override
  public String presignPut(String key, String contentType, long sizeBytes, Duration ttl) {
    // Type and length are signed: the client can't upload anything else to this link.
    return presigner
        .presignPutObject(p ->
            p.signatureDuration(ttl)
                .putObjectRequest(o ->
                    o.bucket(bucket).key(key).contentType(contentType).contentLength(sizeBytes)))
        .url()
        .toString();
  }

  @Override
  public String presignGet(String key, Duration ttl) {
    return presigner
        .presignGetObject(
            p -> p.signatureDuration(ttl).getObjectRequest(o -> o.bucket(bucket).key(key)))
        .url()
        .toString();
  }

  @Override
  public OptionalLong size(String key) {
    try {
      return OptionalLong.of(s3.headObject(h -> h.bucket(bucket).key(key)).contentLength());
    } catch (NoSuchKeyException e) {
      return OptionalLong.empty();
    } catch (S3Exception e) {
      // HEAD responses have no body, so a missing key can surface as a bare 404.
      if (e.statusCode() == NOT_FOUND) {
        return OptionalLong.empty();
      }
      throw e;
    }
  }

  @Override
  public byte[] readHead(String key, int length) {
    return s3.getObjectAsBytes(g -> g.bucket(bucket).key(key).range("bytes=0-" + (length - 1)))
        .asByteArray();
  }

  @Override
  public byte[] read(String key) {
    return s3.getObjectAsBytes(g -> g.bucket(bucket).key(key)).asByteArray();
  }

  @Override
  public void write(String key, byte[] bytes, String contentType) {
    s3.putObject(
        p -> p.bucket(bucket).key(key).contentType(contentType), RequestBody.fromBytes(bytes));
  }

  @Override
  public void delete(String key) {
    s3.deleteObject(d -> d.bucket(bucket).key(key));
  }
}
