---
layout: post
title: "Spring Boot 2.2 properties with special characters"
categories: [Spring Boot]
---

I was trying to correctly identify application using Oracle JDBC Thin driver to the database server in Spring Boot 2.2. 
In Spring Boot 1.5 this was accomplished by setting the `v$session.program` connection property 
[as I explained here](https://stackoverflow.com/a/49278981/1602555). The setup was:

```
spring:
  datasource:
    hikari:
      data-source-properties:
        v$session.program: AppName
```

Unfortunately above no longer works in Spring Boot 2.2. Now surprisingly the property name will be resolved as
`spring.datasource.hikari.data-source-properties.vsession.program` with **the dollar sign silently removed**. 

Others have already reported this strange behaviour in [Problem with yml configuration file parsing map #13404](https://github.com/spring-projects/spring-boot/issues/13404) 
issue. Spring Boot binder has become stricter [as explained in this comment](https://github.com/spring-projects/spring-boot/issues/13404#issuecomment-395307439)
and going forward property name with special characters has to escaped with **both quotes and square brackets**:

```
spring:
  datasource:
    hikari:
      data-source-properties:
        "[v$session.program]": AppName
```

This new escape syntax applies to property names in both `.yml` and `.properties` resources.