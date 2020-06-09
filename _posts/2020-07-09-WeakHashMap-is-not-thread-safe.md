---
layout: post
title: "WeakHashMap is not thread safe"
categories: [Java]
---

`java.util.WeakHashMap` can be used as in-memory cache, allowing keys to expire when they are 
[weakly reachable](https://docs.oracle.com/javase/8/docs/api/java/lang/ref/package-summary.html#reachability).
Unfortunately this class is not thread safe, and it gets worse. It's entirely possible that unsynchronized invocation 
of the `WeakHashMap.get(Object)` method **will result in infinite busy waiting** blocking all other threads 
from progressing.

If we take a look at the `WeakHashMap.get(Object)` method source code, the culprit is the `while` loop: 

```java
public V get(Object key) {
  Object k = maskNull(key);
  int h = hash(k);
  Entry<K,V>[] tab = getTable();
  int index = indexFor(h, tab.length);
  Entry<K,V> e = tab[index];
  while (e != null) {
    if (e.hash == h && eq(k, e.get()))
        return e.value;
    e = e.next;
  }
  return null;
}
```

Although surprising, this problem has been discovered in multiple well-known open source project 
e.g. [Tomcat bug #50078](https://bz.apache.org/bugzilla/show_bug.cgi?id=50078) 
or [Jenkins bug #6528](https://issues.jenkins-ci.org/browse/JENKINS-6528). 

If you need an in-memory cache and want to avoid thread synchronization, `WeakHashMap` is the wrong choice.
