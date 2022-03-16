---
date: 2019-02-25T17:26:58Z
description: What can we learn from rewrites?
slug: what-can-we-learn-from-rewrites
tags: [softwaredevelopment, rewrites]
title: What can we learn from rewrites?
---

Rewrites are a classic argument in software development. Every software architect at some point ponders over the existential question: *Should I rewrite this app?*

As always, there's no universal answer to the question.

I finished reading quite a long article titled [Lessons from 6 software rewrite stories](https://medium.com/@herbcaudill/lessons-from-6-software-rewrite-stories-635e4c8f7c22).

In it the author, [Herb Caudill](https://twitter.com/herbcaudill), analyses six different famous rewrites that had different premises and outcomes. I really liked what he did and I'd like to use it as a basis for further the discussion here on DEV.

I'm going to give you a TLDR; with my own comments.

The first example is **Netscape** from way back at the end of the 90s. In an effort to mitigate the rise of Internet Explorer they decided to open up the browser to the open source community. It didn't pay off because the code was apparently a disaster and people didn't flock to it. They then decided to rewrite from scratch but well... it was too late, Microsoft was acting as a monopoly already and the first version wasn't great either. They managed to build Mozilla in the process, so kudos to that.

Main lesson here is: don't go on a tangent for years if you have a lot of technical debt and the competition is breathing down your neck.

The second example is **Basecamp**. They did a very smart thing in hindsight. Instead of rewriting the same exact app from scratch just to improve code quality or forcing customers to switch to a new product, they decided to redo their app with the lessons learned in years of customer service. New features but also discarded or re-engineered features. They did this twice (!!) by providing two very important things to existing customers: an upgrade path and never ending support for the previous versions.

Main lesson here is: by spawning their app starting from the design table they were able to increase the number of customers and not disappoint those happy with the status quo.

The third example is **Visual Studio Code**. Microsoft realized they were missing out on the cool developers like us ™ by only having Visual Studio as a platform and decided to write a new product from scratch not just by leveraging open source but by espousing it completely and opening the platform with extensions. We all know how correct their bet was. I'm writing this post from VS Code.

Main lesson here is: the correct combination of technology and intuition paid tenfold. We probably wouldn't have the editor without this "acceleration" all web developers are experiencing. They probably also learned something from GitHub's Atom, I'm not sure.

The fourth example is **Gmail** plus **Inbox**. I've never used Inbox so I'm not sure what I've missed out on but I remember [Andy Zhao](https://dev.to/andy) writing about it. Inbox was basically a different UI on the same backend Gmail uses. Unfortunately, as standard Google's behavior goes: they launched it as an experiment and then cancelled it after a while disappointing users. The silver lining is that some of the features were incorporated in Gmail.

Main lesson here: don't bait users :D No, I'm kidding. The main lesson here is that writing a new UI on the same backend might complicate your life considerably (it's not like you can easily change it if it serves your main app anyway).

The fifth example is **FogBugz** plus **Trello**. The path here was weird. They wrote a successful app, FogBugz, and then when the technology it was based on it was showing its age they decided to invent a new language and compiler from scratch that had popular languages as targets. They also decided to add all the features possible to it, in an effort to catch up with Atlassian's JIRA. They then decided to write an entirely new app, Trello, on popular bleeding edge technology (at the time). It fortunately worked and they finally sold it to the competitor they were fearing for the first product, Atlassian.

Main lesson here: the company behind these two products survived them, among other reasons, because they optimized for developer happiness, and they understood that in time (it's not coincidental that they ended up with Glitch after Trello).

The sixth example is **Freshbooks**. Classic tale: a lot of technical debt and a code base in a bad state. The founder decided to do some lateral thinking, incorporated a new company, set a time limit and went all in with Agile to create a competitor to its own product. Customers loved it. They then provided a migration path back and forth. In my experience Agile done right works well for MVPs.

Main lesson here: by virtually separating the two products the founder created a lot of mental space in which the development team thrived by creating what would they had perceived as a better product than their own.

#### Conclusions

The connecting thread between all six examples (I'm unsure if Inbox's story is the same) is what the author of the article calls *developer happiness*. Netscape rewrite bombed also because they failed to attract developers, Basecamp is notoriously a place where they treat employees fairly and they keep open sourcing projects (Rails, Turbolinks, Stimulus.js), Visual Studio Code (and TypeScript) managed to make Microsoft cool again in the eyes of developers, FogCreek morphed itself into Glitch which is an amazing platform for developers at all skill levels, Freshbooks used jedi mind tricks to make developers happy about doing a rewrite. I don't know what Google did :D
