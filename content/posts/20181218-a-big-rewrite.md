---
date: 2018-12-18T17:09:14Z
description: A big rewrite
slug: a-big-rewrite
tags: [softwaredevelopment, rewrites]
title: A big rewrite
---

Folklore and common sense warn developers and teams against doing big rewrites.

## To do or not to do

There are many reasons not to rewrite apps from scratch:

* rewrites take time
* the "legacy" app still needs to be supported and probably debugged
* rewriting the same exact app hoping to change the outcome could be an early sign of madness
* requirements will definitely change from when you start to when you finish
* the company already paid for the "legacy" app, now you want it to pay for the same thing twice
* management will probably be hard to convince

If the rewrite is justified though, there are some positive aspects:

* the time spent rewriting is time you're going to learn a lot
* the "legacy" app has become garbage fire (because of turnover, feature creep, bad design, lack of expertise, Saturn in opposition, whatever) and is slowing growth
* even if you think so, you won't end up rewriting the exact same thing
* the changes in requirements might result in a different, better, product
* if you're not a startup, the "legacy" app is usually funding the rewrite anyway
* management and your colleagues will trust you a lot in future years if you all manage to pull this off
* you get rid of all the tech debt just by deleting a folder (and you get to create brand new debt :-D, but let's not be picky)

## Why I'm writing this

The other day I read two "old" posts about a successful "big rewrite".

In the first one, [Against the Grain: How We Built the Next Generation Online Travel Agency using Amazon, Clojure, and a Comically Small Team](http://www.colinsteele.org/post/23103789647/against-the-grain-aws-clojure-startup), [Colin Steele](https://www.linkedin.com/in/cvillecsteele/) narrates a journey of moving from a giant pile of tech debt that was going to sink the company to a successful re-engineered product. In the fray there are mistakes made and... a succesful acquisition from another company.

The product is a hotel meta search engine.

## The bulk of their story

### Premise

* they initially had the wrong business model (quite common with startups, at least in my experience)
* the app was a spaghetti of monolithic PHP probably worked on by many hands
* the database was a mess
* there were no tests
* he was hired as a consultant and extracted a key feature using Ruby and async programming but the rest was too far gone in his opinion

### Pre-execution

* he became CTO of such company and convinced management to attempt a rewrite
* they fired most of the existing devs and hired just a handful of seniors (another common theme in startups in damage control that are draining money)
* they started the rewrite while keeping the old product running
* they switched from hosted servers to cloud (keep in mind that this happened in 2010) which took convincing

### Tech choices

* the frontend dev wrote a SPA with vanilla JS (again, in 2010)
* after thorough testing and some guts they settled on Clojure (even if he was a Ruby expert). Ruby was abandoned because it required more resources to scale and they had none and because of its builtin concurrency model
* Clojure was the right choice from them. As he wrote: *as the CTO at a cash-strapped startup, Clojure was the answer to a prayer.*
* Clojure was probably an easier sell than usual because how tight they were with time and resources and how well management trusted the team (it would be a though sell in 2018, imagine in 2010)
* the type of web app they had and the performance testing they performed justified the choice (and saved the company money)

### Post execution

* they were acquired at the end of 2011
* all of the tech choices they made were questioned (why AWS, why Clojure)
* he says that they were able to "sell" the choice of Clojure to the new company because it sits on top of the JVM and because of the nice graphs about the performance of the system he showed them

### End of the story

From the second post, [60,000% growth in 7 months using Clojure and AWS](http://www.colinsteele.org/post/27929539434/60000-growth-in-7-months-using-clojure-and-aws)

> Over the course of the last 7 months (we launched in January 2012), we’ve gone from about 1,000 uniques/day on hotelicopter’s site, to 600,000+/day on roomkey.com.  That’s 60,000% growth in 7 months

So, the rewrite paid off.

Another thing to notice is the amount of trust management gave him and the team. Without that the rewrite would have probably failed or they would have run out of money or they would have had to incrementally refactor maybe taking more time. We'll never know.

If you want to read more about the tech choices and the stack read [this second post](http://www.colinsteele.org/post/27929539434/60000-growth-in-7-months-using-clojure-and-aws).

## An anectode from a solo rewrite I did

I once was hired to work on an unmaintanable app that had to be rewritten.

Coincidentally it was written in PHP as well and this too had a database structure that needed Sherlock Holmes to be deciphered. It took me at least a week of staring at MySQL tables with cryptic names and cryptic fields, googling PHP functions to figure out what happened to the data (most of the DB logic was in the app) and to design a new DB that was sane.

I ended up rewriting the app in a short time in Python (and migrate the data). It worked :D

The scope was smaller though and I had no choices to justify, they needed someone with expertise to bring a legacy app to a known stack and then hand it over.

The good thing about this rewrite is that knowledge of the previous stack wasn't ultimately required and I was happy to mostly ignore the app code and being able to focus on the data to bring along and the requirements.

Now that I'm writing this, I think the "legacy app" could also be used as an argument in favor of frameworks for less experienced developers working in small companies where they might not have seniors to interact with day to day. But I digress.

## Conclusions

Keep in mind that there's not a single way to accomplish a rewrite, you might pull it off with a mixture of refactoring and rewrite, for more on this I defer to Blaine Osepchuk's [The Rewrite vs Refactor Debate: 8 Things You Need to Know](https://dev.to/bosepchuk/the-rewrite-vs-refactor-debate-8-things-you-need-to-know-2hi4).

If you want to read another success story (seemingly less wild in its premises), read [I ran a ludicrously complex engineering project (and survived)](https://dev.to/atlassian/i-ran-a-ludicrously-complex-engineering-project-and-survived-2a54).
