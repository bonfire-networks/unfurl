defmodule Unfurl.Parser.JsonLD do
  use Arrows
  import Untangle
  @behaviour Unfurl.Parser

  @json_library Application.compile_env(:unfurl, :json_library, Jason)

  @spec parse(String.t()) :: nil | {:ok, List.t()}
  def parse(html, _opts \\ [])
  def parse(html, _opts) when is_binary(html) do
    html
    |> Floki.parse_document()
    ~> parse()
  end
  def parse(html, _opts) do
    meta = "script[type=\"application/ld+json\"]"

    html
    # |> debug("HTML elements")
    |> Floki.find(meta)
    # |> debug("JSON-LD elements")
    |> case do
      nil ->
        {:ok, []}

      [] ->
        {:ok, []}

      elements ->
        json_ld =
          elements
          |> Enum.flat_map(&decode/1)
          |> List.flatten()
          |> Enum.uniq()

        {:ok, json_ld}
    end
  end

  defp decode(element) do
    element
    |> Floki.text(js: true)
    |> String.trim()
    # |> debug("JSON-LD element")
    |> safe_decode()
  end

  defp safe_decode(""), do: []
  defp safe_decode(json) do
    case @json_library.decode(json) do
      {:ok, data} -> List.wrap(data)
      {:error, e} -> 
        warn(e, "Failed to decode JSON-LD")
        []
    end
  end

end
