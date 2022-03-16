---
date: 2020-05-28T12:15:24Z
description: How to build unique indexes in PostgreSQL on large text
slug: how-to-build-unique-indexes-in-postgresql-on-large-text
tags: [postgresql, rails, database]
title: How to build unique indexes in PostgreSQL on large text
---

As I believe a relational database schema should be as independent as possible from the apps using it, [I've been trying to strengthen the DEV's database a bit lately](https://github.com/thepracticaldev/dev.to/pulls?q=is%3Apr+author%3Arhymes+%22unique+indexes%22) (there are exceptions to this rule but they are not for this post).

One way to do that is to make sure that Rails model statements like this:

```ruby
validates username, uniqueness: true
```

correspond to actual [unique indexes](https://www.postgresql.org/docs/11/indexes-unique.html) in PostgreSQL.

Two reasons for that:

- let the DBMS do its job, it was built to check constraints
- data can "get in" from all sort of ways (throwaway SQL scripts for example)

Even if today your database is used only by a single app, you might have more than one in the future and adding indexes on existing tables or having to clean duplicate rows in large tables is always a bit of a pain (because of locking, I might write another article about that..).

### What happened then?

It seems straigtforward, right? List the column(s) you need the index for, write a Rails migration for them, run the migration, forget about it.

That's where a random test literally saved me from an oversight.

We have a test in our codebase that imports 20+ items from a RSS feed, transforms them into articles and inserts them in the DB, then checks the count to make sure it matches.

They are all different articles, but the database is going to check they are unique anyway (for obvious reasons).

The counts weren't matching and after some very serious debugging magic (aka setting a breakpoint and printing stuff) I came across this:

```ruby
[1] pry(#<RssReader>)> p e
#<ActiveRecord::StatementInvalid: PG::ProgramLimitExceeded: ERROR:  index row size 7280 exceeds btree version 4 maximum 2704 for index "index_articles_on_body_markdown_and_user_id_and_title"
DETAIL:  Index row references tuple (8,1) in relation "articles".
HINT:  Values larger than 1/3 of a buffer page cannot be indexed.
Consider a function index of an MD5 hash of the value, or use full text indexing.
: INSERT INTO "articles" ("body_markdown", "boost_states", "cached_tag_list", "cached_user", "cached_user_name", "cached_user_username", "created_at", "description", "feed_source_url", "password", "path", "processed_html", "published_from_feed", "reading_time", "slug", "title", "updated_at"
```

Wait, what!?

After a bit of digging I realized my oversight: if the text to be indexed is too large and doesn't fit PostgreSQL buffer page, indexing is not going to work.

*PostgreSQL buffer page size can be enlarged but that's beside the point and also not a great idea.*

### So, what's the solution?

The solution is to create a hash of the column and index that instead of the column itself.

There are many ways to go about this but this is what I chose for our particular situation:

```sql
CREATE UNIQUE INDEX CONCURRENTLY "index_articles_on_digest_body_markdown_and_user_id_and_title"
ON "articles"
USING btree (digest("body_markdown", 'sha512'::text), "user_id", "title");
```

Let's break it down:

- `CREATE UNIQUE INDEX` is self explanatory: creates an index on a column, making sure you can't insert the same value twice
- `CONCURRENTLY` is a huge change in PostgreSQL land. In short: it adds the index asynchronously in the background. Basically it doesn't block operations on the table while the index is being built.
- `btree` is the [standard default index for PostgreSQL](https://www.postgresql.org/docs/11/indexes-types.html)
- `digest("body_markdown", 'sha512'::text)` is where the magic happens: we tell PostgreSQL to build a SHA512 hash (go away MD5 😅) and use that for comparison of the index
- `"user_id", "title"` are there because this is not an index on a single column, but a multi column index

This is what happens when you try to add the value twice in the database:

```shell
$ pgcli PracticalDeveloper_development
PracticalDeveloper_development> insert into articles (body_markdown, user_id, title, created_at, updated_at) select body_markdown, user_id, title, now(), now() from articles order by random() limit 1;
duplicate key value violates unique constraint "index_articles_on_digest_body_markdown_and_user_id_and_title"
DETAIL:  Key (digest(body_markdown, 'sha512'::text), user_id, title)=(\x1f40fc92da241694750979ee6cf582f2d5d7d28e18335de05abc54d0560e0f5302860c652bf08d560252aa5e74210546f369fbbbce8c12cfc7957b2652fe9a75, 10,  The Curious Incident of the Dog in the Night-Time Voluptas quia) already exists.
```

*Bonus tip for [pgcli](https://www.pgcli.com/) which I use instead of the regular psql*.

The result of this investigation is [this PR](https://github.com/forem/forem/pull/8072).

