defmodule Unfurl.Tesla.Middleware.SSRF do
  @moduledoc """
  Refuses requests to private, loopback and other reserved addresses (Server-Side Request Forgery), using `ReqSSRF.check/2`. Plug it after the redirect middleware, so every hop is checked rather than just the URL first given.

  A `host:port` in the `:ssrf_allow_hosts` config (or set with `Process.put/2` in a test or caller) skips the check for that hop only, e.g. for another instance in a local multi-instance setup. Extra `ReqSSRF` options can be set in the `:ssrf` config.
  """
  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, _opts) do
    case check(env.url) do
      :ok -> Tesla.run(env, next)
      {:error, reason} -> {:error, {:ssrf, reason}}
    end
  end

  defp check(url) do
    %URI{host: host, port: port} = uri = URI.parse(url)

    if "#{host}:#{port}" in allow_hosts() do
      :ok
    else
      ReqSSRF.check(uri, Application.get_env(:unfurl, :ssrf, []))
    end
  end

  defp allow_hosts,
    do: ProcessTree.get(:ssrf_allow_hosts) || Application.get_env(:unfurl, :ssrf_allow_hosts, [])
end
