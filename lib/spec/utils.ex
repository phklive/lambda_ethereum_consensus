defmodule SpecTestUtils do
  @moduledoc """
  Utilities for spec tests.
  """

  @vectors_dir Path.join(["test", "spec", "vectors", "tests"])

  def vectors_dir, do: @vectors_dir

  def cases_for(filter) do
    [:config, :fork, :runner, :handler, :suite, :case]
    |> Enum.map(fn key -> filter[key] || "*" end)
    |> then(&[@vectors_dir | &1])
    |> Path.join()
    |> Path.wildcard()
    |> Stream.map(&Path.relative_to(&1, SpecTestUtils.vectors_dir()))
    |> Stream.map(&Path.split/1)
    |> Enum.map(&SpecTestCase.new/1)
  end

  @spec sanitize_yaml(any()) :: any()
  def sanitize_yaml(map) when is_map(map) do
    map
    |> Stream.map(&sanitize_yaml/1)
    |> Map.new()
  end

  def sanitize_yaml(list) when is_list(list), do: Enum.map(list, &sanitize_yaml/1)
  def sanitize_yaml({"extra_data", x}), do: {:extra_data, parse_as_string(x)}

  def sanitize_yaml({"transactions", list}),
    do: {:transactions, Enum.map(list, &parse_as_string/1)}

  def sanitize_yaml({k, v}), do: {String.to_atom(k), sanitize_yaml(v)}
  def sanitize_yaml("0x"), do: <<0>>
  def sanitize_yaml("0x" <> hash), do: Base.decode16!(hash, [{:case, :lower}])

  def sanitize_yaml(x) when is_binary(x) do
    case Integer.parse(x) do
      {num, ""} -> num
      _ -> x
    end
  end

  def sanitize_yaml(v), do: v

  # Some values are wrongly formatted as integers sometimes
  defp parse_as_string(0), do: ""
  defp parse_as_string(x) when is_integer(x), do: :binary.encode_unsigned(x, :little)
  defp parse_as_string("0x" <> hash), do: Base.decode16!(hash, [{:case, :lower}])

  @spec read_ssz_from_optional_file!(binary, module) :: any() | nil
  def read_ssz_from_optional_file!(file_path, ssz_type) do
    if File.exists?(file_path) do
      compressed = File.read!(file_path)
      {:ok, decompressed} = :snappyer.decompress(compressed)
      {:ok, ssz_object} = Ssz.from_ssz(decompressed, ssz_type)
      ssz_object
    else
      nil
    end
  end

  @spec read_ssz_from_file!(binary, module) :: any()
  def read_ssz_from_file!(file_path, ssz_type) do
    case read_ssz_from_optional_file!(file_path, ssz_type) do
      nil -> raise "File not found: #{file_path}"
      ssz_object -> ssz_object
    end
  end

  @spec resolve_type_from_handler(String.t(), map()) :: module()
  def resolve_type_from_handler(handler, map) do
    case Map.get(map, handler) do
      nil -> raise "Unknown case #{handler}"
      type -> Module.concat(SszTypes, type)
    end
  end

  @spec resolve_name_from_handler(String.t(), map()) :: String.t()
  def resolve_name_from_handler(handler, map) do
    case Map.get(map, handler) do
      nil -> raise "Unknown case #{handler}"
      name -> name
    end
  end
end
