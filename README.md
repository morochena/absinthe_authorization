# Blanka

[Documentation](https://hexdocs.pm/blanka)

Provides basic declarative authorization functionality to [Absinthe](https://github.com/absinthe-graphql/absinthe) based GraphQL APIs in Phoenix.

## Installation

```elixir
def deps do
  [{:blanka, "~> 0.1.0"}]
end
```

## Basic Usage 

Add Blanka and some rules to your schema.ex:

``` elixir
defmodule ExampleApp.Schema do
  use Absinthe.Schema
  import_types BlogWeb.Schema.Types
  use Blanka

  authorize :posts, %{}, [:body, :title, {:user, [:username]}]
  authorize :user, %{}, [:username, :posts]
  authorize :user, &ExampleApp.Schema.owns_resource/2  
  authorize :create_post, %Blog.Accounts.User{}

  # example of arbitrary function that can be used in
  # authorization rules
  def owns_resource(resource, info) do
    resource.id == info.context.current_user.id
  end

  # ... 
end
```

Wrap your resolvers with the `with_auth` function:

``` elixir
@desc "Get a user of the blog"
field :user, type: :user do
  arg :id, non_null(:id)
  resolve fn attributes, info -> 
    with_auth(:user, attributes, info, &BlogWeb.UserResolver.find/2)
  end 
end
```

## Authorize 

`authorize(field, pattern, whitelist // [])` 

This function creates the authorization rules that are checked by `with_auth`. It's imporrtant to note that rules are checked in descending order. The first rule that matches will the current request will be the one that goes through. 

#### field (atom)

The first parameter is an atom corresponds to the field in your schema. If you have multiple schemas with the same field (like a query and a mutation) - the authorization rules will apply to both.

#### pattern (struct or function)

Structs are compared to `info.context.current_user`, assuming you followed the strategy outlined [here](http://absinthe-graphql.org/guides/context-and-authentication/).

Functions have have access to `resource` and `info` parameter. Info is the same map that is passed in to the resolver. Resource is actually the result of the resolver returning as if it was authorized. Keep this in mind for mutations, I haven't figured out an elegant way to avoid this for now. 

#### whitelist (list)

If specified, the whitelist nils any values from the result of the resolver if they do not match the structure of the list provided. If the result is a list, it will apply it to all objects in the list.

``` elixir
# given a rule like this
authorize :user, %User{}, [:name, {:posts, [:title, :body, {:comments, [:body]}]}]

# applied to this
%{
  id: 3, 
  name: "Greg", 
  email: "climbingreg@foo.com", 
  posts: [
    %{
      id: 1,
      title: "This is my first post!", 
      body: "This is the best post ever!",
      comments: [
        %{
          id: 555,
          body: "This is an interesting comment"
        }
      ]
    }
  ],
  company: %{
    id: 200, 
    name: "Foo Productions",
    industry: "Film"
  }
}

# will result in
%{
  id: nil, 
  name: "Greg", 
  email: nil, 
  posts: [
    %{
      id: nil,
      title: "This is my first post!", 
      body: "This is the best post ever!",
      comments: [
        %{
          id: nil,
          body: "This is an interesting comment"
        }
      ]
    }
  ],
  company: nil
}
```

