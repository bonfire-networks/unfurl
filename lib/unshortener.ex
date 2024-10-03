defmodule Unfurl.Unshortener do
  import Untangle

  @doc """
  Unshorten a URL by following redirects.
  Returns {:ok, final_url} on success or {:error, reason} on failure.

  ## Examples

      iex> unshorten("https://bit.ly/example")
      {:ok, "https://example.com/very/long/url"}

  """
  def unshorten(short_url) do

    # TODO: integrate with `Unfurl.unfurl` so URL's are stored without shorteners (or at least the canonical url is added to metadata)? in which case we should avoid duplicated fetching of the head (also done by `Faviconic`) 

    case Unfurl.Fetcher.head(short_url) do
      {:ok, %{url: url} = head} ->
        # The final URL after following redirects
        debug(head, "headd")
        {:ok, url}
      
      {:error, error} ->
        error(error, "Failed to unshorten URL")
    end
  end

  def unshorten!(short_url) do
    with {:ok, url} <- unshorten(short_url) do
        url
    else _ ->
        short_url
    end
  end

  @doc """
  Unshorten multiple URLs concurrently.
  Returns a list of {:ok, final_url} or {:error, reason} tuples.

  ## Examples

      iex> unshorten_many(["https://bit.ly/ex1", "https://t.co/ex2"])
      [
        {:ok, "https://example.com/long/url1"},
        {:ok, "https://example.com/long/url2"}
      ]

  """
  def unshorten_many(urls) when is_list(urls) do
    urls
    |> Task.async_stream(&unshorten/1, timeout: 10_000)
    |> Enum.map(fn {:ok, result} -> result end)
  end
end
