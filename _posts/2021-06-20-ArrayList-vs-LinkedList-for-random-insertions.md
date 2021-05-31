---
layout: post
title: "ArrayList vs LinkedList for random insertions"
categories: [Algorithm, Java]
katex: true
---

In one of my favourite presentations [Why you should avoid Linked Lists](https://www.youtube.com/watch?v=YQs6IC-vgmo) 
we see a comparison of C++ `vector` and `list` performance in the following problem:

> Generate $$ N $$ random integers and insert them into a sequence so that each is inserted in it's
> proper position in the numerical order. **5 1 4 2** gives:
> - 5
> - 1 5
> - 1 4 5
> - 1 2 4 5
> 
> Remove elements one at a time by picking a random position in the sequence and removing the
> element there. Positions **1 2 0 0** gives:
> - 1 2 4 5
> - 1 4 5
> - 1 4
> - 4
> 
> For which $$ N $$ is better to use a linked list than a vector (or an array) to represent the sequence?

Let's compare Java `java.util.ArrayList` and `java.util.LinkedList` in the same way and see which one will be faster.


# Possible benchmark

To start we can consider following scenarios:

1. Insert $$ N $$ `Integer` into a sized `ArrayList`.
2. Insert $$ N $$ `Integer` into a sized `ArrayList` while maintaining list order.
3. Insert $$ N $$ `Integer` into a `LinkedList`.
4. Insert $$ N $$ `Integer` into a `LinkedList` while maintaining list order.

Scenario 1 gives us the baseline for `ArrayList` by measuring how expensive is the element insertion. By comparing 
results from scenario 1 and 2 we can then measure how expensive is maintaining the `ArrayList` order. Similar idea 
applies to scenario 3 and 4, this time for `LinkedList`.


# Running the benchmark

We can implement the benchmark using [JMH](https://github.com/openjdk/jmh):

```java
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 4, time = 5, timeUnit = TimeUnit.SECONDS)
@Measurement(iterations = 5, time = 10, timeUnit = TimeUnit.SECONDS)
@Fork(1)
public class ArrayListVsLinkedListBenchmark {

  @State(Scope.Benchmark)
  public static class BenchmarkState {
    final int N = 10000; // our N
    final Integer[] numbers = new Integer[N];

    public BenchmarkState() {
      var rand = new Random();
      for (int i = 0; i < numbers.length; i++) {
        numbers[i] = rand.nextInt();
      }
    }
  }

  @Benchmark // Scenario 1
  public List<Integer> arrayListSizedInsert(BenchmarkState state) { 
    var list = new ArrayList<Integer>(state.numbers.length);
    for (Integer number : state.numbers) {
      list.add(number);
    }
    return list;
  }

  @Benchmark // Scenario 2
  public List<Integer> arrayListSizedInOrderInsert(BenchmarkState state) {
    var list = new ArrayList<Integer>(state.numbers.length);
    outer:
    for (Integer number : state.numbers) {
      for (int i = 0; i < list.size(); i++) {
        if (number <= list.get(i)) {
          list.add(i, number);
          continue outer;
        }
      }
      list.add(number);
    }
    return list;
  }

  @Benchmark // Scenario 3
  public List<Integer> linkedListInsert(BenchmarkState state) {
    var list = new LinkedList<Integer>();
    for (Integer number : state.numbers) {
      list.add(number);
    }
    return list;
  }

  @Benchmark // Scenario 4
  public List<Integer> linkedListInOrderInsert(BenchmarkState state) {
    var list = new LinkedList<Integer>();
    outer:
    for (Integer num : state.numbers) {
      for (int i = 0; i < list.size(); i++) {
        if (num <= list.get(i)) {
          list.add(i, num);
          continue outer;
        }
      }
      list.add(num);
    }
    return list;
  }
  
}
```

On Intel(R) Core(TM) i7-7700HQ CPU @ 2.80GHz the results are:

| Scenario                    | N=10    | N=25    | N=50      | N=100      | N=1000         |
| --------------------------- | ------: | ------: | --------: | ---------: | -------------: |
| arrayListSizedInsert        | 47.423  | 115.480 | 199.008   | 377.808    | 3,661.444      |
| arrayListSizedInOrderInsert |	190.376 | 758.708 | 1,771.247 | 5,441.725  | 314,949.200    |
| linkedListInsert            | 71.766  | 169.755 | 337.902   | 668.914    | 6,410.276      |
| linkedListInOrderInsert     | 180.522 | 990.222 | 4,782.757 | 38,536.118 | 66,048,424.268 |

Right away we see that For both `ArrayList` and `LinkedList` the cost of finding insertion point significantly 
overtakes the cost of inserting an element. Only for $$ N=10 $$ `LinkedList` is faster than `ArrayList`. 
With $$ N $$ increasing `LinkedList` performance quickly deteriorates.


# Improving the benchmark

Before we move further it has to be noted that existing `LinkedList` scenarios perform the list traversal 
inefficiently. Instead of traversing the list once for each inserted element this happens every time 
we call `get()` or `add()` method, Let's improve this by switching to `ListIterator`.

To make the benchmark more interesting we will also avoid allocating the `ArrayList` upfront and instead allow 
periodic re-sizing to take place. This will make the `ArrayList` slower, but the behaviour will be closer to 
`LinkedList` which doesn't allocate the memory upfront.

Once again using JMH:

```java
  @Benchmark // Scenario 5
  public List<Integer> arrayListUnsizedInOrderInsert(BenchmarkState state) {
    var list = new ArrayList<Integer>();
    outer:
    for (Integer number : state.numbers) {
      for (int i = 0; i < list.size(); i++) {
        if (number <= list.get(i)) {
          list.add(i, number);
          continue outer;
        }
      }
      list.add(number);
    }
    return list;
  }
    
  @Benchmark // Scenario 6
  public List<Integer> linkedListIteratorInOrderInsert(BenchmarkState state) {
    var list = new LinkedList<Integer>();
    outer:
    for (Integer num : state.numbers) {
      var it = list.listIterator();
      while (it.hasNext()) {
        var el = it.next();
        if (num <= el) {
          it.set(num);
          it.add(el);
          continue outer;
        }
      }
      it.add(num);
    }
    return list;
  }
```

On the same Intel(R) Core(TM) i7-7700HQ CPU @ 2.80GHz the results are:

| Scenario                        | N=10    | N=25    | N=50      | N=100      | N=1000         |
| --------------------------------| ------: | ------: | --------: | ---------: | -------------: |
| arrayListUnsizedInOrderInsert   | 218.910 | 931.218 | 2,034.632 | 5,746.831  | 380,032.696    |	
| linkedListIteratorInOrderInsert |	175.161 | 698.068 | 2,242.376 | 9,627.562  | 1,249,834.336	|

Although new `LinkedList` scenario is considerably more efficient around $$ N=50 $$ `ArrayList` becomes faster. 
This time `LinkedList` performance doesn't degrade as rapidly as before, however $$ N=50 $$ is still a small $$ N $$.


# Conclusion

`LinkedList` insertion complexity is $$ O(1) $$ while `ArrayList` is $$ O(N) $$. Because of that
`LinkedList` is often the first choice when dealing with rapid element insertions. However, this 
complexity doesn't measure the cost of finding a random insertion point within list. 

On a modern hardware the cost of list traversal will be driven primarily by cost of accessing RAM. Because 
`LinkedList` is a linked data structure:
 - It allocates more memory as it must store references between nodes.
 - It can't guarantee memory locality with nodes possibly allocated in non-consecutive memory which will interfere
   with [cache prefetching](https://en.wikipedia.org/wiki/Cache_prefetching).

So don't discard `ArrayList` right away when dealing with rapid insertions, it might actually be faster!