defmodule Unfurl.Fetcher do
  @moduledoc """
  A module for fetching body data for a given url
  """
  use Tesla

  plug Tesla.Middleware.Telemetry

  plug Unfurl.Tesla.Middleware.MaybeFollowRedirects, max_redirects: 5

  # after the redirects middleware, so every hop is checked
  plug Unfurl.Tesla.Middleware.SSRF

  import Untangle

  @doc """
  Fetches a url and extracts the body
  """
  @spec fetch(String.t(), List.t()) :: {:ok, String.t(), Integer.t()} | {:error, Atom.t()}
  def fetch(url, opts \\ [])

  def fetch(url, opts) when is_binary(url) do
    URI.parse(url)
    |> fetch(opts)
  end

  def fetch(%URI{} = url, opts) do
    case url do
      %URI{host: nil, path: nil} ->
        error(url, "Tried to fetch an invalid URL")

      %URI{scheme: "doi"} ->
        error(url, "Tried to fetch an invalid URL")

      %URI{scheme: nil, host: nil, path: host_detected_as_path} ->
        do_fetch("http://#{host_detected_as_path}", opts)

      %URI{} ->
        do_fetch(to_string(url), opts)
    end
  end

  @default_max_body_bytes 10 * 1024 * 1024

  @doc "The size over which a fetched page is refused: `config :unfurl, max_body_bytes: …` (10 MB by default)."
  def max_body_bytes, do: Application.get_env(:unfurl, :max_body_bytes, @default_max_body_bytes)

  defp do_fetch(url, opts \\ []) when is_binary(url) do
    max = max_body_bytes()

    case get(url, with_adapter_option(opts, :max_body_bytes, max)) do
      {:ok, %{body: body}} when is_binary(body) and byte_size(body) > max ->
        # for an adapter that cannot stop reading at the limit (`Bonfire.Common.HTTP.CappedFinch` can), so it has read the body whole
        error(max, "The response body is over the size limit")
        {:error, :body_too_large}

      {:ok, %{body: body, status: status_code}} ->
        {:ok, body, status_code}

      other ->
        other
    end
  rescue
    e in Tesla.Mock.Error ->
      error(e)

    e in ArgumentError ->
      error(e)

    e in CaseClauseError ->
      error(e)
  end

  # `:opts` are the per-request options Tesla hands to its middleware and adapter, where an adapter that supports a limit on the response size reads it
  defp with_adapter_option(opts, key, value) do
    Keyword.update(
      opts,
      :opts,
      [adapter: [{key, value}]],
      fn tesla_opts ->
        Keyword.update(tesla_opts, :adapter, [{key, value}], &Keyword.put(&1, key, value))
      end
    )
  end
end
