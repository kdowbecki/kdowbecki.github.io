---
layout: post
title: "Optimizing computational algorithms"
categories: [Algorithm]
katex: true
---

When optimizing an algorithm it's often good to take a step back and think about the problem nature before jumping 
straight to coding. Today I have seen following question asked on Stack Overflow:

> I have a program that has two nested for loops and takes $$ O(n^2) $$ time. I want to know if there is such way 
> to decrease the time of execution for it. Example:
```java
long b = 10000;
long counter = 0;
for (int k = 0; k < b; k++) {
    for (int a = k; a < b; a++) {
        counter += k;
    }
}
```

At first glance we immediately notice that in the above code variable `k` is added repeatedly. Perhaps we could 
remember the `counter` value from the previous loop iteration? Perhaps we could create another variable... Here we 
should take a step back. 

We should notice that the above code is just a mathematical equation. Let's write it down:

$$
counter = \sum\limits_{k = 0}^{b-1} \sum\limits_{a = k}^{b-1} k
$$ 

We have two nested sums, can we solve this equation?

The sum on the right is $$ k $$ added from $$ k $$ to $$ b-1 $$ (inclusive) times. This means that in total
$$ k $$ is going to be added $$ b - 1 - k + 1 = b - k $$ times. Knowing that we can expand the sum on the right:

$$
\sum\limits_{k = 0}^{b-1} \sum\limits_{a = k}^{b-1} k
= \sum\limits_{k = 0}^{b-1} [k(b-k)]
= \sum\limits_{k = 0}^{b-1} (kb-k^2)
= \sum\limits_{k = 0}^{b-1} kb - \sum\limits_{k = 0}^{b-1} k^2
= b \sum\limits_{k = 0}^{b-1} k - \sum\limits_{k = 0}^{b-1} k^2
$$

We have converted two nested sums into two separate sums and in the process removed $$ a $$ which is an improvement. 
To solve the new sums we can use [known summation formulas, often attributed to Gauss](https://brilliant.org/wiki/sum-of-n-n2-or-n3/):

$$
\sum\limits_{a = 1}^{n} a = \frac{n (n+1)}{2}
\newline
\sum\limits_{a = 1}^{n} a^2 = \frac{n (n+1) (2n+1)}{6} 
$$

If we apply these summation formulas to our equation:

$$
b \sum\limits_{k = 0}^{b-1} k - \sum\limits_{k = 0}^{b-1} k^2
= b \frac{(b-1) (b-1+1)}{2} - \frac{(b-1) (b-1+1) [2(b-1) + 1]}{6}
= \newline
= b \frac{(b-1) b}{2} - \frac{(b-1) b (2b-1)}{6}
= \frac{b^3- b^2}{2} - \frac{(b^2-b) (2b-1)}{6}
= \newline
= \frac{b^3- b^2}{2} - \frac{2b^3 - b^2 - 2b^2 + b}{6}
= \frac{3b^3 - 3b^2}{6} - \frac{2b^3 - 3b^2 + b}{6}
= \newline
= \frac{3b^3 - 3b^2 - 2b^3 + 3b^2 - b}{6}
= \frac{b^3 - b}{6}
$$

We have significantly simplified the original equation into: 

$$
counter = \frac{b^3 - b}{6}
$$ 

which we can implement as a one-liner:

```java
long counter = (b * b * b - b) / 6;
```

Are you not believing that this works? You can try the code yourself:

```java
public static void main(String[] args) {
    for (long b = 0; b <= 10000; b++) {
        long counter = original(b);
        long fastCounter = fast(b);
        System.out.printf("%d\t%d\t%d%n", b, counter, fastCounter);
        if (counter != fastCounter) {
            System.out.println("Failed");
            return;
        }
    }
    System.out.println("Worked");
}

private static long original(final long b) {
    long counter = 0;
    for (int k = 0; k < b; k++) {
        for (int a = k; a < b; a++) {
            counter += k;
        }
    }
    return counter;
}

private static long fast(final long b) {
    return (b * b * b - b) / 6;
}
```

you will see:

```
9995	166416789980	166416789980
9996	166466744990	166466744990
9997	166516709996	166516709996
9998	166566684999	166566684999
9999	166616670000	166616670000
10000	166666665000	166666665000
Worked
```

This new fast algorithm has a runtime complexity of just $$ O(1) $$ and great performance as it
needs only 4 arithmetical operations. We should strive to improve the new algorithm further, taking care of 
edge cases like integer overflow, but who knows, this could be the optimal solution for the problem. One way or 
another, it's good to take a step back when dealing with algorithms.
