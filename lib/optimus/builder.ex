defmodule Optimus.Builder do
  alias Optimus
  alias Optimus.PropertyParsers, as: PP

  def build(props) do
    if Keyword.keyword?(props) do
        case build_from_props(props) do
          {:ok, _arg} = res -> res
          {:error, reason} -> {:error, reason}
        end
    else
      {:error, "#{__MODULE__}.new expects a keyword list"}
    end
  end

  defp build_from_props(props) do
    with {:ok, name} <- build_name(props),
    {:ok, executable} <- build_executable(props),
    {:ok, version} <- build_version(props),
    {:ok, author} <- build_author(props),
    {:ok, about} <- build_about(props),
    {:ok, allow_extra_args} <- build_allow_extra_args(props),
    {:ok, parse_double_dash} <- build_parse_double_dash(props),
    {:ok, args} <- build_args(props[:args]),
    {:ok, flags} <- build_flags(props[:flags]),
    {:ok, options} <- build_options(props[:options]),
    :ok <- validate_args(args),
    :ok <- validate_conflicts(flags, options),
    do: {:ok, %Optimus{name: name, version: version, author: author, about: about, allow_extra_args: allow_extra_args, parse_double_dash: parse_double_dash, args: args, flags: flags, options: options, executable: executable}}
  end

  defp build_name(props) do
    PP.build_string(:name, props[:name], nil)
  end

  defp build_executable(props) do
    PP.build_string(:executable, props[:executable], nil)
  end

  defp build_version(props) do
    PP.build_string(:version, props[:version], nil)
  end

  defp build_author(props) do
    PP.build_string(:author, props[:author], nil)
  end

  defp build_about(props) do
    PP.build_string(:about, props[:about], nil)
  end

  defp build_allow_extra_args(props) do
    PP.build_bool(:allow_extra_args, props[:allow_extra_args], false)
  end

  defp build_parse_double_dash(props) do
     PP.build_bool(:parse_double_dash, props[:parse_double_dash], true)
  end

  defp build_args(specs), do: build_specs("args", Optimus.Arg, specs)
  defp build_flags(specs), do: build_specs("flags", Optimus.Flag, specs)
  defp build_options(specs), do: build_specs("options", Optimus.Option, specs)

  defp build_specs(_name, _module, nil), do: {:ok, []}
  defp build_specs(name, module, specs) do
    if Keyword.keyword?(specs) do
      build_specs_(module, specs, [])
    else
      {:error, "#{name} specs are expected to be a Keyword list"}
    end
  end

  defp build_specs_(_module, [], parsed), do: {:ok, Enum.reverse(parsed)}
  defp build_specs_(module, [{_name, _props} = arg_spec | other], parsed) do
    with {:ok, arg} <- module.new(arg_spec),
    do: build_specs_(module, other, [arg | parsed])
  end

  defp validate_args([arg1, arg2 | other]) do
    if !arg1.required && arg2.required do
      {:error, "required argument #{inspect arg2.name} follows optional argument #{inspect arg1.name}"}
    else
      validate_args([arg2 | other])
    end
  end

  defp validate_args(_), do: :ok

  defp validate_conflicts(flags, options) do
    with :ok <- validate_conflicts(flags, options, :short),
    :ok <- validate_conflicts(flags, options, :long),
    do: :ok
  end

  defp validate_conflicts(flags, options, key) do
    all_options = flags ++ options
    duplicate = all_options
    |> Enum.group_by(fn(item) -> Map.get(item, key) end, fn(item) -> item end)
    |> Map.to_list
    |> Enum.find(fn({option_name, options}) -> option_name && length(options) > 1 end)

    case duplicate do
      {name, _} -> {:error, "duplicate #{key} option name: #{name}"}
      nil -> :ok
    end
  end

end
