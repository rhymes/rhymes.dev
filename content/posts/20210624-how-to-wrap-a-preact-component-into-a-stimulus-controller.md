---
date: 2021-06-24T13:51:54Z
description: How to wrap a Preact component into a Stimulus controller
slug: how-to-wrap-a-preact-component-into-a-stimulus-controller
tags: [javascript, preact, stimulus]
title: How to wrap a Preact component into a Stimulus controller
---

In this post I'm going to illustrate the following:

- wrapping a Preact component inside a Stimulus controller
- loading Preact and the component asynchronously on demand
- communicating with the wrapped component via JavaScript [custom events](https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/CustomEvent)

This is partly based on work [Suzanne Aitchison](https://dev.to/s_aitchison) did [last February on Forem](https://github.com/forem/forem/pull/12511). Forem's public website uses Preact and vanilla JavaScript. Some of Forem's Admin views are using Stimulus. This is an example of how to recycle frontend components from one framework to another.

I'm also assuming the reader has some familiarity with both Preact and Stimulus.

## Wrapping the component

Yesterday I was working on some Admin interactions and I wanted to reuse [Forem's `Snackbar` component](https://storybook.dev.to/?path=/story/app-components-snackbar-snackbar--simulate-adding-snackbar-items):

![Example of Snackbar component in action](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/h3oipmo4hf7jv0zo0ype.png)

How it is implemented inside Preact is not important for our purposes and I haven't checked either, I just know its module exports `Snackbar` and a function `addSnackbarItem` to operate it.

As the screenshot shows, it is similar to [Material's `Snackbar` component](https://material.io/components/snackbars), as it provides *brief messages about app processes at the bottom of the screen*.

With that in mind and with the groundwork laid by Suzanne Aitchison on [a different component](https://github.com/forem/forem/blob/main/app/javascript/admin/controllers/modal_controller.js), I wrote the following code:

```js
import { Controller } from 'stimulus';

// Wraps the Preact Snackbar component into a Stimulus controller
export default class SnackbarController extends Controller {
  static targets = ['snackZone'];

  async connect() {
    const [{ h, render }, { Snackbar }] = await Promise.all([
      // eslint-disable-next-line import/no-unresolved
      import('preact'),
      import('Snackbar'),
    ]);

    render(<Snackbar lifespan="3" />, this.snackZoneTarget);
  }

  async disconnect() {
    const { render } = await import('preact');
    render(null, this.snackZoneTarget);
  }

  // Any controller (or vanilla JS) can add an item to the Snackbar by dispatching a custom event.
  // Stimulus needs to listen via this HTML's attribute: data-action="snackbar:add@document->snackbar#addItem"
  async addItem(event) {
    const { message, addCloseButton = false } = event.detail;

    const { addSnackbarItem } = await import('Snackbar');
    addSnackbarItem({ message, addCloseButton });
  }
}
```

Let's go over it piece by piece.

### Defining a container

```js
static targets = ['snackZone'];
```

Most Preact components need a container to render in. In Stimulus lingo we need to define a "target", which is how the framework calls important HTML elements referenced inside its controller (the main class to organize code in).

This is defined as a regular HTML `<div>` in the page:

```html
<div data-snackbar-target="snackZone"></div>
```

Inside the controller, this element can be accessed as `this.snackZoneTarget`. [Stimulus documentation has more information on targets](https://stimulus.hotwire.dev/reference/targets).

(*snackZone* is just how the `Snackbar`'s container is called inside Forem's frontend code, I kept the name :D)

### Mounting and unmounting the component

The `Snackbar` component, when initialized, doesn't render anything visible to the user. It waits for a message to be added to the stack of disappearing messages that are shown to the user after an action is performed. For this reason, we can use Stimulus lifecycle callbacks to mount it and unmount it.

Stimulus [provides two aptly named callbacks](https://stimulus.hotwire.dev/reference/lifecycle-callbacks), `connect()` and `disconnect()`, that we can use to initialize and cleanup our Preact component.

When the Stimulus controller is attached to the page, it will call the `connect()` method, in our case we take advantage of this by loading Preact and the Snackbar component:

```js
async connect() {
  const [{ h, render }, { Snackbar }] = await Promise.all([
    import('preact'),
    import('Snackbar'),
  ]);

  render(<Snackbar lifespan="3" />, this.snackZoneTarget);
}
```

Here we accomplish the following:

- asynchronously load Preact, importing [its renderer function](https://preactjs.com/guide/v10/api-reference#render)
- asynchronously load [Forem's `Snackbar` component](https://storybook.dev.to/?path=/story/app-components-snackbar-snackbar--simulate-adding-snackbar-items)
- rendering the component inside the container

To be "good citizens" we also want to clean up when the controller is disconnected:

```js
async disconnect() {
  const { render } = await import('preact');
  render(null, this.snackZoneTarget);
}
```

This destroys Preact's component whenever Stimulus unloads its controller from the page.

### Communicating with the component

Now that we know how to embed Preact into Stimulus, how do we send messages? This is where the JavaScript magic lies :-)

Generally, good software design teaches us to avoid coupling components of any type, regardless if we're talking about JavaScript modules, Ruby classes, entire software subsystems and so on.

JavaScript's [CustomEvent Web API](https://developer.mozilla.org/en-US/docs/Web/Events/Creating_and_triggering_events#adding_custom_data_%E2%80%93_customevent) comes to the rescue.

With it it's possible to lean in the standard pub/sub architecture that JavaScript developers are familiar with: an element listens to an event, handles it with a handler and an action on another element triggers an event. The first element is the subscriber, the element triggering the event is the publisher.

With this is mind: what are Stimulus controllers if not also global event subscribers, reacting to changes?

First we need to tell Stimulus to listen to a custom event:

```html
<body
  data-controller="snackbar"
  data-action="snackbar:add@document->snackbar#addItem">
```

`data-controller="snackbar"` attaches Stimulus `SnackbarController`, defined in the first section of this post, to the `<body>` of the page.

`data-action="snackbar:add@document->snackbar#addItem"` instructs the framework to listen to the custom event `snackbar:add` on `window.document` and when received to send it to the `SnackbarController` by invoking its `addItem` method acting as en event handler.

`addItem` is defined as:

```js
async addItem(event) {
  const { message, addCloseButton = false } = event.detail;

  const { addSnackbarItem } = await import('Snackbar');
  addSnackbarItem({ message, addCloseButton });
}
```

The handler extracts, from the event custom payload, the message and a boolean that, if true, will display a button to dismiss the message. It then imports the method `addSnackbarItem` and invokes it with the correct arguments, to display a message to the user.

The missing piece in our "pub/sub" architecture is the published, that is given us for free via the Web API [`EventTarget.dispatchEvent`](https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/dispatchEvent) method:

```js
document.dispatchEvent(new CustomEvent('snackbar:add', { detail: { message: 'MESSAGE' } }));
document.dispatchEvent(new CustomEvent('snackbar:add', { detail: { message: 'MESSAGE', addCloseButton: false } }));
document.dispatchEvent(new CustomEvent('snackbar:add', { detail: { message: 'MESSAGE', addCloseButton: true } }));
```

The great advantage is that the publisher doesn't need to inside Stimulus at all, it can be any JavaScript function reacting to an action: the network, the user or any DOM event.

The `CustomEvent` interface is straightforward and flexible enough that can be used to create more advanced patterns like the, now defunct, [Vue Events API](https://v3.vuejs.org/guide/migration/events-api.html#events-api) which provided a global event bus in the page, out of scope for this post.

### Demo

![Video demo of Snackbar wrapped in Stimulus and invoked via dispatchEvent](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/qerjfpqnqg5ekushl114.gif)

## Conclusion

I hope this showed you a strategy of reuse when you're presented with multiple frameworks that have to interact with each other on a page.
