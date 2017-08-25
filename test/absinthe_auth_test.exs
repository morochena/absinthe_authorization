defmodule Admin do
  defstruct id: 1, name: "admin"
end

defmodule Mod do
  defstruct id: 1, name: "moderator"
end

defmodule User do
  defstruct id: 1, name: "user"
end

defmodule Blanka.AuthTest do
  use ExUnit.Case
  use Blanka
  doctest Blanka

  @fakedb [
    %{id: 1, name: "Bob", email: "bubba@foo.com", posts: nil},
    %{id: 2, name: "Fred", email: "fredmeister@foo.com", posts: nil},
    %{id: 3, name: "Greg", email: "climbingreg@foo.com", posts: [
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
      }},
    %{id: 4, name: "Heinz", email: "theketchup@foo.com", company: %{
        id: 200, 
        name: "Foo Productions",
        industry: "Film"
      }
    }
  ]

  def user_resolver(%{id: id}, _info) do
    case Enum.find @fakedb, fn user -> user.id == id end do
      nil ->  {:error, "User id #{id} not found"}
      user -> {:ok, user}
    end
  end

  authorize :user, %{}, [:name]
  authorize :user, %User{}, [:name, 
                              {:posts, [:title, :body, 
                                {:comments, [:body]}]}]
  authorize :user, &Blanka.AuthTest.owns_resource/2 
  authorize :user, %Mod{}, [:id, :name, {:company, [:name, :industry]}]
  authorize :user, %Admin{}

  def owns_resource(resource, info) do
    cond do 
      is_map(info.context.current_user) -> resource.id == info.context.current_user.id
      true -> false
    end
  end

  test "with_auth should only return name when not authenticated" do 
    attributes = %{id: 1}
    info = %{context: %{current_user: nil}}

    assert {:ok, user} = with_auth(:user, attributes, info, &Blanka.AuthTest.user_resolver/2)
    assert user.id == nil
    assert user.name == "Bob"
    assert user.email == nil
  end

  test "with_auth should return all attributes when admin" do 
    attributes = %{id: 2}
    info = %{context: %{current_user: %Admin{}}}

    assert {:ok, user} = with_auth(:user, attributes, info, &Blanka.AuthTest.user_resolver/2)
    assert user.id == 2
    assert user.name == "Fred"
    assert user.email == "fredmeister@foo.com"
  end

  test "with_auth scrubs nested data - map" do 
    attributes = %{id: 4}
    info = %{context: %{current_user: %Mod{}}}

    assert {:ok, user} = with_auth(:user, attributes, info, &Blanka.AuthTest.user_resolver/2)
    assert user.id == 4
    assert user.name == "Heinz"
    assert user.email == nil
    assert user.company.id == nil
    assert user.company.name == "Foo Productions"
    assert user.company.industry == "Film"
  end

  test "with_auth scrubs nested data - list" do 
    attributes = %{id: 3}
    info = %{context: %{current_user: %User{}}}

    assert {:ok, user} = with_auth(:user, attributes, info, &Blanka.AuthTest.user_resolver/2)
    assert user.id == nil
    assert user.name == "Greg"
    assert user.email == nil
  end

  test "with_auth  works with arbitrary function" do 
    attributes = %{id: 2}
    info = %{context: %{current_user: %User{id: 2}}}

    assert {:ok, user} = with_auth(:user, attributes, info, &Blanka.AuthTest.user_resolver/2)
    assert user.id == 2
    assert user.name == "Fred"
    assert user.email == "fredmeister@foo.com"
  end

end

