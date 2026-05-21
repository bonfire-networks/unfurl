defmodule Unfurl.Parser do
  use Arrows

  @doc """
  Parses the given HTML, returning a map structure of structured
  data keys mapping to their respective values, or an error.
  """
  @callback parse(html :: String.t()) :: {:ok, Map.t()} | {:error, Atom.t()}

  @doc """
  Extracts the given tags from the given raw html according to
  the given match function
  """
  @spec extract(List.t() | String.t(), String.t(), Function.t()) :: Map.t()
  def extract(tag, html, match, extract_attr \\ "content")

  def extract(tags, html, match, extract_attr) when is_list(tags) do
    tags
    |> Stream.map(&extract(&1, html, match, extract_attr))
    |> Enum.reject(fn
      {_, v} -> is_nil(v)
      nil -> true
    end)
    |> Map.new()
    |> maybe_group_keys()
  end

  def extract(tag, html, match, extract_attr) when is_binary(html) do
    html
    |> Floki.parse_document()
    ~> extract(tag, ..., match, extract_attr) 
  end

  def extract(tag, html, match, extract_attr) do
    html
    |> Floki.find(match.(tag))
    |> case do
      nil ->
        nil

      [] ->
        nil

      elements ->
        content =
          case do_extract_content(elements, extract_attr) do
            [] -> nil
            [element] -> element
            content -> content
          end

        {tag, content}
    end
  end

  @doc "Extracts a canonical url from the given raw HTML"
  @spec extract_canonical(String.t()) :: nil | String.t()
  def extract_canonical(html) when is_binary(html) do
    html
    |> Floki.parse_document()
    ~> extract_canonical()
  end
  def extract_canonical(html) do
    html
    |> Floki.find("link[rel=\"canonical\"]")
    |> case do
      [] ->
        nil

      elements ->
        elements
        |> Floki.attribute("href")
        |> Enum.at(0)
    end
  end

  @doc """
  Groups colon-separated keys into dynamic map structures

  ## Examples

      iex> Application.put_env(:unfurl, :group_keys?, false)
      iex> Unfurl.Parser.maybe_group_keys %{"twitter:app:id" => 123, "twitter:app:name" => "YouTube"}
      %{"twitter:app:id" => 123, "twitter:app:name" => "YouTube"}

      iex> Application.put_env(:unfurl, :group_keys?, true)
      iex> Unfurl.Parser.maybe_group_keys %{"twitter:app:id" => 123, "twitter:app:name" => "YouTube"}
      %{
        "twitter" => %{
          "app" => %{
            "id" => 123,
            "name" => "YouTube"
          }
        }
      }

      iex> Application.put_env(:unfurl, :group_keys?, true)
      iex> Unfurl.Parser.maybe_group_keys %{"og:image" => "http://x/i.jpg", "og:image:width" => "1200"}
      %{"og" => %{"image" => %{"url" => "http://x/i.jpg", "width" => "1200"}}}
  """
  @spec maybe_group_keys(Map.t()) :: Map.t()
  def maybe_group_keys(map)

  def maybe_group_keys(map) do
    if Application.get_env(:unfurl, :group_keys?, true) do
      do_group_keys(map)
    else
      map
    end
  end

  defp do_group_keys(map) do
    Enum.reduce(map, %{}, fn
      {_, v}, _acc when is_map(v) -> do_group_keys(v)
      {k, v}, acc -> do_group_keys(k, v, acc)
    end)
  end

  defp do_group_keys(key, value, acc) do
    [h | t] = key |> String.split(":") |> Enum.reverse()
    base = Map.new([{h, value}])

    result =
      Enum.reduce(t, base, fn key, sub_acc ->
        Map.new([{key, sub_acc}])
      end)

    deep_merge(acc, result)
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  # A bare value (e.g. `og:image`) colliding with its structured sub-properties
  # (e.g. `og:image:width`) must not be discarded: per the OpenGraph spec the bare
  # value is equivalent to the `:url` sub-property, so fold it in rather than letting
  # one clobber the other (which would lose the actual image URL).
  defp deep_resolve(_key, left, right) when is_map(left) and is_binary(right) do
    Map.put_new(left, "url", right)
  end

  defp deep_resolve(_key, left, right) when is_binary(left) and is_map(right) do
    Map.put_new(right, "url", left)
  end

  defp deep_resolve(_key, _left, right) do
    right
  end

  defp do_extract_content(elements, extract_attr) do
    elements
    |> Enum.map(fn element ->
      element
      |> Floki.attribute(extract_attr)
      |> Enum.at(0)
    end)
  end
end
