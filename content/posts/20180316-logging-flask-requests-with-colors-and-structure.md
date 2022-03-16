---
date: 2018-03-16T10:29:39Z
description: Logging Flask requests with structure and colors
slug: logging-flask-requests-with-colors-and-structure
tags: [flask, python, logging]
title: Logging Flask requests with structure and colors
---

Logging is one of those things on which all developers agree, what we don't agree with is the format.

You can log using "free text", agree on a structure of use full JSON.

I tend to use a combination of free text and structured logging. My favorite logging library so far is [lograge](https://github.com/roidrage/lograge) for Rails which funnily enough is described by the authors as `"An attempt to tame Rails' default policy to log everything"`.

Flask definitely doesn't get logging right by default and I think it has to do also with how complicated Python's default [logging](https://docs.python.org/3/library/logging.html) which honestly I never completely understood.

Anyway, back on the scope of the article. Lograge is pretty neat because it turns this:

```text
Started GET "/" for 127.0.0.1 at 2012-03-10 14:28:14 +0100
Processing by HomeController#index as HTML
  Rendered text template within layouts/application (0.0ms)
  Rendered layouts/_assets.html.erb (2.0ms)
  Rendered layouts/_top.html.erb (2.6ms)
  Rendered layouts/_about.html.erb (0.3ms)
  Rendered layouts/_google_analytics.html.erb (0.4ms)
Completed 200 OK in 79ms (Views: 78.8ms | ActiveRecord: 0.0ms)
```

into this:

```text
method=GET path=/jobs/833552.json format=json controller=JobsController  action=show status=200 duration=58.33 view=40.43 db=15.26
```

I wanted to replicate that with the [latest released version of Flask](https://pypi.python.org/pypi/Flask/0.12.2) (v0.12.2) and add some coloring to get to this:

![colorized logging](https://thepracticaldev.s3.amazonaws.com/i/a810d2ap3r8fgvnncsb3.png)

**Info to collect**

As you can see from the image we need:

* request method
* request path
* response status code
* request time
* time stamp in RFC339 format
* request ip
* request host
* request params

**How to collect it in Flask**

Flask has hooks to inject your code at different stages of requests. A bit like Rails request filters.

We're going to use [before_request](http://flask.pocoo.org/docs/0.12/api/#flask.Flask.before_request) and [after_request](http://flask.pocoo.org/docs/0.12/api/#flask.Flask.after_request).

The first thing we're going to collect it the timestamp of the beginning of the request:

```python
@app.before_request
def start_timer():
    g.start = time.time()
```

`app` is the Flask app, `g` is the [flask global object](http://flask.pocoo.org/docs/0.12/api/#flask.g) and `time.time()` well... you know :-)

The rest of the information can be collected after the request is finished with:

```python
@app.after_request
def log_request(response):
    if request.path == '/favicon.ico':
        return response
    elif request.path.startswith('/static'):
        return response

    now = time.time()
    duration = round(now - g.start, 2)
    dt = datetime.datetime.fromtimestamp(now)
    timestamp = rfc3339(dt, utc=True)

    ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    host = request.host.split(':', 1)[0]
    args = dict(request.args)
```

* This does not log the favicon or requests for static files. You might want to keep them
* The timestamp is in UTC, you might want it in a specific timezone but I tend to like logs in UTC. I use [rfc3339 library](https://pypi.python.org/pypi/rfc3339)
* It retrieves the IP address from `X-Forwarded-For` to give precedence to proxied requests, defaults to Flask's remote address
* Host is retrieved without the optional port

The next step is to create the params and add coloring:

```python
    log_params = [
        ('method', request.method, 'blue'),
        ('path', request.path, 'blue'),
        ('status', response.status_code, 'yellow'),
        ('duration', duration, 'green'),
        ('time', timestamp, 'magenta'),
        ('ip', ip, 'red'),
        ('host', host, 'red'),
        ('params', args, 'blue')
    ]
    request_id = request.headers.get('X-Request-ID')
    if request_id:
        log_params.append(('request_id', request_id, 'yellow'))
```

I also optionally log the `request id` which is set by Heroku.

The last part is actually building the line and outputting it:

```python
    parts = []  # as any dev I hate naming temporary variables :-)
    for name, value, color in log_params:
        part = color("{}={}".format(name, value), fg=color)
        parts.append(part)
    line = " ".join(parts)

    app.logger.info(line)

```

`color` comes from the [ansicolors](https://pypi.python.org/pypi/ansicolors) library.

This is the whole snippet:

```python
import datetime
import time

import colors
from flask import g, request
from rfc3339 import rfc3339

app = create_your_flask_app()


@app.before_request
def start_timer():
    g.start = time.time()


@app.after_request
def log_request(response):
    if request.path == '/favicon.ico':
        return response
    elif request.path.startswith('/static'):
        return response

    now = time.time()
    duration = round(now - g.start, 2)
    dt = datetime.datetime.fromtimestamp(now)
    timestamp = rfc3339(dt, utc=True)

    ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    host = request.host.split(':', 1)[0]
    args = dict(request.args)

    log_params = [
        ('method', request.method, 'blue'),
        ('path', request.path, 'blue'),
        ('status', response.status_code, 'yellow'),
        ('duration', duration, 'green'),
        ('time', timestamp, 'magenta'),
        ('ip', ip, 'red'),
        ('host', host, 'red'),
        ('params', args, 'blue')
    ]

    request_id = request.headers.get('X-Request-ID')
    if request_id:
        log_params.append(('request_id', request_id, 'yellow'))

    parts = []
    for name, value, color in log_params:
        part = colors.color("{}={}".format(name, value), fg=color)
        parts.append(part)
    line = " ".join(parts)

    app.logger.info(line)

    return response
```

