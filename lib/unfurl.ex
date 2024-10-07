defmodule Unfurl do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Application
  import Untangle

  alias Unfurl.{Fetcher, Parser, Oembed}
  alias Unfurl.Parser.{Facebook, HTML, JsonLD, Twitter, RelMe}

  @doc false
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Unfurl.Supervisor]

    children = [
      Unfurl.Oembed
    ]

    Supervisor.start_link(children, opts)
  end

  @doc """
  Unfurls a url

  Fetches oembed data if available, as well as the source HTML to be parsed by `unfurl_html/3`.

  Also accepts opts as a keyword list.
  """
  @spec unfurl(String.t(), Keyword.t()) :: {:ok, Map.t()} | {:error, Atom.t()}
  def unfurl(url, opts \\ []) do
    case fetch(url, opts) do
      {:ok, {body, status_code}, oembed_meta} when is_binary(body) ->
        unfurl_html(
          url,
          body,
          Keyword.merge(opts,
            # because already done in `fetch/2`
            skip_oembed_fetch: true,
            extra: Enum.into(oembed_meta || %{}, %{status_code: status_code})
          )
        )

      other ->
        error(other, "Could not fetch any metadata")
    end
  end

  @doc """
  Extracts data from the pre-fetched HTML source of a URL

  Checks for Twitter Card, Open Graph, JSON-LD, rel-me, and other HTML meta tags.

  Also tries to find and/or fetch (disable all with `skip_fetches: true`):
  - a favicon (disable with `skip_favicon_fetch: true`)
  - oembed info (disable with `skip_oembed_fetch: true`)
  """
  def unfurl_html(url, body, opts \\ []) do
    with {:ok, body} <- Floki.parse_document(body),
         canonical_url <- Parser.extract_canonical(body),
         {:ok, results} <-
           parse(
             body,
             # ++ [urls: [url, canonical_url]]
             opts
           ) do
      {:ok,
       Map.merge(results || %{}, opts[:extra] || %{})
       |> Map.merge(%{
         canonical_url: if(canonical_url != url, do: canonical_url),
         favicon:
           if(!opts[:skip_favicon_fetch] and !opts[:skip_fetches], do: maybe_favicon(url, body)),
         oembed:
           opts[:extra][:oembed] ||
             if(!opts[:skip_oembed_fetch] and !opts[:skip_fetches],
               do: Oembed.detect_and_fetch(url, body, opts)
             )
       })}
    end
  end

  defp fetch(url, opts) do
    fetch_oembed = Task.async(Oembed, :fetch, [url, opts])
    fetch_html = Task.async(Fetcher, :fetch, [url, opts])

    case Task.yield_many([fetch_oembed, fetch_html], timeout: 4000, on_timeout: :kill_task) do
      [{_fetch_oembed, {:ok, {:ok, oembed}}}, {_fetch, {:ok, {:ok, body, status_code}}}] ->
        # oembed found + HTML fetched
        {:ok, {body, status_code}, oembed || Oembed.detect_and_fetch(url, body, opts)}

      [{_fetch_oembed, {:ok, {:ok, oembed}}}, other] ->
        debug(other, "No HTML fetched")
        # oembed was found from a known provider
        {:ok, {nil, nil}, oembed}

      [other, {_fetch, {:ok, {:ok, body, status_code}}}] ->
        debug(other, "No oembed found from known provider, try finding one in HTML")
        {:ok, {body, status_code}, Oembed.detect_and_fetch(url, body, opts)}

      [other_oembed, other_html] ->
        error(other_oembed, "Error fetching oembed")
        error(other_html, "Error fetching HTML")
        {:error, :fetch_error}

      e ->
        error(e, "Error fetching oembed or HTML")
        {:error, :fetch_error}
    end
  end

  defp parse(body, opts) do
    parse = &Task.async(&1, :parse, [body, opts])
    tasks = Enum.map([Facebook, Twitter, JsonLD, RelMe, HTML], parse)

    with [facebook, twitter, json_ld, rel_me, other] <- Task.yield_many(tasks),
         {_facebook, {:ok, {:ok, facebook}}} <- facebook,
         {_twitter, {:ok, {:ok, twitter}}} <- twitter,
         {_json_ld, {:ok, {:ok, json_ld}}} <- json_ld,
         {_rel_me, {:ok, {:ok, rel_me}}} <- rel_me,
         {_other, {:ok, {:ok, other}}} <- other do
      {:ok,
       %{
         facebook: facebook,
         twitter: twitter,
         json_ld: json_ld,
         other: other,
         rel_me: rel_me
       }}
    else
      _ -> {:error, :parse_error}
    end
  end

  def maybe_favicon(url, body) do
    case URI.parse(url) do
      # %URI{host: nil, path: nil} ->
      %URI{host: nil} ->
        warn(url, "expected a valid URI, but got")
        debug(body)

        with true <- body != [],
             {:ok, url} <- Faviconic.find(nil, body) do
          url
        else
          _ ->
            nil
        end

      # %URI{scheme: nil, host: nil, path: host_detected_as_path} ->
      #   with {:ok, url} <- Faviconic.find(host_detected_as_path, body) do
      #   url
      # else _ ->
      #   nil
      # end

      %URI{scheme: "doi"} ->
        nil

      %URI{} ->
        with {:ok, url} <- Faviconic.find(url, body) do
          url
        else
          _ ->
            nil
        end
    end
  end

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


  def url_ip_address!(url) do
    with {:ok, ip} <- url_ip_address(url) do
        ip
    else _ ->
        nil
    end
  end

  def url_ip_address(url) do
    uri_host(url)
    |> domain_ip_address()
  end
  
  def domain_ip_address(host) when is_binary(host) do
    with {:ok, {:hostent, _, _, _, _, [ip_tuple|_]}} <- :inet.gethostbyname(String.to_charlist(host)) do
        {:ok, :inet.ntoa(ip_tuple) |> to_string()}
    else e ->
        error(e, "DNS resolution failed")
    end
  end
  def domain_ip_address(other), do: error(other, "Expected a hostname")

  def uri_host(%URI{host: nil} = _url), do: nil
  def uri_host(%URI{host: host} = _url), do: host
  def uri_host(url) when is_binary(url) do
    URI.parse(url) |> uri_host()
  end

    @doc """
  Apply a function from this module to a list of items concurrently.
  Returns a list of {:ok, final_url} or {:error, reason} tuples.

  ## Examples

      iex> apply_many(:unshorten, ["https://bit.ly/ex1", "https://bit.ly/ex2"])
      [
        {:ok, "https://example.com/long/url1"},
        {:ok, "https://example.com/long/url2"}
      ]

      iex> apply_many(:unshorten!, ["https://bit.ly/ex1", "https://bit.ly/ex2"])
      [
        "https://example.com/long/url1",
        "https://example.com/long/url2"
      ]

      iex> apply_many(:unfurl, ["https://bit.ly/ex1", "https://bit.ly/ex2"], skip_oembed_fetch: true)
      [
        {:ok, %{oembed: nil} = _meta},
        {:ok, %{oembed: nil} = _meta}
      ]

  """
  def apply_many(fun, items, extra_args \\ []) when is_list(items) do
    items
    |> Task.async_stream(__MODULE__, fun, [extra_args], timeout: 10_000)
    |> Enum.map(fn 
      {:ok, result} -> result 
      other -> error(other)
    end)
  end

end
