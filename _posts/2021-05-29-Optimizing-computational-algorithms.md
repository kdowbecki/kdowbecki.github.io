---
layout: post
title: "Optimizing computational algorithms"
categories: [Algorithm]
katex: true
---

When optimizing an algorithm it's often good to pause, take a step back, and think about the problem domain before 
jumping straight to coding. Today I have seen following question asked on Stack Overflow:

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
remember the `counter` variable value from the previous loop iteration? Perhaps we could create another variable... 
Here we should pause and take a step back. 

The above code can be represented as a mathematical equation, let's write it down:

$$
counter = \sum\limits_{k = 0}^{b-1} \sum\limits_{a = k}^{b-1} k
$$ 

The inner sum is $$ k $$ added from $$ k $$ to $$ b-1 $$ (inclusive) times. In total
$$ k $$ is going to be added $$ b - 1 - k + 1 = b - k $$ times here. Knowing this we can expand the inner sum:

$$
\sum\limits_{k = 0}^{b-1} \sum\limits_{a = k}^{b-1} k
= \sum\limits_{k = 0}^{b-1} [k(b-k)]
= \sum\limits_{k = 0}^{b-1} (kb-k^2)
= \sum\limits_{k = 0}^{b-1} kb - \sum\limits_{k = 0}^{b-1} k^2
= b \sum\limits_{k = 0}^{b-1} k - \sum\limits_{k = 0}^{b-1} k^2
$$

We have converted a sum of sums into two separate sums. In the process removed $$ a $$ making it simpler. 
To solve the two sums we can use [known summation formulas, often attributed to Gauss](https://brilliant.org/wiki/sum-of-n-n2-or-n3/):

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

We have significantly simplified the original nested sum equation into just: 

$$
counter = \frac{b^3 - b}{6}
$$ 

which can be implemented as a one-liner:

```java
long counter = (b * b * b - b) / 6;
```

If you are not believing that the new formula works you can try the code yourself:

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

private static long original(long b) {
    long counter = 0;
    for (int k = 0; k < b; k++) {
        for (int a = k; a < b; a++) {
            counter += k;
        }
    }
    return counter;
}

private static long fast(long b) {
    return (b * b * b - b) / 6;
}
```

You will observe:

```
9995	166416789980	166416789980
9996	166466744990	166466744990
9997	166516709996	166516709996
9998	166566684999	166566684999
9999	166616670000	166616670000
10000	166666665000	166666665000
Worked
```

This new fast algorithm has a runtime complexity of just $$ O(1) $$ and great performance with
just 4 arithmetic operations. We can always strive to improve this new approach, taking care of 
edge cases like integer overflow. However, this might already be the optimal solution.
