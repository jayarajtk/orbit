package com.orbit.shared;

import java.io.Closeable;
import java.io.IOException;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Set;
import java.util.function.Supplier;
import javax.sql.DataSource;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.datasource.DelegatingDataSource;

/**
 * Counts the SQL statements prepared on the calling thread, so a test can assert that an operation
 * runs a fixed number of queries (no N+1). Statements other threads run (schedulers, other
 * requests) are not counted, which keeps the count deterministic.
 */
public final class CountingDataSource extends DelegatingDataSource implements Closeable {

  private static final Set<String> STATEMENT_METHODS =
      Set.of("prepareStatement", "prepareCall", "createStatement");

  private final ThreadLocal<int[]> counter = new ThreadLocal<>();

  CountingDataSource(DataSource target) {
    super(target);
  }

  /** Runs {@code action} and returns its result with the statements it prepared on this thread. */
  public <T> Counted<T> count(Supplier<T> action) {
    int[] statements = {0};
    counter.set(statements);
    try {
      T result = action.get();
      return new Counted<>(result, statements[0]);
    } finally {
      counter.remove();
    }
  }

  @Override
  public Connection getConnection() throws SQLException {
    return counting(super.getConnection());
  }

  @Override
  public Connection getConnection(String username, String password) throws SQLException {
    return counting(super.getConnection(username, password));
  }

  /** Closes the pool behind it, as the context would have closed the unwrapped data source. */
  @Override
  public void close() throws IOException {
    if (obtainTargetDataSource() instanceof Closeable closeable) {
      closeable.close();
    }
  }

  private Connection counting(Connection target) {
    InvocationHandler handler =
        (proxy, method, args) -> {
          switch (method.getName()) {
            case "equals" -> {
              return proxy == args[0];
            }
            case "hashCode" -> {
              return System.identityHashCode(proxy);
            }
            default -> {
              if (STATEMENT_METHODS.contains(method.getName()) && counter.get() != null) {
                counter.get()[0]++;
              }
              return invoke(target, method, args);
            }
          }
        };
    return (Connection)
        Proxy.newProxyInstance(
            Connection.class.getClassLoader(), new Class<?>[] {Connection.class}, handler);
  }

  private static Object invoke(Connection target, Method method, Object[] args) throws Throwable {
    try {
      return method.invoke(target, args);
    } catch (InvocationTargetException e) {
      throw e.getCause();
    }
  }

  /** What an action returned and how many statements it prepared. */
  public record Counted<T>(T result, int statements) {}

  /** Wraps the application's data source in a {@link CountingDataSource}. */
  @TestConfiguration(proxyBeanMethods = false)
  public static class Config {

    @Bean
    static BeanPostProcessor countingDataSourceWrapper() {
      return new BeanPostProcessor() {
        @Override
        public Object postProcessAfterInitialization(Object bean, String beanName) {
          if (bean instanceof DataSource dataSource && !(bean instanceof CountingDataSource)) {
            return new CountingDataSource(dataSource);
          }
          return bean;
        }
      };
    }
  }
}
