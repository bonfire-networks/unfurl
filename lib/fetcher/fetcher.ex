defmodule Unfurl.Fetcher do
  @moduledoc """
  A module for fetching body data for a given url
  """
  use Tesla

  plug Tesla.Middleware.Telemetry

  plug Unfurl.Tesla.Middleware.MaybeFollowRedirects, max_redirects: 5

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

  defp do_fetch(url, opts \\ []) when is_binary(url) do
    case get(url, opts) do
      {:ok, %{body: body, status: status_code}} -> {:ok, body, status_code}
      other -> other
    end
  rescue
    e in Tesla.Mock.Error ->
      error(e)

    e in ArgumentError ->
      error(e)

    e in CaseClauseError ->
      error(e)
  end
end
