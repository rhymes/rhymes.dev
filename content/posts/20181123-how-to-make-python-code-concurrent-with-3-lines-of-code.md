---
date: 2018-11-23T20:05:51Z
description: How to make Python code concurrent with 3 lines
slug: how-to-make-python-code-concurrent-with-3-lines-of-code
tags: [python, concurrency]
title: How to make Python code concurrent with 3 lines
---

I was inspired by Ryan Palo's [quest to uncover gems in Python's standard library](https://dev.to/rpalo/defaultdicts-never-check-if-a-key-is-present-again-5hlp).

I decided to share one of my favorite tricks in Python's standard library through an example. The entire code runs on Python 3.2+ without external packages.

## The initial problem

Let's say you have a thousand URLs to process/download/examine, so you need to issue as much HTTP GET calls and retrieve the body of each response.

This is a way to do it:

```python
import http.client
import socket

def get_it(url):
    try:
        # always set a timeout when you connect to an external server
        connection = http.client.HTTPSConnection(url, timeout=2)

        connection.request("GET", "/")

        response = connection.getresponse()

        return response.read()
    except socket.timeout:
        # in a real world scenario you would probably do stuff if the
        # socket goes into timeout
        pass

urls = [
    "www.google.com",
    "www.youtube.com",
    "www.wikipedia.org",
    "www.reddit.com",
    "www.httpbin.org"
] * 200

for url in urls:
    get_it(url)
```

*(I wouldn't use the standard library as an HTTP client but for the purpose of this post it's okay)*

As you can see there's no magic here. Python iterates on 1000 URLs and calls each of them.

This thing on my computer occupies 2% of the CPU and spends most of the time waiting for I/O:

```shell
$ time python io_bound_serial.py
20.67s user 5.37s system 855.03s real 24292kB mem
```

It runs for roughly 14 minutes. We can do better.

## Show me the trick!

```python
from concurrent.futures import ThreadPoolExecutor as PoolExecutor
import http.client
import socket

def get_it(url):
    try:
        # always set a timeout when you connect to an external server
        connection = http.client.HTTPSConnection(url, timeout=2)

        connection.request("GET", "/")

        response = connection.getresponse()

        return response.read()
    except socket.timeout:
        # in a real world scenario you would probably do stuff if the
        # socket goes into timeout
        pass

urls = [
    "www.google.com",
    "www.youtube.com",
    "www.wikipedia.org",
    "www.reddit.com",
    "www.httpbin.org"
] * 200

with PoolExecutor(max_workers=4) as executor:
    for _ in executor.map(get_it, urls):
        pass
```

Let's see what changed:

```python
# import a new API to create a thread pool
from concurrent.futures import ThreadPoolExecutor as PoolExecutor

# create a thread pool of 4 threads
with PoolExecutor(max_workers=4) as executor:

    # distribute the 1000 URLs among 4 threads in the pool
    # _ is the body of each page that I'm ignoring right now
    for _ in executor.map(get_it, urls):
        pass
```

So, 3 lines of code, we made a slow serial task into a concurrent one, taking little short of 5 minutes:

```shell
$ time python io_bound_threads.py
21.40s user 6.10s system 294.07s real 31784kB mem
```

We went from 855.03s to 294.07s, a 2.9x increase!

## Wait, there's more

The great thing about this new API is that you can substitute

```python
from concurrent.futures import ThreadPoolExecutor as PoolExecutor
```

with

```python
from concurrent.futures import ProcessPoolExecutor as PoolExecutor
```

to tell Python to use processes instead of threads. Out of curiosity, let's see what happens to the running time:

```shell
$ time python io_bound_processes.py
22.19s user 6.03s system 270.28s real 23324kB mem
```

20 seconds less than the threaded version, not much different. Keep in mind that these are unscientific experiments and I'm using the computer while these scripts run.

## Bonus content

My computer has 4 cores, let's see what happens to the threaded versions increasing the number of worker threads:

```shell
# 6 threads
20.48s user 5.19s system 155.92s real 35876kB mem
# 8 threads
23.48s user 5.55s system 178.29s real 40472kB mem
# 16 threads
23.77s user 5.44s system 119.69s real 58928kB mem
# 32 threads
21.88s user 4.81s system 119.26s real 96136kB mem
```

Three things to notice: RAM occupation obviously increases, we hit a wall around 16 threads and at 16 threads we're more than 7x faster than the serial version.

If you don't recognize `time`'s output is because I've aliased it like this:

```shell
time='gtime -f '\''%Us user %Ss system %es real %MkB mem -- %C'\'
```

where `gtime` is installed by `brew install gnu-time`

## Conclusions

I think [ThreadPoolExecutor](https://docs.python.org/3.7/library/concurrent.futures.html#threadpoolexecutor) and [ProcessPoolExecutor](https://docs.python.org/3.7/library/concurrent.futures.html#processpoolexecutor) are super cool additions to Python's standard library. You could have done mostly everything they do with the "older" [threading](https://docs.python.org/3.7/library/threading.html), [multiprocessing](https://docs.python.org/3.7/library/multiprocessing.html) and with FIFO queues but this API is so much better.

