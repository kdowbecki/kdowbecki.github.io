---
layout: post
title: "Statement caching with Spring Boot and Oracle database"
categories: [Spring Boot, Oracle]
---

This post is a continuation of [this Stack Overflow question](https://stackoverflow.com/questions/58855423/oracle-jdbc-optimization-enable-preparedstatement-caching-in-a-spring-boot-res/58994467#58994467)
where the author attempted to incorrectly setup statement caching. The overall idea is well described in 
[chapter 20. Statement and Result Set Caching](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/jjdbc/statement-and-resultset-caching.html#GUID-F3F4BB63-356A-4F65-81B1-5C84FC35A16D) 
documentation however the example uses  `OracleDataSource.setImplicitCachingEnabled(true)` which is a proprietary API. 

Luckily, the same behaviour can be achieved just by using Spring Boot properties. We will need the following to prove this:
- [Spring Boot 2.2.1](https://spring.io/blog/2019/11/07/spring-boot-2-2-1-available-now)
- [HikariCP](https://github.com/brettwooldridge/HikariCP) connection pool, comes with Spring Boot
- [Oracle 12c R2 12.2.0.1](https://www.oracle.com/database/12c-database/) database server 


# Database server setup

We need an Oracle database server. Since we don't need any special configuration we can use [Oracle Database 12c Enterprise Edition docker image](https://hub.docker.com/_/oracle-database-enterprise-edition).
This can be done with:

```text
docker run -d -it --name oracle12c -p 1521:1521 store/oracle/database-enterprise:12.2.0.1
```

Once the server is up we can create new user for our Spring Boot application:
```sql
ALTER SESSION SET "_ORACLE_SCRIPT" = true;
CREATE USER test1 IDENTIFIED BY test1;
GRANT ALL PRIVILEGES TO test1;
GRANT UNLIMITED TABLESPACE TO test1;
ALTER USER test1 quota unlimited ON users;
```

Now having created `test1` user we can create a `fruit` table with two columns and few example rows:
```sql
CREATE TABLE fruit (
	id INTEGER PRIMARY KEY,
	name VARCHAR2(200)
);
INSERT INTO fruit (id, name) VALUES (1, 'Apple');
INSERT INTO fruit (id, name) VALUES (2, 'Orange');
INSERT INTO fruit (id, name) VALUES (3, 'Strawberry');
INSERT INTO fruit (id, name) VALUES (4, 'Banana');
INSERT INTO fruit (id, name) VALUES (5, 'Blackberry');
INSERT INTO fruit (id, name) VALUES (6, 'Papaya');
INSERT INTO fruit (id, name) VALUES (7, 'Cherry');
INSERT INTO fruit (id, name) VALUES (8, 'Tomato');
INSERT INTO fruit (id, name) VALUES (9, 'Cucumber');
INSERT INTO fruit (id, name) VALUES (10, 'Avocado');
```


## Application setup

To quickly generate a new Spring boot application we can use [Spring Initializer](https://start.spring.io/). 
It's handy to select additional `spring-boot-starter-data-jdbc` dependency to get basic JDBC boilerplate.

Next, `ojdbc8.jar` driver must be downloaded to match the database server version. This can be done from 
[Oracle Database 12.2.0.1 JDBC Driver & UCP Downloads](https://www.oracle.com/database/technologies/jdbc-ucp-122-downloads.html)
website. Once we have the JAR we can to add it as a runtime dependency.

To execute new SQL query we can create a bean with `@Scheduled` method. Every 100ms a connection will be 
obtained from the pool, and the same SQL query will be executed using `PreparedStatement`. The actual SQL query used
makes no difference to us, we just need something running on the connection to see that it's cached:

```java
@Service
public class QueryService {
  private static final Logger LOG = LoggerFactory.getLogger(QueryService.class);
  private static final String SQL = "SELECT id, name FROM fruit WHERE lower(name) LIKE ? ORDER BY name";

  @Autowired
  private DataSource dataSource;

  @Scheduled(fixedRate = 100)
  public void runQuery() throws Exception {
    try (Connection conn = dataSource.getConnection()) {
      try (PreparedStatement stmt = conn.prepareStatement(SQL)) {
        stmt.setString(1, "%a%");
        try (ResultSet rs = stmt.executeQuery()) {
          StringJoiner joiner = new StringJoiner(" ");
          while (rs.next()) {
            joiner.add(rs.getInt("id") + "=" + rs.getString("name"));
          }
          LOG.info(joiner.toString());
        }
      }
    }
  }
}
```

If we configure the task scheduler with `Executors.newScheduledThreadPool(10)` we see that `QueryService.runQuery()` 
method is executed using multiple threads, so far so good:

```text
2019-12-08 21:52:48.323  INFO 28312 --- [pool-1-thread-1] io.github.kdowbecki.QueryService         : 1=Apple 10=Avocado 4=Banana 5=Blackberry 2=Orange 6=Papaya 3=Strawberry 8=Tomato
2019-12-08 21:52:48.354  INFO 28312 --- [pool-1-thread-3] io.github.kdowbecki.QueryService         : 1=Apple 10=Avocado 4=Banana 5=Blackberry 2=Orange 6=Papaya 3=Strawberry 8=Tomato
2019-12-08 21:52:48.454  INFO 28312 --- [pool-1-thread-2] io.github.kdowbecki.QueryService         : 1=Apple 10=Avocado 4=Banana 5=Blackberry 2=Orange 6=Papaya 3=Strawberry 8=Tomato
2019-12-08 21:52:48.554  INFO 28312 --- [pool-1-thread-4] io.github.kdowbecki.QueryService         : 1=Apple 10=Avocado 4=Banana 5=Blackberry 2=Orange 6=Papaya 3=Strawberry 8=Tomato
```


## There is no statement caching

To observe this we should run the application and query the [V$SQLAREA view](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/refrn/V-SQLAREA.html#GUID-09D5169F-EE9E-4297-8E01-8D191D87BDF7) 
which provides "statistics on SQL statements that are in memory, parsed, and ready for execution". We can focus on just
two columns: `PARSE_CALLS` and `EXECUTIONS`:

```sql
SELECT parse_calls, executions
FROM v$sqlarea 
WHERE sql_text LIKE 'SELECT id, name FROM fruit%'
```

Which will return:

```text
89	89
```

These two numbers are constantly increasing with time. They will always have the same value which indicates that each time 
`PreparedStatement.executeQuery()` is run the SQL query is parsed.


## Enabling statement caching in the driver

By design HikariCP doesn't implement a statement cache [as explained by the author](https://github.com/brettwooldridge/HikariCP/issues/488#issuecomment-154285114). 
This functionality must be provided by the JDBC driver if we want to use it in our application. In our case `ojdbc8.jar` provides a configuration 
**`oracle.jdbc.implicitStatementCacheSize` property** which defines the size of the internal LRU statement cache. By 
default, the value is 0, we need to overwrite it to enable caching.

This can be done with `application.yml` property, if we want to cache 100 statements:

```yaml
spring:
  datasource:
    hikari:
      data-source-properties:
        oracle.jdbc.implicitStatementCacheSize: 100
```

Let's restart the database server and compare `PARSE_CALLS` with `EXECUTIONS` values for our SQL query again. 
This time we see: 

```text
1	59
```

Only the `EXECUTIONS` value is increasing with time while `PARSE_CALLS` doesn't change. We have a working statement 
cache!


## Resources

- <a href="https://www.oracle.com/technical-resources/articles/vasiliev-oracle-jdbc.html">High-Performance Oracle JDBC Programming</a>
- <a href="https://manualzz.com/doc/46481860/performance--scalability--and-high-availability-with-jdbc">Performance, Scalability, and High Availability with JDBC and UCP in Oracle Database 12c Release 2 (12.2.0.1)</a>
- <a href="http://www.oracle.com/technetwork/database/application-development/con2158-javaoneucpsession-2769404.pdf">Java Connection Pool Performance and Scalability with Wait-Free Programming</a>
