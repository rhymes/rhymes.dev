---
date: 2017-09-22T18:31:58Z
description: Adventures in TrailDB with millions of rows, Python and Go
slug: adventures-in-traildb-with-millions-of-rows-python-and-go
tags: [traildb, python, go]
title: Adventures in TrailDB with millions of rows, Python and Go
---

Storing and querying massive quantities of data is a problem not many projects or companies have to deal with but, at some point, if a product is popular and many users find it useful, it could happen.

You might naturally design your app around a relational database system and use many techniques to scale horizontally or vertical (or both) based on your own requirements and issues.

What do you do with the event data? It might be collected in batches or in real-time but at the end of the day, what do you do with all this information that belongs to a user?

Event data could be data coming from sensors, your own mobile applications, queuing systems, UIs, analytics, access logs and much more.

I would define "event data" as a time ordered series of occurrences that relate to a specific owner.

There are many different places this data might end up, for example:

* a set of tables in a relational database (eg. PostgreSQL or MySQL)
* a streaming data platform (eg. Apache Kafka or Amazon Kinesis)
* a time series database (eg. InfluxDB)

For this article I would like to explore a different tool, that in some specific cases might be the right tool for the job: TrailDB.

## What is TrailDB

I'm going to quote the [source](http://traildb.io/) here:

> TrailDB is a library, implemented in C, which allows you to query series of events at blazing speed.

TrailDB was developed by AdRoll to deal with petabyte-scale quantities of data.

Not everybody has to deal with such scaling challenges but I think TrailDB has a lot of interesting things even for smaller data sets.

## How does TrailDB work

TrailDB has two main modes: construction and querying.

In the construction phase all the event data to be ingested is passed to the library which divides the data internally in a set of trails. Each trail is a series of time ordered events indexed by a unique identifier of your choice.

All this ingested data is processed, ordered and compressed to minimize the occupied space. The result is a read only file ready to be queried.

## How to create a TrailDB

For my experiments I exported a table with more than 139 million events split in two CSV files (don't open them in your favorite editor, not even Sublime :-D).

The first file occupies 29 GB and the second file 30 GB.

TrailDB has bindings for various programming languages: C, D, R, Haskell, Rust, Python and Go.

The language I'm more familiar with among all of those is Python so that's where I started from. Even if TrailDB's own [tutorial](http://traildb.io/docs/tutorial/#part-ii-analyze-a-large-traildb-of-wikipedia-edits) warns against using Python with massive quantities of data.

Let's see how it's done:

```python
COLUMNS = OrderedDict(zip(
    ['YOUR', 'LIST', 'OF', 'COLUMNS', 'IN', 'THE', 'CSV'],
     range(0, NUMBER_OF_COLUMNS)
))

def create_trail_db(input_path, output_path, columns):
    traildb = TrailDBConstructor(output_path, COLUMNS.keys())

    with open(input_path) as input_file:
        reader = csv.reader(input_file, encoding='utf-8', escapechar='\\')

        for line in reader:
            event_uuid = line[COLUMNS['event_uuid']]
            event_time = line[COLUMNS['event_time']]

            # I should probably use a regular expression here but I am lazy
            # and this is just an experiment
            try:
                time = datetime.strptime(event_time, '%Y-%m-%d %H:%M:%S.%f')
            except ValueError:
                time = datetime.strptime(event_time, '%Y-%m-%d %H:%M:%S')

            utf8_encoded_values = [value.encode('utf-8') for value in line]
            traildb.add(event_uuid, time, utf8_encoded_values)

    traildb.finalize()
```

Basically you open a constructor, iterate in your file, pass a uuid and a timestamp to traildb with all your data and then call finalize. Very, very simple. As you noticed I had to use Python 2 because TrailDB doesn't support Python 3.

A couple of notes and statistics:

* the input CSV file is 29 GB on disk
* the output `.tdb` file is 4.4 GB
* on my Macbook Pro with 16 GB RAM and SSD it took 3 hours and 5 minutes to produce
* For those 3 hours I worked on something else using the computer normally

Since I didn't want to wait another 3 hours for the second half of the data set I decided to rewrite the Python script in Go. It was my first attempt at writing Go code beyond the tutorial so it might not be the best implementation but the TrailDB library is quite simple in Go as well:

```go
// I skipped all the error checking for brevity
func create_trail_db(input_path string, output_path string, columns []string) {
    traildb, err := tdb.NewTrailDBConstructor(output_path, columns...)
    input_file, err := os.Open(input_path)
    defer input_file.Close()

    dialect := csv.Dialect{
        Delimiter:   ',',
        Quoting:     csv.NoDoubleQuote,
        DoubleQuote: csv.NoDoubleQuote,
    }
    reader := csv.NewDialectReader(input_file, dialect)
    for {
        record, err := reader.Read()

        event_uuid := record[indexOf("event_uuid", columns)]
        event_time := record[indexOf("event_time", columns)]

        timestamp, err := strptime.Parse(event_time, "%Y-%m-%d %H:%M:%S.%f")
        if err != nil {
            timestamp, _ = strptime.Parse(event_time, "%Y-%m-%d %H:%M:%S")
        }

        traildb.Add(event_uuid, timestamp.Unix(), record)
    }

    traildb.Finalize()
    traildb.Close()
}
```

It took 1 hour and 30 minutes to parse the second file, which contains 493 thousand more lines than the previous file parsed by Python.

A few notes on the whole creation process:

* the compression works great, 8.8 GB total from 59 GB of raw source material
* Go took half the time to do more stuff
* I'm quite sure that a lot of time the time is spent in parsing the timestamps from the lines in the CSV so it might be faster with timestamp already in seconds

## How to query a TrailDB

So now we have two files, let say `a.tdb` and `b.tdb` each occupying roughly 4.4 GB sitting there in a folder ready to be analyzed. How do we do that?

Turns out there are many ways, from the "please do not look at this dumb code" way to those that can scale in a divide et conquer architecture.

### Query conditions

If we want to query something for our adventures we need to decide what to look for. The condition for this experiment, in SQL, will be the following:

```sql
SELECT *
FROM ab_tests
WHERE ab_test_id = '1234'
AND action_type IN ('clicked_button_red', 'clicked_button_green')
```

It could be anything else, this is just a pseudo example.

### Setting a dumb reference point

Since I needed an unrealistic reference point just to be able to say "wow" when actually using TrailDB I decided to write a dumb script in Python and Go to iterate over all the tens of millions of lines in the file and detect the results manually. See for yourself:

```python
tdb = TrailDB(tdb_filepath)

...

def action_data(tdb, action_types, action_types):
    for uuid, trail in tdb.trails():
        for event in trail:
            if event.ab_test_id in ab_test_ids and event.action_type in action_types:
                yield event

count = 0
for event in action_data(tdb, ab_test_ids, action_types):
    print event
    count += 1
```

```go
db, err := tdb.Open(tdb_filepath)

func action_data(db *tdb.TrailDB, ab_test_ids map[string]bool, action_types map[string]bool) int {
    trail, err := tdb.NewCursor(db)

    count := 0
    for i := uint64(0); i < db.NumTrails; i++ {
        err := tdb.GetTrail(trail, i)

        for {
            evt := trail.NextEvent()
            evtMap := evt.ToMap()
            if (ab_test_ids[evtMap["ab_test_id"]]) && (action_types[evtMap["action_type"]]) {
                evt.Print()
                count += 1
            }
        }
    }

    return count
}
```

Here are the timings:

```bash

$ time python query_db_naive.py a.db
4105.14s user 49.11s system 93% cpu 1:14:19.35 total

$ time go run query_db_naive.go a.db
538.53s user 8.66s system 100% cpu 9:05.35 total

```

Python took 1 hour and 14 minutes and Go took 9 minutes and 5 seconds. They both found the same 216 events I was looking for.

I skipped Python for the second file because I didn't want to die waiting. Go took less than 12 minutes to find the 220 events in the second file (which I remind you is bigger than the first).

### Querying with TrailDB filter API

TrailDB allows the developer to create [filters](http://traildb.io/docs/technical_overview/#return-a-subset-of-events-with-event-filters) for the queries.

You can use them, for example, to quickly extract rows matching a set of conditions in a separate TrailDB file or to just, you know, find stuff and do something with it before the end of time like in the examples above.

I rewrote the two scripts using filters:

```python

query = [
    [('ab_test_id', value) for value in ab_test_ids],
    [('action_type', value) for value in action_types]
]
count = 0
for uuid, trail in tdb.trails(event_filter=query):
    for event in trail:
        print event
        count += 1

```

`tdb.trails()` accepts a Python list of filters and only returns matching rows. Each filter is a list, all the lists in the query are in `AND` with each other and each item in a single list is in `OR` with the other items.

Let's see the same thing in Go:

```go

query := [][]tdb.FilterTerm{
  {
    tdb.FilterTerm{Field: "ab_test_id", Value: "2767"},
  },
  {
    tdb.FilterTerm{Field: "action_type", Value: "clicked_button_red"},
    tdb.FilterTerm{Field: "action_type", Value: "clicked_button_green"},
  },
}
filter := db.NewEventFilter(query)
db.SetFilter(filter)

```

Here are the results for the first file:

```bash

$ time python query_db_filter.py a.tdb
14.36s user 0.63s system 97% cpu 15.362 total

$ time go run query_db_filter.go a.tdb
5.75s user 0.53s system 97% cpu 6.459 total

# precompiled go binary
$ time ./query_db_filter a.tdb
5.42s user 0.39s system 97% cpu 5.945 total

```

And the results for the second file:

```bash

$ time python query_db_filter.py b.tdb
14.13s user 0.61s system 96% cpu 15.257 total

$ time go run query_db_filter.go b.tdb
5.82s user 0.79s system 92% cpu 7.194 total

# precompiled go binary
$ time ./query_db_filter b.tdb
5.60s user 0.43s system 97% cpu 6.192 total

```

We already know that our baseline was non-sensical but we can still draw a few conclusions:

* Go's example is 2, 2.6 times faster than Python's
* TrailDB filters are really fast, though creating complex conditions might require a bit of preparation
* Things might be even faster splitting the trails, looking for the items in parallel and then joining the results. Like in a "map reduce" algorithm.

### Querying with TrailDB command line tool

TrailDB ships with a command line tool, written in C, that you can use to create databases, to filter, to create indexes, merge and more.

So naturally I wanted to see how fast it was with querying:

```bash

$ time tdb dump --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i a.tdb
6.47s user 0.45s system 96% cpu 7.176 total

$ time tdb dump --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i b.tdb
5.66s user 0.46s system 96% cpu 6.359 total

```

The speed is definitely on par with our Go reference implementation.

### Querying with TrailDB command line tool and a prepared index

The command line tool has a neat feature that allows to pre-build an index matching our filters. The index is saved on disk beside the traildb file.

First we create the index:

```bash

$ time tdb index --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i a.tdb
Index created successfully at a.tdb.index in 286 seconds.
346.05s user 12.63s system 125% cpu 4:45.99 total

$ du a.tdb.index
645M  a.tdb.index

```

Then we run the same query in the previous paragraph again:

```bash

$ time tdb dump --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i a.tdb
0.06s user 0.01s system 39% cpu 0.185 total

```

As you can see it's quite faster. We went from 6.47s to 0.06s.

There's a catch though: I couldn't find a way to use the index from the programming languages. It can only be used by the command line tool which is not ideal.

## How to merge multiple TrailDBs

We now know how to create a traildb, how to extract data from it but we still don't know how to take two traildb files and merge them into one.

I created another pair of scripts to merge:

```python

output_tdb = TrailDBConstructor(output_path, columns)

for tdb_filepath in tdb_filepaths:
    tdb = TrailDB(tdb_filepath)
    output_tdb.append(tdb)

```

```go

output_tdb, err := tdb.NewTrailDBConstructor(output_path, columns...)

for i := 0; i < len(tdb_filepaths); i++ {
  tdb_filepath := tdb_filepaths[i]

  db, err := tdb.Open(tdb_filepath)

  err = output_tdb.Append(db)

  db.Close()
}

output_tdb.Finalize()
output_tdb.Close()

```

Then I ran them:

```bash

$ time python merge_dbs.py final.tdb a.tdb b.tdb
1044.97s user 1260.73s system 27% cpu 2:22:08.29 total

$ time go run merge_dbs.go final.tdb a.tdb b.tdb
960.93s user 1149.51s system 22% cpu 2:33:54.73 total

```

Let's check the events are all there:

```python

>>> from traildb import TrailDB
>>> tdb = TrailDB('final.tdb')
>>> tdb.num_events
139017085L

```


A note: Go might have been 11 minutes slower than Python due to the fact I was uploading gigabytes on a S3 bucket in the meantime and also Time Machine's backup started... These tests are definitely not scientific :-D

Merge is a slow operation, I supposed the library has to decompress the data for each TrailDB and recompress it in the final one.

The operation was very intensive on my laptop with 16 GB of RAM. The process was swapping like crazy but again, I did not run these scripts on a dedicated machine.

Merge might be worth it only to merge small files.

## Querying 139 million events

Now that we've created the "final" file, with 139 million events, I was curious to see how fast Python and Go were with it:

```sh

$ time python query_db_filter.py final.tdb
29.56s user 2.65s system 80% cpu 40.223 total

$ time go run query_db_filter.go final.tdb
11.63s user 1.02s system 95% cpu 13.303 total

```

## Bonus content: how to query TrailDB files on Amazon S3

TrailDB has an [experimental feature](http://tech.adroll.com/blog/data/2016/11/29/traildb-mmap-s3.html), in a separate version, that can use Linux [userfaultfd()](https://lwn.net/Articles/615086/) syscall to take advantage of page faults to fetch blocks of data from the network (the remote S3 file), map the blocks in the local memory and cache them on disk.

It offers a server process which translates page faults into network calls to fetch parts of the file on S3. I didn't know this could be done and my jaw fell down when I read the article.

How cool is that? I had to find out if it worked (and now you know why I was uploading stuff to S3 while conducting the previous experiments).

I setup an EC2 machine (t1.micro + 8GB SSD gp2 volume), installed traildb on it and started playing.

My configuration for the experiment was:

* 16MB of block size (the amount of data from the file the process fetches on the network)
* 1GB of max occupied space on disk (max size of the local cache)

```bash

time tdb dump --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i s3://something/a.tdb
real    2m27.941s
user    0m6.348s
sys     0m3.400s

```

For obvious reasons is slower than the local version but see what happens when you have some locally cached data:

```bash

time tdb dump --filter='ab_test_id=2767 & action_type=clicked_button_red action_type=clicked_button_green' -i s3://something/a.tdb
real    0m52.742s
user    0m6.496s
sys     0m3.680s

```

Not bad eh?

The reason why this feature is useful is that in same cases we might have TrailDB files bigger than the disk storage so we need a way to query data without having the files locally available.

## Bonus content: query TrailDB with reel, an experimental language

TrailDB offers a multithreaded tool, reel, which can be used to compute metrics over a series of events, for example bounce rate or funnel analysis.

It operates on TrailDB files without any modifications to them. It's just another way to extract information.

A reel query looks like this:

```text

var Events uint

if $ab_test_id $ab_test_id='2767':
   if $action_type $action_type='clicked_button_red' or if $action_type $action_type='clicked_button_green':
      inc Events 1

```

This is the result with 2 and 4 threads:

```bash

$ time ./reel query.rl -P -T 2 a.tdb
[thread 0] 0% trails evaluated
[thread 0] 44% trails evaluated
[thread 0] 88% trails evaluated
[thread 0] 100% trails evaluated
Events
216

7.39s user 0.42s system 178% cpu 4.371 total

```

```bash

$ time ./reel query.rl -P -T 4 a.tdb
[thread 0] 0% trails evaluated
[thread 0] 44% trails evaluated
[thread 0] 88% trails evaluated
[thread 0] 100% trails evaluated
Events
216

9.98s user 0.54s system 295% cpu 3.560 total

```

So, since it's more or less as fast as our Go and Python scripts, why bother learning another tool? Because reel can be used to handle [time passing between different events](https://github.com/traildb/reel#handling-time), [it has control flow](https://github.com/traildb/reel#control-flow) and [it can group results](https://github.com/traildb/reel#grouping-by-splitting-contexts).

There is another non-experimental tool, [trck](https://github.com/traildb/trck), which is a full fledge query engine with a state machine but I couldn't make it work on OSX so I'll conveniently leave the test as an excercise to the reader ;-)

## Considerations and conclusions

TrailDB is really fast if used properly and I value the finalized files to be read-only as a plus. It requires a bit of work to be part of a company data workflow but I think it's a tool worth exploring and it can make the difference in containing costs with the analyis of massive quantitities of data which all companies are starting to have because of "big data" and the fact that basically nobody deletes anything anymore.

I would definitely recommend using Go over Python to operate with TrailDB.

As I said at the beginning TrailDB was created by AdRoll which uses it to process petabyte-scale quantities of data. I think it's a tool worth knowing (or at least knowing it's out there) though as for the present moment I find it a bit unpolished. Also the community seem pretty small and if I'm not mistaken the open source project is maintained by the developers at AdRoll which might make the project be driven by their company's business requirements and schedule (the latest release is 0.6 and it was published in May 2017).

Anyway, if you're interested in knowing more, here are a couple of links:

* [Announcing TrailDB](http://tech.adroll.com/blog/data/2016/05/24/traildb-open-sourced.html)
* [Introduction to TrailDB](http://slides.com/villetuulos/intro-to-traildb#/)
