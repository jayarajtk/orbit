package com.orbit.shared.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Enables asynchronous event listeners ({@code @ApplicationModuleListener}). Boot's task executor
 * runs them on virtual threads ({@code spring.threads.virtual.enabled}).
 */
@Configuration(proxyBeanMethods = false)
@EnableAsync
public class AsyncConfig {}
