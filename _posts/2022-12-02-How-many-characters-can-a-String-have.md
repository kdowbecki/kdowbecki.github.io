---
layout: post
title: "How many characters can a String have?"
categories: [Java]
---

Since `String.length()` method returns an `int` we could guess that the maximum length would be `Integer.MAX_VALUE` 
characters. That's not correct. Let's forget about Unicode for now, and try to create the longest possible string by
repeating a lowercase letter *a*.

```java
String text = "a".repeat(Integer.MAX_VALUE);
```
```
java.lang.OutOfMemoryError: Requested array size exceeds VM limit
  at java.base/java.lang.String.repeat(String.java:4428)
  ...
```

Let's try to understand what happened and why the code complied but threw an error in runtime.


# How is the String implemented

Since Java 9 and [JEP 254: Compact Strings](https://openjdk.java.net/jeps/254) the `String` class is internally storing
the characters in a `byte[]` array. The stack trace from `OutOfMemoryError` points to `String.java:4428` line, 
which in Java 17 source code is an array creation expression:

```java
final byte[] single = new byte[count];
```

As per [Java Language Specification, Java SE 17 Edition, Chapter 10](https://docs.oracle.com/javase/specs/jls/se17/html/jls-10.html)

> The variables contained in an array have no names; instead they are referenced by array access expressions that
> use **non-negative integer index** values.

The language specification doesn't prohibit the `Integer.MAX_VALUE` array index so the compiler doesn't complain
if we try to allocate `new byte[Integer.MAX_VALUE]`. However, we will get the familiar 
`OutOfMemoryError: Requested array size exceeds VM limit` error in runtime.

This is not a new behaviour. The ancient `java.util.Hastable` class present since Java 1.0 mentions it.

```java
/**
 * The maximum size of array to allocate.
 * Some VMs reserve some header words in an array.
 * Attempts to allocate larger arrays may result in
 * OutOfMemoryError: Requested array size exceeds VM limit
 */
private static final int MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8;
```


# How is the array creation implemented

The maximum array length limitation is coming from the JVM implementation. In OpenJDK 17 source code it will be
[arrayOop.hpp `max_array_length(BasicType type)` method](https://github.com/openjdk/jdk/blob/jdk-17-ga/src/hotspot/share/oops/arrayOop.hpp#L136-L158)
which performs the below calculation.

```cpp
const size_t max_element_words_per_size_t =
  align_down((SIZE_MAX/HeapWordSize - header_size(type)), MinObjAlignment);
const size_t max_elements_per_size_t =
  HeapWordSize * max_element_words_per_size_t / type2aelembytes(type);
if ((size_t)max_jint < max_elements_per_size_t) {
  // It should be ok to return max_jint here, but parts of the code
  // (CollectedHeap, Klass::oop_oop_iterate(), and more) uses an int for
  // passing around the size (in words) of an object. So, we need to avoid
  // overflowing an int when we add the header. See CRs 4718400 and 7110613.
  return align_down(max_jint - header_size(type), MinObjAlignment);
}
return (int32_t)max_elements_per_size_t;
```

I'm definitely not OpenJDK source code expert. After spending some time searching for answers it feels like 
`MinObjAlignment` and other values in this method will depend on the CPU architecture. If so there won't 
be just a single answer.

On Linux x86_64 debugging with [`gdb`](https://sourceware.org/gdb/) shows that the expression 
`align_down(max_jint - header_size(type), MinObjAlignment)` is executed and the method returns 2147483645, 
which is `Integer.MAX_VALUE - 2`. Knowing that let's try to create the longest possible string again.

```java
String text = "a".repeat(Integer.MAX_VALUE - 2);
```

This time it doesn't throw any errors confirming that for Java 17 running on Linux x86_64 a string can have up to
`Integer.MAX_VALUE - 2` characters.
