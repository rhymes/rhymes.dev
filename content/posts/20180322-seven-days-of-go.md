---
date: 2018-03-22T01:57:46Z
description: Developing an API server in Go
slug: seven-days-of-go
tags: [go, webdev]
title: Seven days of Go
---

The following is a brain dump of everything I've learned so far using Go, writing the mvp of an app, in 7 days.

My only previous experience with Go was "copying and pasting" with what become part of [this article]({{< ref "20170922-adventures-in-traildb-with-millions-of-rows-python-and-go" >}}) last year.

## What and why

I've been asked by a client to write an API server. The deadline for the MVP was "yesterday" so I decided, instead of comfortably using Python (and quite frankly taking a little bit less of time) to write it in Go in 7 days.

I know, it sounds ridiculous, but I had (vague) requirements like:

* low response time and low latency
* potentially used by millions of devices (their main mobile app has 10+ million installations)
* has to be exposed on the web and internally as a data source

So my first thought was: microservices, random buzzword, containers, graphql, orchestration, another random buzzword and so on.

The second thought was: breathe.

Disclaimer: I'm in R&D so not everything I write becomes a production application.

Also, do not try this at home :P

## First step: hello world

The first thing I had to figure out was how. So I've read a bunch of tutorials and guides and then started from the simplest of web apps:

```go
package main

import (
    "fmt"
    "log"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello, world!")
}

func main() {
    http.HandleFunc("/", handler)
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

This is all standard library and [it's production ready](https://blog.cloudflare.com/exposing-go-on-the-internet/).

## Second step: the data

I listed all I needed and sketched with the input of the company's PM the data entities and the endpoints, the data flow and so on.

I knew I could safely model everything with a "classic" relational database and so I did. The README on Github lists the following two requirements for now:

* PostgreSQL 10
* Go 1.10

though I'm sure it can work with PostgreSQL 9.6 and since I know little about Go, probably with earlier versions of that too.

I also wanted to keep dependencies at a minimum (more on this later).

I actually wrote the SQL for the entities by hand. It took me a couple of tries because I always, always, forget something in the `CREATE TABLE` statements (remember kids to put `NOT NULL` in your foreign keys or else die a slow death). I also spent 10 minutes googling for the best SQL extension for Visual Studio Code, which I didn't find. They all suck.

The data model is pretty simple though. Three entities: A, B and C. C belongs to B and A. B belongs to A. A is the know it all.

Anyway I have been too spoiled by data mappers like SQLAlchemy or ORMs like ActiveRecord to generate the initial schema. Man, typing SQL without code completion is retro.

I actually tried to use [gorm](http://gorm.io/) which, as the name says, it's a Go ORM, in the beginning but I abandoned on day 2. I didn't feel confident with it, the auto migrate functionality scared me (auto migrations during the start of the app!?!?!) and I had some issues (later on I also found out it has performance problems but I didn't know yet).

This is the actual commit message from git log:

```text
0cb0ff3 [6 days ago] (rhymes) Bye gorm
```

I ended up using [go-pg](https://github.com/go-pg/pg) which is an ORM (ahem) but also a PostgreSQL client.

## Braindump

What follows is a glimpse in the journey I had these seven days and the partial insanity of my decision (I won't quote Robert Frost's The Road Not Taken, I promise) and of some aspects of Go I liked or liked less.

* Go might not the best name for Google searches. Sometimes you type "go something" and then you have to retype "golang something" because the results make no sense. Funny because Google invented Go. It also reminds me of Goo Goo Dolls, not my favorite band ever.

* HTTP support is amazing. The standard library supports well HTTP 1.1 and 2 (even [server push!!](https://golang.org/pkg/net/http/#Pusher)), SSL/TLS, request parsing, headers and more. Python's `http.server` is just a toy but the Go team implemented a production ready HTTP server in the standard library. I'm not surprised since Go is behind some web server's Google exposed to the public, like [dl.google.com](https://news.ycombinator.com/item?id=4701454) which was ported from C++ six years ago. It uses goroutines (think of them like concurrent routines mapped on system threads) to serve traffic.

* The packaging system needs to get better. Packaging systems are also for humans, not just for the machines. I hate vendoring dependencies in the git repository so I chose [dep](https://github.com/golang/dep) which is another easy name to Google for, also "dep" is not the same tool as "godep". I'm starting to think they are trolling the newcomers. Uninstalling global dependencies it's also impossible. They actually tell you to manually find the files in the `GOPATH` and delete them. Are you kidding me? Is this the 90s?

* Don't fight it. Repeat with me: don't fight Go. My first instinct was to program Go like I would Python but that's a bad idea. That's a bad idea in most languages any how so don't do it.

* When you stop figthing Go you realize the core is pretty simple to learn. I went through [Go by example](https://gobyexample.com/) and my head didn't explode.

* Type safety is pain if you're used to high level dynamic languages where variables are just labels for pieces of memory. The first two days it was all typing errors and crashes. They can be brutal, but don't fight them.

* Type safety is awesome. Go's Visual Studio Code extension is magic. It tells me which type this variable contains or that method returns, I can also click and read the implementation of the method (it works for any library you imported and for the standard library). I learned quite a bit this way.

* Error handling is weird. If you look at any standard Go code you will see this pattern A LOT:

  ```go
  if err != nil {
    // do something with the error
  }
  ```

  The thing is that numerous methods return a value and a an error so you end up having to handle errors every other line. I do have methods like:

  ```go
  this, err := Service.LoadThisFromTheDB(id)
  if err != nil {
    // send HTTP error code to the client
  }

  that, err := Service.LoadThatFromTheDB(id)
  if err != nil {
    // send HTTP error code to the client
  }

  // do something with this and that
  ```

  It can really become weird at some point.

* Error handling is awesome. Forget I just said it's weird (and it is) but the more you program, the more you understand why they chose to avoid exceptions. Exceptions, in Ruby for example, are very costly and they can also be used as a control flow mechanism. Go decided that the best place to handle an error is right there when you get it. Obviously if you start encapsulating functionality in functions you can also return the error to the caller so they can still be a contro flow mechanism...

* There's no builtin way to generate cryptographically secure strings (API tokens in my case). I had to [copy and paste that from the Internet](http://blog.questionable.services/article/generating-secure-random-numbers-crypto-rand/). As you see it's only a few lines of code but I find it odd, especially because they have all the ingredients in the library. To be honest Python got its [secrets](https://docs.python.org/3/library/secrets.html) module pretty recently.

* [Structs](https://gobyexample.com/structs), [methods](https://gobyexample.com/methods) and [interfaces](https://gobyexample.com/interfaces) are awesome. Structs are where you model your data, models are where you attach behaviour to such data but interfaces are where the magic of OOP happens. Python and Ruby have duck typing (they "send" a method to the receiver hoping it responds), Go has interfaces that let it check if a receiver implements this or that method. Or something like that, I didn't have time to go into depth.

* Structs are really awesome. I have data like:

  ```go
  type Model struct {
    ID        uint64    `sql:"-,notnull" json:"-"`
    CreatedAt time.Time `sql:"-,notnull" json:"createdAt"`
    UpdatedAt time.Time `sql:"-,notnull" json:"updatedAt"`
  }
  ```

  This means: ID is an integer, with a non null column in the database which should be ignored by the JSON serialiser (because we never return DB numeric primary keys to an API client, right?). It also says that `CreatedAt` and `UpdatedAt` and timestamps with their own serialisation name.

  The reason why they are capitalized is that in Go names starting with a capital letter are public, names with a lowercase letter are private. Simple as that.

  So what do I do with this "base" Model struct? I embed it in the actual model struct:

  ```go
  type A struct {
    Model // hello, I'm embedding myself into A

    Name string `sql:",notnull" json:"name"`
  }
  ```

  There's a lot to unpack here: I'm not sure how but magically you will find `ID`, `CreatedAt` and `UpdatedAt` in your model struct plus the rest of the fields specific to that model/table, in this case `Name`.

* Structuring a project is neither hard nor easy. I'm 100% sure it has everything to do with my lack of knowledge but my code base right now it's a bit of a jigsaw puzzle.

* Writing tests is neither hard nor easy. The tests itself are okay. Go comes equipped with its own testing package but I haven't figured out fixtures for functional tests yet. The great thing though is that with Visual Studio Code you can just tell it to generate a test for the file you're writing and thanks to the type system the unit test is like 90% ready. Just need to fill in which inputs and outputs. A-mazing!

* Logging is bonkers. It honestly is. The standard library does not support levels. The third party ecosystem around logging reminds me of the NPM repository on a good day. This is a screenshot from [awesome-go#logging](https://github.com/avelino/awesome-go#logging):

![golang likes logging](https://thepracticaldev.s3.amazonaws.com/i/ogkyrq8jp615lqr095ej.png)

  See? Are you kidding me? I also ended up with none of them. I'm using [go-kit's log](https://github.com/go-kit/kit/tree/master/log), only the log module which, because Go is awesome and weird, you can just import without importing the rest of the package. Magic.

* Schema migration is pretty easy but it can bite you in the butt. I started with [goose](https://github.com/pressly/goose) which was working but I had to switch to [migrate](https://github.com/mattes/migrate) (what is it with developers and naming projects?!) because Heroku doesn't support anything other than migrate in a specific version in its Go buildpack.

* Querying from the DB with go-pg is also pretty easy (if you read the wiki instead of the autogenerated doc like I did...):

  ```go
  func (s *AService) LoadA(name string) (*A, error) {
    var a A
    err := s.DB.Model(&a).
      Column("*").
      Where("name = ?", name).
      Select()
    if err != nil {
      return nil, err
    }
    return &a, nil
  }
  ```

  Here we tell the DB that the model is our `A` struct up there, that we want all the columns, which criteria to use in filtering and to issue the `SELECT`.
  The weird signature `func (s *AService) LoadA(name string) (*A, error)` means "this is a method of `AService` called `LoadA` which takes a string and returns a pointer to `A` and and error. Yes, it's a mouthful, but you get used to it quickly.

* Inserting data is even easier:

  ```go
  func (s *AService) CreateA(a *A) error {
    _, err := s.DB.Model(a).Returning("*").Insert()
    return err
  }
  ```

  If you love PostgreSQL like I do you'll love go-pg but please, start from the wiki, save yourself some time :D

* I obviously had to replicate the logging experiment I did with [Flask]({{< ref "20180316-logging-flask-requests-with-colors-and-structure" >}}) and [Rails]({{< ref "20180316-logging-rails-requests-with-structure-and-colors" >}}):

  ```go
  start := time.Now()

  // ...some other go code...

  // serve the request
  handler.ServeHTTP(lrw, r)

  // extract entries
  method := r.Method
  path := r.URL.Path
  proto := r.Proto
  status := lrw.statusCode
  duration := time.Since(start)
  host := r.Host
  ip := r.RemoteAddr
  if remoteIP := r.Header.Get("x-forwarded-for"); len(remoteIP) > 0 {
    ip = remoteIP
  }
  params := r.URL.Query()

  logger.Info(
    "method", method,
    "path", path,
    "proto", proto,
    "status", strconv.Itoa(status),
    "duration", duration.String(),
    "host", host,
    "ip", ip,
    "params", params.Encode(),
  )
  ```

  The colours are set by go-kit/log colouring module by level.

* Go fmt. It's like prettier for JavaScript, but better because there are no options and all the code you see around is written the same way. Huge time saver.

* Go and PostgreSQL are pretty fast. I had even seen responses taking **microseconds**!!. Locally though, due to the obvious round trip latency network requests are slower. But hold your horses! We're talking about a few milliseconds.

This is a response time for a SQL Select (with pre warmed cache), plus JSON serialization on localhost:

```text
sql="SELECT EXISTS(SELECT 1 FROM as WHERE api_key = 'super secret') FROM \"as\" AS \"a\"" duration=701.774µs
sql="SELECT * FROM \"as\" AS \"as\" WHERE (api_key = 'super secret')" duration=843.299µs
method=GET path=/api/v1/a proto=HTTP/1.1 status=200 duration=1.7544ms host=localhost:8080 ip=[::1]:54198 params=
```

This is the same server replying with 401 Unauthorized if I use the wrong api key:

```text
method=GET path=/api/v1/a proto=HTTP/1.1 status=401 duration=591.115µs host=localhost:8080 ip=[::1]:54198 params=
```

Not bad eh?

* Go is pretty slick. Everything you write gets packaged in a single binary, like the in the *olden days* and that's it. This is how much it takes to build this app:

  ```bash
  ➜ git:(development) ✗ time go build
  go build  0.31s user 0.30s system 138% cpu 0.441 total
  ```

  This is what you write in the Heroku's `Procfile`:

  ```text
  web: name-of-your-app's-binary
  ```

  That's really it. It has an impact on your development feedback cycle. "It's compiling" is not an excuse with Go :-D


* Makefiles are making a comeback. Since the tooling in Go is not "top spot" in some areas and because Go sometimes makes you feel like you're back in the 90s, sooner or later, you'll end up with a Makefile. I _definitely_ had to Google how to build one. Now my Makefile builds, installs, starts, cleans, lints and tests (with coverage). Basically I had to rebuild a Bimby robot using bronze age tools.

* Go is modest in its RAM usage. The app is using 17 mega bytes on a $7 Heroku dyno. I did a few unscientific load tests today on read and write endpoints and the memory usage skyrocketed to... 18 mega bytes with peaks of 20. I should look into containers and put more than one app in a single dyno :-D

* A lot of Go devs say "stay away from frameworks" (HTTP frameworks). So I did and I'm not missing any. I'm sure I would have a different opinion if I were writing a web app instead of an API but there's no way I'm writing a "frontend" web app in Go. No way. My dependencies are godotenv to load .env files, gorilla mux for the routing, go-pg for PostgreSQL, go-kit/log for logging, govalidator to validate JSON requests, NewRelic's and Sentry's Go agents.

## Conclusions

My current experience in Go is "copying and pasting" and "stackoverflow programming" and "WTF" and "wow" and "OMG this thing is amazing" and "I can't believe the packaging system sucks" so I'm sure I'm going to change opinion about a lot of things in the future.

The joy ride ends here, if you are still reading.

The app is not finished (spaghetti code and low test coverage are definitely in) but the MVP is.

I don't really have conclusions but I'm going to leave you with a few resources:

* [Go by Example](https://gobyexample.com/): where it all started
* [How I Built an API with Mux, Go, PostgreSQL, and GORM](https://dev.to/aspittel/how-i-built-an-api-with-mux-go-postgresql-and-gorm-5ah8): many thanks to [Ali Spittel](https://dev.to/aspittel), her article helped a lot! Sorry if I ditched GORM :D!
* [Ten Reasons Why I Don't Like Golang](https://www.teamten.com/lawrence/writings/why-i-dont-like-go.html): always useful to read opinions from those who didn't drink the kool aid
* [Why Timehop Chose Go to Replace Our Rails App](https://medium.com/timehop/why-timehop-chose-go-to-replace-our-rails-app-2855ea1912d): pros are deployment, toolchain (what?!), standard library (definitely yes); cons is the dependency management system (and this article is from 2015!!)
* [Testing in Go](https://blog.alexellis.io/golang-writing-unit-tests/)
* [Standard package layout](https://medium.com/@benbjohnson/standard-package-layout-7cdbc8391fc1): it helps, seriously!
