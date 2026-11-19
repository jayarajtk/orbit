package com.orbit.media.infrastructure;

import com.orbit.media.application.MediaScanner;
import com.orbit.media.application.ObjectStorage;
import java.time.Duration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.core.retry.RetryMode;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/** S3 client, presigner and the default scanner. */
@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(MediaProperties.class)
class StorageConfig {

  @Bean(destroyMethod = "close")
  S3Client mediaS3Client(MediaProperties properties) {
    var builder =
        S3Client.builder()
            .region(Region.of(properties.region()))
            .credentialsProvider(credentials(properties))
            .serviceConfiguration(s3Configuration(properties))
            .httpClientBuilder(
                UrlConnectionHttpClient.builder()
                    .connectionTimeout(Duration.ofSeconds(5))
                    .socketTimeout(Duration.ofSeconds(30)))
            // Bounded retries with backoff and jitter (the SDK's standard mode).
            .overrideConfiguration(
                ClientOverrideConfiguration.builder()
                    .retryStrategy(RetryMode.STANDARD)
                    .apiCallTimeout(Duration.ofSeconds(60))
                    .build());
    if (properties.endpoint() != null) {
      builder.endpointOverride(properties.endpoint());
    }
    return builder.build();
  }

  @Bean(destroyMethod = "close")
  S3Presigner mediaS3Presigner(MediaProperties properties) {
    var builder =
        S3Presigner.builder()
            .region(Region.of(properties.region()))
            .credentialsProvider(credentials(properties))
            .serviceConfiguration(s3Configuration(properties));
    if (properties.endpoint() != null) {
      builder.endpointOverride(properties.endpoint());
    }
    return builder.build();
  }

  @Bean
  ObjectStorage objectStorage(S3Client s3, S3Presigner presigner, MediaProperties properties) {
    S3ObjectStorage storage = new S3ObjectStorage(s3, presigner, properties.bucket());
    if (properties.createBucket()) {
      storage.ensureBucket();
    }
    return storage;
  }

  @Bean
  @ConditionalOnMissingBean(MediaScanner.class)
  MediaScanner mediaScanner() {
    return new AllowAllMediaScanner();
  }

  private static S3Configuration s3Configuration(MediaProperties properties) {
    return S3Configuration.builder().pathStyleAccessEnabled(properties.pathStyle()).build();
  }

  private static AwsCredentialsProvider credentials(MediaProperties properties) {
    return properties.hasStaticCredentials()
        ? StaticCredentialsProvider.create(
            AwsBasicCredentials.create(properties.accessKey(), properties.secretKey()))
        : DefaultCredentialsProvider.builder().build();
  }
}
