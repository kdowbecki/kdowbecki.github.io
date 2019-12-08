---
layout: post
title: "Spring Boot 2.2 properties with special characters"
categories: SpringBoot
---

I was trying to correctly identify Oracle JDBC Thin driver to the database in Spring Boot 2.2. Back in Spring Boot 1.5, 
this was be done by setting the `v$session.program` connection property [as I explained here](https://stackoverflow.com/a/49278981/1602555).
The setup was:

```
spring:
  datasource:
    hikari:
      data-source-properties:
        v$session.program: AppName
```

Unfortunately above no longer works in Spring Boot 2.2 and the property name will be resolved as
`spring.datasource.hikari.data-source-properties.vsession.program` with **the dollar sign silently removed**. 

Other have already reported this in [Problem with yml configuration file parsing map #13404](https://github.com/spring-projects/spring-boot/issues/13404) issue.
Turns out that in recent Spring Boot versions the property binder become more strict [as explained in this comment](https://github.com/spring-projects/spring-boot/issues/13404#issuecomment-395307439).
Going forward a property name with special characters has to escaped with **both** quotes and square brackets:

```
spring:
  datasource:
    hikari:
      data-source-properties:
        "[v$session.program]": AppName
```

This new syntax applies to property names in both `.yml` and `.properties` resources. 

The property values are not affected.
