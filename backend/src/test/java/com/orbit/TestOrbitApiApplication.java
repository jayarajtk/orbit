package com.orbit;

import org.springframework.boot.SpringApplication;

public class TestOrbitApiApplication {

  public static void main(String[] args) {
    SpringApplication.from(OrbitApiApplication::main)
        .with(TestcontainersConfiguration.class)
        .run(args);
  }
}
