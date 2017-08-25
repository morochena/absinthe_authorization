defmodule Blanka do
  
  defmacro __using__(_opts) do
    quote do
      import Blanka
      @white_list []
      @before_compile Blanka
    end
  end
  
  defmacro authorize(field, pattern) do
    quote do
      @white_list [unquote({field, pattern}) | @white_list]
    end
  end
  
  defmacro authorize(field, pattern, params) do
    quote do
      field = unquote(field)
      pattern = unquote(pattern)
      params = unquote(params)
      @white_list [{field, pattern, params} | @white_list]
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      def with_auth(field, attributes, info, resolver) do
        field_whitelists = Enum.filter(@white_list, fn rule -> field == elem(rule,0) end)
        current_user = get_in(info.context, [:current_user])
        
        matched_rule = Enum.find(field_whitelists, fn auth_rule ->
          
          case elem(auth_rule, 1) do        
            # match on struct
            %{__struct__: rule_struct} -> compare_structs(rule_struct, current_user)
            
            # function reference
            func when is_function(func) -> 
              resource = resolver.(attributes, info)
              compare_functions(func, resource, info)
              
              # match on blank map
              %{} -> true
              
              # not a match
              _ -> false
            end
          end)
          
          case matched_rule do
            nil -> {:error, "Unauthorized"}
            {_field, _pattern, params} -> filter_params(params, resolver.(attributes, info))
            {_field, _pattern} -> resolver.(attributes, info)
          end
        end
      end
    end
    
    def compare_structs(rule_struct, current_user) when is_map(current_user) do
      rule_struct == current_user.__struct__
    end
    
    def compare_structs(rule_struct, current_user) do
      false
    end
    
    def compare_functions(rule_func, resource, info) do
      {:ok, resource} = resource
      {rule_func, []} = Code.eval_quoted(rule_func)
      rule_func.(resource, info)
    end
    
    def filter_params(whitelist_params, result) do
      case result do
        {:ok, res} when is_list(res) -> {:ok, filter_list(whitelist_params, res)}
        {:ok, res} when is_map(res)  -> {:ok, filter_struct(whitelist_params, res)}
      end
    end
    
    def filter_list(whitelist_params, results) do
      Enum.map(results, fn struct -> filter_struct(whitelist_params, struct) end)
    end
    
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

    def has_tuple?(params, key) do      
      Enum.any? params, fn(param) ->
        case param do
          {^key, _} -> true
          _         -> false
        end
      end
    end
    
    def get_tuple(params, key) do
      Enum.find params, fn(param) ->
        case param do
          {^key, _} -> true
          _         -> false 
        end
      end
    end  

  end
