---
date: 2017-12-27T07:17:54Z
description: Awaiting for async promises in JavaScript
slug: awaiting-for-async-promises-in-javascript
tags: [javascript, python, async]
title: Awaiting for async promises in JavaScript
---

*This post originated as a comment to [Daniel Warren](https://dev.to/warrend)'s post [Clarifying Async and Promises](https://dev.to/warrend/clarifying-async-and-promises-4h38) and I decided to repost it as a separate article because it might be useful to others.*

I was exploring the other day the possibilities beyond the "then/catch" pattern with promises because to me it still looks like callbacks, neater and cleaner but there has to be a better way, for readability's sake.

In Python land (see the [Twisted framework which influenced Node.js](https://nodejs.org/en/about/)) this problem has been already met. In Twisted promises are called "deferreds" but the issue is the same: cascading callbacks, error handlers, callbacks to your error handlers, sibling callbacks and error handlers can still become a mess to read and understand:

```js
.then(() => {}).then(() => {}).then(() => {}).catch((err) => {})
```

or in Twisted

```python
.addCallback(function).addCallback(function).addCallback(function).addErrback(errHandler)
```

What they came up with is:

> a decorator named inlineCallbacks which allows you to work with Deferreds without writing callback functions.

So in Twisted you can do this:

```python
@inlineCallbacks
def getUsers(self):
    try:
        responseBody = yield makeRequest("GET", "/users")
    except ConnectionError:
       log.failure("makeRequest failed due to connection error")
       return []

   return json.loads(responseBody)
```

`makeRequest` returns a deferred (a promise) and this way instead of attaching callbacks and error handlers to it you can wait for the response to come back and if an error arises you handle it there and then with `try...except` (try/catch in JS). In the latest Python versions you can even do this:

```python
async def bar():
    baz = await someOtherDeferredFunction()
    fooResult = await foo()
    return baz + fooResult
```

So you can basically use `await` for the deferred/promises to resolve and write synchronous-looking code instead of attaching callbacks, which brings me back to JavaScript and async/await (same keywords of Python, don't know which came first :D).

Instead of attaching callbacks and error handler to your promise you can use async/await to write more readable code:

```js
async function bar() {
  const a = await someFunction();
  const b = await someOtherFunction();
  return a + b;
}
```

I found this video by Wes Bos very informing:

{{< youtube 9YkUCxvaLEk >}}


* [Twisted deferreds](https://twistedmatrix.com/documents/current/core/howto/defer-intro.html)
