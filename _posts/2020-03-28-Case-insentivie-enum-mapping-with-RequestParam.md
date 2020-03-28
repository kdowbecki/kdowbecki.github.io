---
layout: post
title: "Case insensitive enum mapping with @RequestParam"
categories: [Spring Boot, Stack Overflow]
---

One of my highest voted posts on Stack Overflow is an answer to 
[Deserialize enum ignoring case in Spring Boot controller](https://stackoverflow.com/q/50231233/1602555) question. Frankly, 
the answer is incorrect. The whole situation is puzzling since I don't get why it was upvoted.

# Enum constants are case sensitive

Consider the following enum and corresponding `@RestController`:

```java
public enum ExampleEnum {
  FIRST,
  SECOND
}
```

```java
@RestController
public class ExampleEnumController {
  @GetMapping("/enum")
  public ExampleEnum getByName(@RequestParam(name = "name", required = false) ExampleEnum ee) {
    return ee;
  }
}
```

This will work as intended and return 200 response when `name` request parameter value is uppercase e.g. 
`GET http://localhost:8080/enum?mame=FIRST`. However when `name` value is lowercase 
e.g. `GET http://localhost:8080/enum?mame=first` the code will return a 400 response:

```json
{
  "timestamp": "2020-03-28T10:21:20.989+0000",
  "status": 400,
  "error": "Bad Request",
  "message": "Failed to convert value of type 'java.lang.String' to required type 'kad.ExampleEnum'; nested exception is org.springframework.core.convert.ConversionFailedException: Failed to convert from type [java.lang.String] to type [@org.springframework.web.bind.annotation.RequestParam kad.ExampleEnum] for value 'first'; nested exception is java.lang.IllegalArgumentException: No enum constant kad.ExampleEnum.first",
  "path": "/enum"
}
```

# Custom case insensitive matching

The default behaviour is caused by Spring utilizing `com.sun.beans.editors.EnumEditor` to map enum values mapped with
`@RequestParam` annotation. To change this we have to declare our own editor.

```java
import java.beans.PropertyEditorSupport;

public class CaseInsensitiveEnumEditor extends PropertyEditorSupport {
  private final Class<? extends Enum> enumType;
  private final String[] enumNames;
             
  public CaseInsensitiveEnumEditor(Class<?> type) {
    this.enumType = type.asSubclass(Enum.class);
    var values = type.getEnumConstants();
    if (values == null) {
      throw new IllegalArgumentException("Unsupported " + type);
    }
    this.enumNames = new String[values.length];
    for (int i = 0; i < values.length; i++) {
      this.enumNames[i] = ((Enum<?>) values[i]).name();
    }
  }
             
  @Override
  public void setAsText(String text) throws IllegalArgumentException {
    if (text == null || text.isEmpty()) {
      setValue(null);
      return;
    }
    for (String n : enumNames) {
      if (n.equalsIgnoreCase(text)) {
        @SuppressWarnings("unchecked")
        var newValue = Enum.valueOf(enumType, n);
        setValue(newValue);
        return;
      }
     }
     throw new IllegalArgumentException("No enum constant " + enumType.getCanonicalName() + " equals ignore case " + text);
   }

}
```

And register the new editor by using `@InitBinder`:

```java
@RestController
public class ExampleEnumController {

  @GetMapping("/enum")
  public ExampleEnum getByName(@RequestParam(name = "name", required = false) ExampleEnum ee) {
    return ee;
  }

  @InitBinder
  public void initBinder(WebDataBinder binder) {
    binder.registerCustomEditor(ExampleEnum.class, new CaseInsensitiveEnumEditor(ExampleEnum.class));
  }

}
```
