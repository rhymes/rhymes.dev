Hi, I'm rhymes.

I am an experienced programmer, my pronouns are he/him.

Most recently I worked at [Forem](https://www.forem.com/) from May 2019 until October 2021, as Senior and then Principal Software Engineer. I was working as an opensource maintainer and contributing to the entire stack:

- **database**: query plan optimization, schema design and evolution and more. I have extensive experience with PostgreSQL and I'm good at knowing when PostgreSQL is enough, when it's the best choice and when it's not.

- **caching**: edge, server and HTTP caching. Caching is hard but avoiding caching is usually more expensive than having to deal with stale reads. As with everything, it depends, sometimes recomputing values is faster than the roundtrip to your Redis server.

- **performance**: I truly believe that performance is a feature which has spawned my interest in optimizing at all layers. I'm good at finding bottlenecks in SQL queries, profiling, correlating data from monitoring and observability tools, [exploring concurrent solutions](https://github.com/forem/forem/issues/10996). I also love debugging.

- **search engine**: at Forem the company switched from Algolia to Elasticsearch to PostgreSQL full text because we figured out that having a separate search server was overkill. I was part of the team in charge of moving the app off Elasticsearch to FTS, wrote enough code to be able to use both and then started chipping away at ES with wrappers, triggers and all that. [Some of that work is here](https://github.com/forem/forem/pulls?q=is%3Apr+author%3Arhymes+is%3Aclosed+%22Search+2%22+).

- **API**: I spent time improving Forem's RESTish API (at the time the API was mostly at [Level 2 of the REST maturity model](https://www.martinfowler.com/articles/richardsonMaturityModel.html#level2)), fixing [caching issues for example](https://github.com/forem/forem/pull/4744), adding [its Open API 3 specification](https://github.com/forem/forem/pulls?q=is%3Apr+author%3Arhymes+is%3Aclosed++openapi+3), improving [its impact on the DB](https://github.com/forem/forem/pull/5805), securing parts of it with OAuth and more. I'm interesting in API design, I wrote a GraphQL API in Go in the past and I can talk about the differences of approaches and how I think REST APIs still make sense in many cases.

- **frontend**: I'm not an expert at frontend development, especially now that the complexity increased quite a bit. I care a lot about accessibility and usability. I think many frontend teams start with single page applications to insulate themselves from backend teams, which doesn't necessarily translates to a better user experience. I like JavaScript and [I wished we used less of it overall](https://infrequently.org/2021/03/the-performance-inequality-gap/). That said, I'm naturally interested in hybrid solutions composed of server rendered pages augmented by the ideas behind htmx, StimulusReflex, Phoenix LiveView, Hotwire and others. At Forem I learned Preact, Stimulus, CSS grid and flexbox and improved my a11y skills. I also used to maintain a full Vue SPA before that.

Other things I have experience at: understanding how a planned feature can impact subsystems and teams, mentoring and learning from people at all skill levels, evaluating basic security implications in software design, evaluating the relation between business requirements and engineering requirements.

Most of these things I have not learned in isolation but because of others: past colleagues, technical writers, opensource maintainers and contributors, even people outside of the tech industry. I'm not a 10x developer, I just like good software that works and responds quickly to its users.

Although it's not at all the best of metrics you can see [some of those contributions I made at Forem here](https://github.com/forem/forem/pulls?q=is%3Apr+author%3Arhymes) but that won't tell you anything of the wonderful colleagues I had there and how much I learned from them.

Before Forem I wrote servers, web apps and tools for more than a decade in Python, Ruby and JavaScript. I "secretly" think functional programming will save us all in the end but have settled to incorporating learnings from those languages in more general purpose languages. Rust's borrow checker is a really good idea for many of the problems that programming languages have with shared data.

I value transparency, privacy, [boring technologies](https://mcfunley.com/choose-boring-technology) and I usually [rant on Twitter](https://twitter.com/rhymes_) about those things, performance, unnecessary complexity in software and data collection.
