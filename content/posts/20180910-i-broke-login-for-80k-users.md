---
date: 2018-09-10T17:40:07Z
lastmod: 2018-09-12T11:08:08Z
description: Breaking login due to Doorkeeper updates
slug: i-broke-login-for-80k-users
tags: [ruby, rails, webdev]
title: I broke login for 80k users
---

Let me start by saying that I'm not happy about this :-D

The following is a post mortem of carelessness, naivety and bad changelogs and upgrade guides.

## What happened

A client of mine has a mobile app with a login that uses [OAuth2 Password Grant](https://www.oauth.com/oauth2-servers/access-tokens/password-grant/). It's an app both for Android and iOS.

We started receiving complaints about users that couldn't login so I went into "investigative mode" (which lasted the entire day until now).

The app is the "classic" app nobody really cares about made by numerous system integrators that talks to many servers, among them this API I wrote for the login part. I honestly have no idea how the mobile app works internally, I've never seen the code but I wrote the server side API and it has worked for many years.

The Rails server also has been successfully migrated across all 4.x versions and to 5.2, still the tests we did always worked. The Rails server is the backend of various different mobile apps sharing common functionality. Definitely pre Firebase or App Sync :D

Going back to the main issue: some users couldn't login. I started talking to the mobile developer that inherited the code of the app (he's not the original coder) and we discussed the situation.

Note: this is many weeks after the first complaints. August is a dead month in Italy. The mobile team was on holiday, the system integrator was on holiday, my client's client was on holiday. Probably also the poor users were on holiday and trying to use the app from there.

At the same time other parts of the app stopped working. Again, I have no idea how it actually works, I only see the API logs of the traffic they make on one server but I know the code more or less by memory and there was definitely no reason the rest of the app had anything to do with this functionality. Well unless there's poor exception handling and flows I'm not privy about but that's total speculation.

I asked the usual questions: did you recently released a new version? Can we have a log of the actions of the user (which they don't have, a story for another day) and so on.

After receiving an account on the help desk app (yay) we noticed a pattern: only Android devices were failing: potentially 80 thousand users, in reality they received 400 complaints. Still, a lot but it could have been way worse. I guess even users are chill about this app.

## Sherlock moment

I then downloaded 40 days of logs and started using [ripgrep](https://github.com/BurntSushi/ripgrep) (written in Rust, best grep tool ever with look ahead and look behind) to find clues about what was going on. I found anomalies in the the pattern of API calls made by the REST clients.

After that I convinced the mobile developer to start debugging the app.

I also noticed that the day before the first emails I released an update for [doorkeeper](https://github.com/doorkeeper-gem/doorkeeper), Rails OAuth2 server (we'll get back to this later). I reverted that but still... it didn't work.

I asked the mobile developer to show me the login code (I haven't read Java code in years :D). After a few minutes I discovered a bug in the client: if the refresh token is expired the code raises an exception but fails to login again.

We decided this could have been the case and ask one of the customers to reinstall the app, confident that a new set of oauth tokens would do the trick. The customer comes back a few minutes later saying it doesn't work. The fact that the mobile team doesn't even use this app tells you a lot, we had to ask a customer through the help desk to reproduce the error...

I start to sweat a little. In the meantime iOS goes on without a breeze. I know for sure that my Rails app doesn't make any distinction between platforms. A REST client is just a REST client, regardless of platform.

I go back to Doorkeeper's GitHub. I start re-reading the [changelog](https://github.com/doorkeeper-gem/doorkeeper/blob/master/NEWS.md), the [upgrade guide](https://github.com/doorkeeper-gem/doorkeeper/wiki/Migration-from-old-versions) (even though I reverted the version in the meantime) and the issues and a couple of things starts to feel weird:

![doorkeeper 4.4.0](https://thepracticaldev.s3.amazonaws.com/i/zbb65c9i4o0fdsl83c9u.png)

which points to [issue 1120](https://github.com/doorkeeper-gem/doorkeeper/pull/1120) a backport of a security issue about the ability to revoke tokens.

I think "well, what does it have to do with me?", we're not having issues with revoking access tokens anyway. Also, what is this "confidential" thing they are warning about all of a sudden?

In the upgrade I notice another clue:

![doorkeeper 4x to 5.0](https://thepracticaldev.s3.amazonaws.com/i/e0zufmlu4th64a0uttgp.png)

> Doorkeeper::Application now has a new boolean column named confidential that is true by default and has NOT NULL CONSTRAINT. This column is required to allow creating Public & Private Clients as mentioned in Section 8.5 of draft-ietf-oauth-native-apps-12 of OAuth 2 RFC. If you are migrating from Doorkeeper <= 5.0, then you can easily add this column by generating a proper migration file using the following command: rails g doorkeeper:confidential_applications.

Please tell me that is totally unclear to you too.

I end up skimming the OAuth2 RFC mentions because nothing in the changelog and in the upgrapde guide is clear enough.

In the meantime the mobile developer sends me the the API call the Android app is doing, in its curl version.

DING DING DING.

I instantly notice something: they are not sending the client secret. Wait what? They do a `git blame` on the code and tell me "the client secret part has been commented out for two years".

Then I'm sure the issue is somewhere on the server. That is apparently the only difference between Android and iOS.

DING DING DING.

This is when I get the intuition. The Doorkeeper upgrade guide says *a column named confidential that is true by default*. I open the production console, flip the flag to false and BOOM. Everything works.

## Conclusion

* The implications of the flag `confidential` are totally unclear from reading the changelog. Especially because the fix talks about revocation, not about making the client secret mandatory
* I should have spent way more time reading the diff (I didn't because I trusted the changelog)
* The flag `confidential` should probably be false by default
* Please please please Flutter make all of this nonsense of writing the same app twice with different bugs go away

As I said in the beginning the fact we took so long to figure this out is a combination of carelessness (I applied the security fix withouth reading the diff, just the changelog), naivety (I assumed the security fix about revocation was innocuous and I didn't test it in depth) and the fact that this app is definitely not a priority for anybody.

I have no moral of the story, I opened an issue on Doorkeper's GitHub: https://github.com/doorkeeper-gem/doorkeeper/issues/1142


**Update from 12th September 2018:** the issue ticket resulted in a clearer explanation in the wiki and changelog, yay :-)
