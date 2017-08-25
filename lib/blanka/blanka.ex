defmodule Blanka do

  @moduledoc """
  Blanka adds basic authorization logic to an Absinthe based GraphQL implementation. You're able to define simple, declarative authorization rules to control who has access to what.

  Implementation is meant to be simple and straightforward. You add authorization rules to the top of your `schema.ex` file, and then wrap the reference to the resolver in the authorization function.

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
  """

  defmacro __using__(_opts) do
    quote do
      import Blanka
      @white_list []
      @before_compile Blanka
    end
  end

  @doc """
  Creates the authorization rules that are checked by with_auth. 
  
  It's important to note that rules are checked in reverse order to how they were declared (bottom-up) - the first rule that matches will be the one that is used.
  
  #### field (atom)

  The first parameter is an atom corresponds to the field in your schema. If you have multiple schemas with the same field (like a query and a mutation) - the authorization rules will apply to both.

  #### pattern (struct, function or blank map)

  Structs are compared to info.context.current_user, assuming you followed the strategy outlined here.

  Functions have have access to resource and info parameter. Info is the same map that is passed in to the resolver. Resource is actually the result of the resolver returning as if it was authorized. Keep this in mind for mutations, I haven't figured out an elegant way to avoid this for now.

  Blank maps will always match.

  #### whitelist (list)

  If specified, the whitelist nils any values from the result of the resolver if they do not match the structure of the list provided. If the result is a list, it will apply it to all objects in the list.
  
  ##### Simple Example

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

  ##### Nested Example

  ``` elixir
  # rule
  authorize :user, %User{}, [:name, {:posts, [:title, :body, {:comments, [:body]}]}]

  # result from resolver
  %{
    id: 3, 
    name: "Greg", 
    email: "climbinggreg@foo.com", 
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

  # filtered result from resolver
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


  """
  defmacro authorize(field, pattern, whitelist \\ []) do
    quote do
      field = unquote(field)
      pattern = unquote(pattern)
      whitelist = unquote(whitelist)
      @white_list [{field, pattern, whitelist} | @white_list]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def with_auth(field, attributes, info, resolver) do
        rules = Enum.filter(@white_list, fn rule -> field == elem(rule, 0) end)
        current_user = get_in(info.context, [:current_user])

        matched_rule = find_matching_rule(rules, current_user, attributes, info, resolver)

        case matched_rule do
          nil -> {:error, "Unauthorized"}
          {_field, _pattern, []} -> resolver.(attributes, info)
          {_field, _pattern, whitelist} -> filter_params(whitelist, resolver.(attributes, info))
        end
      end
    end
  end

    @doc false
    def find_matching_rule(rules, current_user, attributes, info, resolver) do
      Enum.find(rules, fn rule ->
        case elem(rule, 1) do
          # match on struct
          %{__struct__: pattern} -> compare_structs(pattern, current_user)

          # match on function reference
          pattern when is_function(pattern) ->
            resource = resolver.(attributes, info)
            compare_functions(pattern, resource, info)

            # match on blank map
            %{} -> true

            # not a match
            _ -> false
        end
      end)
    end

    @doc false
    def compare_structs(rule_struct, current_user) when is_map(current_user) do
      rule_struct == current_user.__struct__
    end

    @doc false
    def compare_structs(rule_struct, current_user) do
      false
    end

    @doc false
    def compare_functions(rule_func, resource, info) do
      {:ok, resource} = resource
      {rule_func, []} = Code.eval_quoted(rule_func)
      rule_func.(resource, info)
    end

    @doc false
    def filter_params(whitelist_params, result) do
      case result do
        {:ok, res} when is_list(res) -> {:ok, filter_list(whitelist_params, res)}
        {:ok, res} when is_map(res)  -> {:ok, filter_struct(whitelist_params, res)}
      end
    end

    @doc false
    def filter_list(whitelist_params, results) do
      Enum.map(results, fn struct -> filter_struct(whitelist_params, struct) end)
    end

    @doc false
    def filter_struct(whitelist_params, struct) do
      whitelist_params = [:__meta__, :__struct__ | whitelist_params]

      Enum.reduce Map.keys(struct), %{}, fn key, acc ->
        cond do
          Enum.member?(whitelist_params, key) -> Map.put(acc, key, Map.get(struct, key))
          has_tuple?(whitelist_params, key) and not is_nil(Map.get(struct, key)) ->
            cond do
              is_map(Map.get(struct, key)) ->
                Map.put(acc, key, filter_struct(elem(get_tuple(whitelist_params, key), 1), Map.get(struct, key)))
              is_list(Map.get(struct, key)) ->
                Map.put(acc, key, Enum.map(Map.get(struct, key), fn mapp -> filter_struct(elem(get_tuple(whitelist_params, key), 1), mapp) end))
            end
          true -> Map.put(acc, key, nil)
        end
      end
    end

    @doc false
    def has_tuple?(params, key) do
      Enum.any? params, fn(param) ->
        case param do
          {^key, _} -> true
          _         -> false
        end
      end
    end

    @doc false
    def get_tuple(params, key) do
      Enum.find params, fn(param) ->
        case param do
          {^key, _} -> true
          _         -> false
        end
      end
    end

  end