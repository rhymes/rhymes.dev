---
date: 2018-04-05T17:13:58Z
description: Server to server communication using GraphQL between Go and Python
slug: server-to-server-communication-using-graphql
tags: [python, go, graphql]
title: Server to server communication using GraphQL
---

The development of the [Go API server]({{< ref "20180322-seven-days-of-go" >}}) I was "documenting" a couple of weeks ago has gone forward.

Since then I added tests (mostly functional), refactored some parts and learnt a bit more about Go.

The API server is the owner of its own database. Now, for the same app, we're building a frontend web app which for some features needs to talk to the API server and exchange data.

The API server currently exposes a REST API for mobile clients.

My first thought was to add a few endpoints to that API but I instantly rejected the idea because I definitely do not want the mobile clients to be able to access those endpoints by accident ;-).

My second idea was to create a separate REST API, on the same server, and secure it in a different way. Basically separate the endpoints for the mobile clients from the ones used by this web app and call them through a different authentication mechanism and call it a day.

The web app is very much in the conception and design phase and we're not sure how the final app will be entirely so we can't be sure how much of the Go API domain the web app will be needing or using.

I chose to use GraphQL which frees me, more or less, of the burden of designing another API at all. It also gives free introspection which is perfect at this stage.

## Go GraphQL server

The first step was to setup a GraphQL server in Go. After a little research I decided to use [gqlgen](https://github.com/vektah/gqlgen). gqlgen generates (!!) a GraphQL server given the types definitions and the schema.

A schema example:

```graphql
type Query {
    todos: [Todo!]!
    todo(todoID: ID!): Todo
}

type Mutation {
    createTodo(todo: TodoInput!): Todo
}

type Todo {
    todoID: ID!
    title: String!
    text: String!
}

input TodoInput {
    title: String!
    text: String!
}
```

Here, following the standard [graphql schema](https://graphql.org/learn/schema/) we're defining two types of queries (one to retrieve all todos and one for a specific one) and a mutation (a request to mutate state) to create a new todo. The mutation takes a `TodoInput` which is basically the todo model minus the auto generated ID.

Normally `gqlgen` would generate the actual struct/model to use in GraphQL. Since I already have it (the one used in the REST API), fortunately I can just tell the generator to "import" it from the business logic. More details are in the [gqlgen documentation](https://gqlgen.com/getting-started/).

Next step is to create the `resolvers`, methods invoked by the GraphQL servers to return or create data, for example:

```go
package gql

type Resolver struct {
  DB *DataStore
}

func (r *Resolver) Query_todos(ctx context.Context) ([]models.Todo, error) {
  todos, err := r.DB.Todos()
  return todos, err
}

func (r *Resolver) Query_todo(ctx context.Context, todoID string) (*models.Todo, error) {
  todo, err := r.DB.Todo(todoID)
  return todo, err
}

func (r *Resolver) Mutation_createTodo(ctx context.Context, todo models.Todo) (*models.Todo, error) {
  todo.TodoID = uuid.NewV4().String()
  err := r.DB.CreateTodo(&todo)
  return &todo, err
}
```

The first calls the business logic to retrieve all todos, the second retrieves a single todo, the third creates a new one. I'm 100% reusing some of the business logic in common with the REST API.

Last step is creating the server itself:

```go
gqlServer := &gql.Resolver{DB: db}
router.Handle("/gql-playground", handler.Playground("Todo", "/graphql"))
router.Handle("/graphql", handler.GraphQL(gql.MakeExecutableSchema(gqlServer)))
```

These three magical lines expose a playground to test queries and an actual graphql server. I wouldn't recommend to enable the playground in production :D

## Python GraphQL Client

Now that we have a server, we need a client in Python to see if everything is working.

I'm using [pygql](https://pypi.org/project/pygql/), like this:

```python
from pygql import Client, gql
from pygql.transport.requests import RequestsHTTPTransport

# the URL is the url of the Go server
transport = RequestsHTTPTransport('http://localhost:8080/graphql', use_json=True)
# we tell Python to fetch the schema by itself!
client = Client(transport=transport, fetch_schema_from_transport=True)

# let's build a query to get all the ids and the titles of the todos in the db
query = gql("""
  query {
    todos {
      todoID
      title
    }
  }
""")

client.execute(query)
```

This is the output:

```python
{
    'todos': [{
        'todoID': '403d9f8c-cdc3-4784-9582-aa0677681f4a',
        'title': 'I need to remember'
    }, {
        'todoID': '90b0edbc-75a8-4ae3-b345-11c520578f26',
        'title': 'There is something I need to remember'
    }]
}
```

As you can see the GraphQL server only sent up what we asked for, invoking the right resolvers and doing all the right transformations.

By subtistuting the query with a mutation

```python
query = gql("""
mutation createTodo {
  createTodo(todo: {
    title: "Another thing I need to remember",
    text: "A very long text about everything I need to do"
  }) {
    todoID
    title
    text
  }
}
""")
```

we create a new todo on the server and get back its id and the rest of the fields if we need to.

## Conclusion

This way we can build "incrementally" an API between two servers without "committing" to a definite schema. Changing the schema is super easy on the server and the client will know what to expect. The Python client also raises exceptions if the field we asked for is not in the schema without having to make a round trip to the server to get an error. The great thing is that it's the client that decides what data to fetch.

A couple of considerations:

* There is no auth between the two, that it's not a good idea for obvious reasons. I'm currently deciding how to do it properly. I was thinking to use the [Client Credentials OAuth 2 flow](https://www.digitalocean.com/community/tutorials/an-introduction-to-oauth-2#grant-type-client-credentials) (shout out to Digital Ocean for the great OAuth 2 tutorial!). This way I can control the lifetime of the tokens and who's getting access. If you have suggestions they are more than welcome.

* It's not all rainbows and unicorns, GraphQL is kind of opaque in the logs and it doesn't work with HTTP caching. You can read a thorough comparison of the two approaches here: https://philsturgeon.uk/api/2017/01/24/graphql-vs-rest-overview/

