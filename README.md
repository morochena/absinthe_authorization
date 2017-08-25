# Blanka

[Documentation](https://hexdocs.pm/blanka/0.1.0) | [Example Phoenix App](https://github.com/morochena/phoenix-authorization-example)

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

This function creates the authorization rules that are checked by `with_auth`. It's important to note that rules are checked in reverse order to how they were declared (bottom-up) - the first rule that matches will be the one that is used.

#### field (atom)

The first parameter is an atom corresponds to the field in your schema. If you have multiple schemas with the same field (like a query and a mutation) - the authorization rules will apply to both.

#### pattern (struct, function or blank map)

Structs are compared to info.context.current_user, assuming you followed the strategy outlined here.

Functions have have access to resource and info parameter. Info is the same map that is passed in to the resolver. Resource is actually the result of the resolver returning as if it was authorized. Keep this in mind for mutations, I haven't figured out an elegant way to avoid this for now.

Blank maps will always match.

#### whitelist (list)

If specified, the whitelist nils any values from the result of the resolver if they do not match the structure of the list provided. If the result is a list, it will apply it to all objects in the list.

Simple Example:

``` elixir
authorize :user, %{}, [:name, :username]

# result from resolver
%{
  id: 3,
  name: "Greg",
  email: "climbinggreg@foo.com",
  username: "climber_guy123"
}

# filtered result
%{
  id: nil,
  name: "Greg",
  email: nil,
  username: "climber_guy123"
}
```