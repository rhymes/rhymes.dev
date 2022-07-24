---
date: 2022-07-24T20:45:18Z
description: How to save memory with Celery using Redis as a backend
slug: how-to-save-memory-with-celery-using-redis-as-a-backend
tags: [celery, python]
title: How to save memory with Celery using Redis as a backend
---

If you're working a Python web app, there's a good probability you are using [Celery](https://docs.celeryq.dev/en/stable/) (or [RQ](https://python-rq.org/)) to offload work to a background queue.

In its simplest form a Celery unit of work (task) looks like this:

```python
@app.task
def hello():
    return 'hello world'
```

A regular Python method, with a decorator to declare it as a task and a(n optional) return value.

Celery runs at least one worker process, which asks the broker (the queue transport) for the next task to process and optionally stores its result in what Celery calls a "backend". Celery supports a combination of brokers and backends, though the most popular options are respectively RabbitMQ and Redis.

Stored results are what we're going to look at in this short post.

By default Celery doesn't need a backend, but many apps do enable it, including the one I'm working on for a client.

When [result_backend](https://docs.celeryq.dev/en/stable/userguide/configuration.html#result-backend) is enabled, all tasks will default to store their results.

Each time a task runs, the method's return value is saved (for 24 hours by default, by comparison RQ stores results for 500 seconds) in the backend, Redis for example. Celery creates an expiring key with the value and some metadata.

The main reason a task would return a value, for something that runs out of process from the main app, is for composition purposes. Celery supports passing the return value of a task to a following task, creating a chain of operations.

In the scenario I was working on we had a chain of tasks running at regular intervals (either triggered by business logic or manually by the user of the app), each time those tasks were running they were producing a bunch of stored values to feed to the next task, possibly.

You can see how, after a certain threshold of activity by the users, there's a probability that the memory limit of the backend is reached, creating a less than ideal scenario.

In contrast, a similar tool in Ruby-land, Sidekiq, [doesn't even have the concept of a backend / result store](https://github.com/mperham/sidekiq/issues/3532#issuecomment-311758678=). If you want your task (they're called jobs over there) to save its result value, you store it manually somewhere.

## How to configure Celery to use less memory?

First I audited all the tasks and realized that only less than 5% of all of them actually needed their result stored (as they were passing it along to a subsequent task in a chain).

This meant that the backend itself was needed, but most results themselves weren't, especially as they were stored continuously, all day.

I then [configured Celery](https://docs.celeryq.dev/en/stable/userguide/configuration.html?#task-ignore-result) to ignore results by default and lower the expiration of those that are stored by setting:

```python
task_ignore_result=True
task_store_errors_even_if_ignored=True
result_expires=43200
```

Other things to keep in mind: [Redis itself can be configured to evict keys](https://redis.io/docs/manual/eviction/) thus potentially never reaching its limit. Though definitely important, if not paramount in some situations, understanding what is causing the memory issues was my priority.

## How to tell Celery not to ignore results when they are needed?

Remember the initial task?

```python
@app.task
def hello():
    return 'hello world'
```

Add a param to the decorator:

```python
@app.task(ignore_result=False)
def hello():
    return 'hello world'
```

[ignore_result](https://docs.celeryq.dev/en/stable/userguide/tasks.html#ignore-results-you-don-t-want) is the magic keyword.

## Conclusion

After deploying the change and waiting for the existing result keys in Redis to expire, a noticeable reduction in the memory footprint was witnessed, with a 7x reduction in number of Redis keys and a lot of saved bandwidth of course.

![Graphs describing dramatic drop in Redis total commands per sec, hits/miss per sec, total memory usage and network I/O](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/wnncrznmgqy2z69nzq92.png)

Keep an eye on those Celery tasks ;-)
