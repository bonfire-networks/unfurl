defmodule Unfurl.Parser.JsonLD do
  @behaviour Unfurl.Parser

  @json_library Application.get_env(:unfurl, :json_library, Jason)

  @spec parse(String.t()) :: nil | {:ok, List.t()}
  def parse(html, _opts \\ []) do
    meta = "script[type=\"application/ld+json\"]"

    html
    # |> Floki.parse_document()
    # |> elem(1)
    |> Floki.find(meta)
    |> case do
      nil ->
        {:ok, []}

      elements ->
        json_ld =
          elements
          |> Enum.map(&decode/1)
          |> List.flatten()
          |> Enum.uniq()

        {:ok, json_ld}
    end
  end

  defp decode(element) do
    element
    |> Floki.text(js: true)
    |> @json_library.decode!()
  end
end
