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
end
