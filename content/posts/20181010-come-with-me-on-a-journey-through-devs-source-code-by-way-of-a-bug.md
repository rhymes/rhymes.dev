---
date: 2018-10-09T22:02:25Z
description: A journey in debugging DEV's source code
slug: come-with-me-on-a-journey-through-devs-source-code-by-way-of-a-bug
tags: [webdev, rails, opensource]
title: Come with me on a journey through DEV's source code by way of a bug
---

This article started because I thought that researching a particular bug could be useful to understand devto's source code a little better. So I literally wrote this while doing the research and I ended up writing about other things as well. Here we go.

The bug I'm referring to is called [Timeouts when deleting a post](https://github.com/thepracticaldev/dev.to/issues/821) on GitHub. As the title implies, removing a post results in a server timeout which results in an error to the user. [Peter Frank](https://dev.to/peter) in his bug report added a couple of details we need to keep present for our "investigation": this bug doesn't always happens (which would be better in the context of finding a solution, deterministic is always better) and it more likely presents itself with articles that have many reactions and comments.

First clues: it happens sometimes and usually with articles with a lot of data attached.

Let's see if we can dig up more information _before_ diving into the code.

A note: I'm writing this post to explain (and expand) the way I researched this while it happened at the same time (well, over the course of multiple days but still at the same time :-D), so all discoveries were new to me when I wrote about them as they are to you if you read this.

Another note: I'm going to use the terms "async" and "out of process" interchangeably here. Async in this context means "the user doesn't wait for the call to be executed" not "async" as in JavaScript. A better term should be "out of process" because these asynchronous calls are executed by an external process through a queue on the database with a library/gem called [delayed job](https://github.com/collectiveidea/delayed_job/).

## Referential integrity

ActiveRecord (Rails's ORM), like many other object relational mappers, is an object layer that sits on top of a relational database system. Let's take a little detour and talk a little about a fundamental feature to preserve data meaningfulness in database systems: referential integrity. Why not, the bug can wait!

[Referential integrity](https://en.wikipedia.org/wiki/Referential_integrity), to simplify a lot, is a defense against developers with weird ideas on how to structure their relational data. It forbids insertion of rows that have no correspondence in the primary table of the relationship. In layman terms it guarantees that there is a correspondent row in the relationship: if you have a table with a list of 10 cities, you shouldn't have a customer whose address belongs to an unknown city. Funnily enough it took more than a decade for MySQL to activate referential integrity by default, while PostgreSQL had it for 10 years already, at the time. Sometimes I think that MySQL in its early incarnations was a giant collection of CSV files with SQL on top. I'm joking, maybe.

With referential integrity in place you can rest (mostly) assured that the database won't let you add zombie rows, will keep the relationship updated and will clean up after you if you tell it to.

How do you instruct the database to do all of these things? It's quite simple. I'll use an example from [PostgreSQL 10 documentation](https://www.postgresql.org/docs/10/static/ddl-constraints.html):

```sql
CREATE TABLE products (
    product_no integer PRIMARY KEY,
    name text,
    price numeric
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    shipping_address text,
);

CREATE TABLE order_items (
    product_no integer REFERENCES products ON DELETE RESTRICT,
    order_id integer REFERENCES orders ON DELETE CASCADE,
    quantity integer,
    PRIMARY KEY (product_no, order_id)
);
```

The table `order_items` has two foreign keys, one towards `orders` and another that points to `products` (a classic example of many-to-many in case you're wondering).

Wnen you design tables like this you should ask yourself the following questions (in addition to the obvious ones like "what am I really doing with this data?"):

- what happens if a row in the primary table is deleted?

- do I want to delete all the related rows?

- do I want to set the referencing column to `NULL` ? in that case what does it mean for my business logic? does `NULL` even make sense for my data?

- do I want to set the column to its default value? what does it mean for my business logic? does this column even have a default value?

If you look back at the example what we're telling the database are the following two things:

- products cannot be removed, unless they do not appear in any order

- orders can be be removed at all times, and they take the items with them to the grave 😀

Keep in mind that removal in this context is still a fast operation, even in a context like dev.to's if an article were to have tables linked with a _cascade_ directive, it should still be a fast operation. DBs tend to become slow when a single `DELETE` triggers millions (or tens of millions) of other removals. I assume this is not the case (yet or in the future) but since the point of this whole section is to expand our knowledge about referential integrity and not to actually investigate the bug, let's keep on digging.

Next we open the console and check if the tables are linked to each other, using `psql` :

```shell
$ rails dbconsole
psql (10.5)
Type "help" for help.

PracticalDeveloper_development=# \d+ articles
...
Indexes:
    "articles_pkey" PRIMARY KEY, btree (id)
    "index_articles_on_boost_states" gin (boost_states)
    "index_articles_on_featured_number" btree (featured_number)
    "index_articles_on_hotness_score" btree (hotness_score)
    "index_articles_on_published_at" btree (published_at)
    "index_articles_on_slug" btree (slug)
    "index_articles_on_user_id" btree (user_id)
```

This table has a primary key, a few indexes but apparently no foreign key constraints (the indicators for referential integrity). Compare it with a table that has both:

```shell
PracticalDeveloper_development=# \d users
...
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_confirmation_token" UNIQUE, btree (confirmation_token)
    "index_users_on_reset_password_token" UNIQUE, btree (reset_password_token)
    "index_users_on_username" UNIQUE, btree (username)
    "index_users_on_language_settings" gin (language_settings)
    "index_users_on_organization_id" btree (organization_id)
Referenced by:
    TABLE "messages" CONSTRAINT "fk_rails_273a25a7a6" FOREIGN KEY (user_id) REFERENCES users(id)
    TABLE "badge_achievements" CONSTRAINT "fk_rails_4a2e48ca67" FOREIGN KEY (user_id) REFERENCES users(id)
    TABLE "chat_channel_memberships" CONSTRAINT "fk_rails_4ba367990a" FOREIGN KEY (user_id) REFERENCES users(id)
    TABLE "push_notification_subscriptions" CONSTRAINT "fk_rails_c0b1e39717" FOREIGN KEY (user_id) REFERENCES users(id)
```

This is what we learned so far: why referential integrity can come into play when you remove rows from a DB and that the `articles` table has no apparent relationships with any other table at the database level. But is this true in the web app? Let's move up one layer, diving into the Ruby code.

*ps. in the case of Rails (don't remember since which version) you can also see which foreign keys you have defined by looking in the [schema.rb](https://github.com/thepracticaldev/dev.to/blob/master/db/schema.rb) file.*

## ActiveRecord, associations and callbacks

Now that we know what referential integrity is, how to identify it and now that we know it's not at play in this bug we can move up a layer and check how is the [Article object](https://github.com/thepracticaldev/dev.to/blob/master/app/models/article.rb) defined (I'll skip stuff that I think it's not related to this article and the bug itself, altough I might be wrong because I don't know the code base well):

```ruby
class Article < ApplicationRecord
  # ...

  has_many :comments,       as: :commentable
  has_many :buffer_updates
  has_many :reactions,      as: :reactable, dependent: :destroy
  has_many  :notifications, as: :notifiable

  # ...

  before_destroy    :before_destroy_actions

  # ...

  def before_destroy_actions
    bust_cache
    remove_algolia_index
    reactions.destroy_all
    user.delay.resave_articles
    organization&.delay&.resave_articles
  end
end
```

A bunch of new information from that piece of code:

- Rails (but not the DB) knows that an article can have many comments, buffer updates, reactions and notifications (these are called "associations" in Rails lingo)

- Reactions are explictly dependent on the articles and they will be destroyed if the article is removed

- There's a callback that does a bunch of stuff (we'll explore it later) before the object and its row in the database are destroyed

- Three out of four associations are the `able` type, Rails calls these [polymorphic associations](https://guides.rubyonrails.org/association_basics.html#polymorphic-associations) because they allow the programmer to associate multiple types of objects to the same row, using two different columns (a string with the name of the model type the object belongs to and an id). They are very handy, though I always felt they make the database very dependent on the domain model (set by Rails). They can also require a [composite index](https://www.postgresql.org/docs/10/static/indexes-multicolumn.html) in the associated table to speed up queries

Similarly to what the underlying database system can do, ActiveRecord allows the developer to specify what happens to the related objects when the primary one is destroyed. According to the [documentation](https://guides.rubyonrails.org/association_basics.html#dependent) Rails supports: destroying all related objects, deleting all related objects, setting the foreign key to `NULL` or restricting the removal with an error. The difference between _destroy_ and _delete_ is that in the former case all related callbacks are executed prior to removal, in the latter one the callbacks are skipped and only the row in the DB is removed.

The [default strategy](https://api.rubyonrails.org/classes/ActiveRecord/Associations/ClassMethods.html#module-ActiveRecord::Associations::ClassMethods-label-Delete+or+destroy%3F) for the relationships without a `dependent` is to do nothing, which means leaving the referenced rows there in place. If it were up to me the default would be *the app doesn't start until you decided what to do with the linked models* but I'm not the person who designed ActiveRecord.

Keep in mind that the database trumps the code, if you define nothing at the Rails level but the database is configured to automatically destroy all related rows, then the rows will be destroyed. This is one of the many reasons why it's worth taking the time to learn how the DB works :-)

The last bit we haven't talked about the model layer is the callback which is probably where the bug manifests itself.

### The infamous callback

This _before destroy_ callback will execute prior to issuing the `DELETE` statement to the DB:

```ruby
def before_destroy_actions
  bust_cache
  remove_algolia_index
  reactions.destroy_all
  user.delay.resave_articles
  organization&.delay&.resave_articles
end
```

#### Cache busting

The first thing the callback does is call the method `bust_cache` which in turn [calls sequentially six times the Fastly API](https://github.com/thepracticaldev/dev.to/blob/master/app/labor/cache_buster.rb#L6) to purge the article's cache (each call to bust is two HTTP calls). It also does a cospicuos number of out of process calls to the same API (around 20-50, depends on the status of the article and the number of tags) but these don't matter because the user won't wait for them.

One thing to annotate: six HTTP calls are _always_ going out after you press the button to delete an article.

#### Index removal

dev.to uses Algolia for search, the call `remove_algolia_index` does the following:

- calls [algolia_remove_from_index!](https://github.com/algolia/algoliasearch-rails/blob/25436b69de166b60eb220890e2eb8a07ed65ac82/lib/algoliasearch-rails.rb#L587) which in turns calls the "async" version of the Algolia HTTP API which in reality does a [(fast) synchronous call to Algolia](https://github.com/algolia/algoliasearch-client-ruby/blob/2dcf070e2b9f4f446a85d1abf494269acc4dec42/lib/algolia/client.rb#L518) without waiting for the index to be cleared on their side. It's still a synchronous call subject adding to the user's latency

- calls Algolia's HTTP API other two times for other indexes

So, adding the previous 6 HTTP calls for Fastly, we're at 9 APIs called in process

#### Reactions destruction

The third step is `reactions.destroy_all` which as the call implies destroys all the reactions to the article. In Rails `destroy_all` simply iterates on all the objects and calls destroy on each of them which in turn activate all the "destroy" callbacks for proper cleanup. The [Reaction](https://github.com/thepracticaldev/dev.to/blob/master/app/models/reaction.rb) model has two `before_destroy` callbacks:

```ruby
class Reaction < ApplicationRecord
  # ...

  before_destroy :update_reactable_without_delay
  before_destroy :clean_up_before_destroy

  # ...
end
```

I had to dig a little bit to find out what the first one does (one of the things I dislike about the Rails way of doing things are the magical methods popping up everywhere, they make refactoring harder and they encourage coupling between the model and all the various gems). `update_reactable_without_delay` calls [update_reactable](https://github.com/thepracticaldev/dev.to/blob/master/app/models/reaction.rb#L76) (which has been declared as an async function by default) bypassing the queue. The result is a standard inline call the user waits for.

- `update_reactable` recalculates (this time out of process), the scores of the Article (a thing that should probably be avoided since the Article is up for removal) if the article has been published. Then (back inline) it reindexes the article (twice) calling Algolia, removes the reactions from Fastly's cache (each call to bust the cache is two Fastly's calls), busts another cache (two more HTTP calls) and possibly updates a column on the Article (which is probably not needed since it's going to be removed). The total is 6 HTTP calls: one async HTTP calls (the first one to Algolia), one other call to Algolia and four to Fastly. Let's annotate down the 5 the user has to wait for.

- `clean_up_before_destroy` reindexes the article on Algolia (a third time).

Let's sum up: a removal of a reaction amounts to 6 HTTP calls. If the article has a 100 reactions... well you can do the math.

Let's say the article had 1 reaction, plus the calls tallied before we're at around 15 HTTP calls:

- 6 to bust the cache of the article

- 3 to remove the article from the index

- 6 for the reaction attached to the article

There's an additional bonus HTTP call that I've identified by chance using a [gist to debug net/http calls](https://gist.github.com/ahoward/736721), it calls the [Stream.io API](https://github.com/GetStream/stream-rails#activerecord) to delete the reaction from the user's feed. A total of 16 HTTP calls.

This is what happens when a reaction is destroyed (I added the awesome gem [httplog](https://github.com/trusche/httplog) to my local installation):

```ruby
[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/Article_development/25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time"}
[httplog] Connecting: REDACTED.algolia.net:443
[httplog] Status: 200
[httplog] Benchmark: 0.357128 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.151Z","taskID":945887592,"objectID":"25"}

[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/searchables_development/articles-25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time","tag_list":["discuss","security","python","beginners"],"main_image":"https://pigment.github.io/fake-logos/logos/medium/color/8.png","id":25,"featured":true,"published":true,"published_at":"2018-09-30T07:44:48.530Z","featured_number":1538293488,"comments_count":1,"reactions_count":0,"positive_reactions_count":0,"path":"/willricki/-the-curious-incident-of-the-dog-in-the-night-time-3e4b","class_name":"Article","user_name":"Ricki Will","user_username":"willricki","comments_blob":"Waistcoat craft beer pickled vice seitan kombucha drinking. 90's green juice hoodie.","body_text":"\n\nMeggings tattooed normcore kitsch chia. Fixie migas etsy hashtag jean shorts neutra pork belly. Vice salvia biodiesel portland actually slow-carb loko chia. Freegan biodiesel flexitarian tattooed.\n\n\nNeque. \n\n\nBefore they sold out diy xoxo aesthetic biodiesel pbr\u0026amp;b. Tumblr lo-fi craft beer listicle. Lo-fi church-key cold-pressed.\n\n\n","tag_keywords_for_search":"","search_score":153832,"readable_publish_date":"Sep 30","flare_tag":{"name":"discuss","bg_color_hex":null,"text_color_hex":null},"user":{"username":"willricki","name":"Ricki Will","profile_image_90":"/uploads/user/profile_image/6/22018b1a-7afa-47c1-bbae-b829977828e4.png"},"_tags":["discuss","security","python","beginners","user_6","username_willricki","lang_en"]}
[httplog] Status: 200
[httplog] Benchmark: 0.031995 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.426Z","taskID":945887612,"objectID":"articles-25"}

[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/ordered_articles_development/articles-25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time","path":"/willricki/-the-curious-incident-of-the-dog-in-the-night-time-3e4b","class_name":"Article","comments_count":1,"tag_list":["discuss","security","python","beginners"],"positive_reactions_count":0,"id":25,"hotness_score":153829,"readable_publish_date":"Sep 30","flare_tag":{"name":"discuss","bg_color_hex":null,"text_color_hex":null},"published_at_int":1538293488,"user":{"username":"willricki","name":"Ricki Will","profile_image_90":"/uploads/user/profile_image/6/22018b1a-7afa-47c1-bbae-b829977828e4.png"},"_tags":["discuss","security","python","beginners","user_6","username_willricki","lang_en"]}
[httplog] Status: 200
[httplog] Benchmark: 0.047077 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.494Z","taskID":945887622,"objectID":"articles-25"}

[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/Article_development/25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time"}
[httplog] Status: 200
[httplog] Benchmark: 0.029352 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.541Z","taskID":945887632,"objectID":"25"}

[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/searchables_development/articles-25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time","tag_list":["discuss","security","python","beginners"],"main_image":"https://pigment.github.io/fake-logos/logos/medium/color/8.png","id":25,"featured":true,"published":true,"published_at":"2018-09-30T07:44:48.530Z","featured_number":1538293488,"comments_count":1,"reactions_count":0,"positive_reactions_count":1,"path":"/willricki/-the-curious-incident-of-the-dog-in-the-night-time-3e4b","class_name":"Article","user_name":"Ricki Will","user_username":"willricki","comments_blob":"Waistcoat craft beer pickled vice seitan kombucha drinking. 90's green juice hoodie.","body_text":"\n\nMeggings tattooed normcore kitsch chia. Fixie migas etsy hashtag jean shorts neutra pork belly. Vice salvia biodiesel portland actually slow-carb loko chia. Freegan biodiesel flexitarian tattooed.\n\n\nNeque. \n\n\nBefore they sold out diy xoxo aesthetic biodiesel pbr\u0026amp;b. Tumblr lo-fi craft beer listicle. Lo-fi church-key cold-pressed.\n\n\n","tag_keywords_for_search":"","search_score":154132,"readable_publish_date":"Sep 30","flare_tag":{"name":"discuss","bg_color_hex":null,"text_color_hex":null},"user":{"username":"willricki","name":"Ricki Will","profile_image_90":"/uploads/user/profile_image/6/22018b1a-7afa-47c1-bbae-b829977828e4.png"},"_tags":["discuss","security","python","beginners","user_6","username_willricki","lang_en"]}
[httplog] Status: 200
[httplog] Benchmark: 0.028819 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.612Z","taskID":945887642,"objectID":"articles-25"}

[httplog] Sending: PUT https://REDACTED.algolia.net/1/indexes/ordered_articles_development/articles-25
[httplog] Data: {"title":" The Curious Incident of the Dog in the Night-Time","path":"/willricki/-the-curious-incident-of-the-dog-in-the-night-time-3e4b","class_name":"Article","comments_count":1,"tag_list":["discuss","security","python","beginners"],"positive_reactions_count":1,"id":25,"hotness_score":153829,"readable_publish_date":"Sep 30","flare_tag":{"name":"discuss","bg_color_hex":null,"text_color_hex":null},"published_at_int":1538293488,"user":{"username":"willricki","name":"Ricki Will","profile_image_90":"/uploads/user/profile_image/6/22018b1a-7afa-47c1-bbae-b829977828e4.png"},"_tags":["discuss","security","python","beginners","user_6","username_willricki","lang_en"]}
[httplog] Status: 200
[httplog] Benchmark: 0.02821 seconds
[httplog] Response:
{"updatedAt":"2018-10-09T17:23:44.652Z","taskID":945887652,"objectID":"articles-25"}

[httplog] Connecting: us-east-api.stream-io-api.com:443
[httplog] Sending: DELETE http://us-east-api.stream-io-api.com:443/api/v1.0/feed/user/10/Reaction:7/?api_key=REDACTED&foreign_id=1
[httplog] Data:
[httplog] Status: 200
[httplog] Benchmark: 0.336152 seconds
[httplog] Response:
{"removed":"Reaction:7","duration":"17.84ms"}
```

If you countn them they are 7, not 16. That's because the calls to Fastly are only executed in production.

#### Resaving articles

[User.resave_articles](https://github.com/thepracticaldev/dev.to/blob/master/app/models/user.rb#L338) refreshes the user's other articles and is called out of process so it's not interesting to us right now. The same happens to the organization if the article is part of one but again, so we don't care.

Let's recap what we know so far. Each article removal triggers a callback that does a lot of things that touch third party services that help this website be as fast as it is and it also updates various counters I didn't really investigate :-D.

### What happens when the article is removed

After the callback has been dealt with and all the various caches are up to date and the reactions are gone from the database, we still need to check what happens to the other associations of the article we're removing. As you recall every article can possibly have comments, reactions (gone by now), buffer updates (not sure what they are) and notifications.

Let's see what happens when we destroy an article to see if we can get other clues. I replaced a long log with my summaries:

```ruby
> art = Article.last # article id 25
> art.destroy!
# its tags are destroyed, this is handled by "acts_as_taggable_on :tags"...
# a bunch of other tag related stuff happens, 17 select calls...
# the aforamentioned HTTP calls for each reaction are here too...
# there's a SQL DELETE for each reaction...
# the user object is updated...
# a couple of other UPDATEs I didn't investigate but which seem really plausible...
# the HTTP calls to remove the article itself from search...
# the article is finally deleted from the db...
# the article count for the user is updated
```

Aside from the fact that in my initial overview I totally forgot about the destruction of the tags (they amount to a `DELETE` and an `UPDATE` each to the database) I would say there's a lot going on when an article is removed.

What happens to the rest of the objects we didn't find in the console?

If you remember from what I said earlier, in Rails relationships everything not marked explicitly as "dependent" survives the destruction of the primary object, so they all are in the DB:

```sql
PracticalDeveloper_development=# select count(*) from comments where commentable_id = 25;
 count
-------
     3
PracticalDeveloper_development=# select count(*) from notifications where notifiable_id = 25;
 count
-------
     2
PracticalDeveloper_development=# select count(*) from buffer_updates where article_id = 25;
 count
-------
     1
```

I think we can be a little bit confident that [the issue that sparked this article](https://github.com/thepracticaldev/dev.to/issues/821) is likely to manifest if such article is really popular before being removed having many reactions, comments and notifications.

### Timeout

Another factor that I mentioned in [a comment to the issue](https://github.com/thepracticaldev/dev.to/issues/821#issuecomment-427307008) is the Heroku's default timeout setting. dev.to IIRC runs on Heroku, which has a [30 seconds timeout](https://devcenter.heroku.com/articles/request-timeout) for HTTP calls once the router has processed them (so it's a timer for your app code). If the app doesn't respond in 30 seconds, it timeouts and sends an error.

dev.to, savvily, cuts this timeout in half using [rack timeout](https://github.com/heroku/rack-timeout#rails-apps) default service timeout which is 15 seconds.

In brief: if after hitting the "remove article" button the server doesn't finish in 15 seconds, a timeout error is raised. Having seen that a popular article can possibly trigger dozens of HTTP calls, you can understand why in some cases the 15 seconds wall can be hit.

## Recap

Let's recap what we learned so far about what happens when an article is removed:

* referential integrity can be a factor if the article has millions of related rows (unlikely in this scenario)

* Rails removing associated objects sequentially is a factor (considering that it also has to load such objects from the DB to the ORM before removing them because it has to if it wants to trigger the various callbacks)

* Inline callbacks and HTTP calls are another factor

* Rails is not smart at all because it could decrease the amount of calls to the DB (for example by buffering the `DELETE` statements for all reactions and using a `IN` clause)

* Rails magic is sometimes annoying 😛

## Possible solutions

This is where I stop for now because I'm not familiar with the code base (well, after this definitely more :D) and because I think it could be an interesting "collective" exercise since it's not a critical bug that needs to be fixed "yesterday".

At first the simplest solution that could pop up in a one's mind is to move everything that happens inline when an article is removed in a out of process call by delegating everything to a job that is going to be picked up by the queue manager. The user just needs the article gone from their view after all. The proper removal can happen with a worker process. Aside from the fact that I'm not sure I considered everything that's going on (I found out about tags by chance as you saw) and all the implications, I think this is just a quick win. It would fix the user's problem by swiping the reported issue under the rug.

Another possible solution is to split the removal in its two main parts: the caches need to be updated or emptied and the rows need to be removed from the DB. The caches can all be destroyed out of process so the user doesn't have to wait for Fastly or Algolia (maybe only Stream.io? I don't know). This requires a bit of refactoring because some of the code I talked about is also used by other parts of the app.

A more complete solution is to go a step further from the second solution and also clean up all the leftovers (comments, notifications and buffer updates) but there might be a reason why they are left there in the first place. All these three entities can be removed in a separate job because two out of three have *before destroy* callbacks which trigger other stuff I haven't looked at.

This should definitely be enough for the user to never encounter again the pesky timeout error. To go an extra mile we could also look into the fact ActiveRecord issues a single `DELETE` for each object it removes from the database but this is definitely too much for now. I would annotate this somewhere and come back to it after the refactoring if needed.

## Conclusions

If you are still with me, thank you. It took me quite a while to write this :-D

I don't have any mighty conclusions. I hope this deep dive in dev.to's source code served at least a purpose. For me it has been a great way to learn a bit more and write about something that non-Rails developers in here might not know but more importantly to help potential contributors.

I'm definitely hoping from some feedback ;-)
