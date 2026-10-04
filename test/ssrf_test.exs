defmodule Unfurl.SSRFTest do
  @moduledoc """
  Unfurl fetches URLs that come from untrusted input (links in posts, and oEmbed endpoints named by the fetched page itself), so it must never reach a private or loopback address, on any hop.

  The sites here are real HTTP servers running on this machine (`Bypass`). A test that expects a fetch to be refused checks that the server never received it. Next to it, a test where the server's `host:port` is allowlisted checks that the same fetch does arrive, which shows it really would have been made. `ReqSSRF` has its own tests for which addresses count as private, so these only check that the check runs on each of Unfurl's requests, after every redirect, and that the allowlist doesn't switch it off for other hosts.
  """
  use ExUnit.Case, async: false

  alias Unfurl.Fetcher

  setup do
    {:ok, bypass: Bypass.open()}
  end

  defp url(bypass, path), do: "http://127.0.0.1:#{bypass.port}#{path}"

  defp allow!(bypasses),
    do: Process.put(:ssrf_allow_hosts, Enum.map(List.wrap(bypasses), &"127.0.0.1:#{&1.port}"))

  defp serve(bypass, path, body, opts \\ []) do
    test_pid = self()
    content_type = opts[:content_type] || "text/html"

    Bypass.stub(bypass, opts[:method] || "GET", path, fn conn ->
      send(test_pid, {:hit, bypass.port, path})

      conn
      |> Plug.Conn.put_resp_content_type(content_type, nil)
      |> Plug.Conn.resp(200, body)
    end)
  end

  defp refute_hit(bypass) do
    port = bypass.port
    refute_receive {:hit, ^port, _}, 300
  end

  test "an allowlisted host is fetched", %{bypass: bypass} do
    serve(bypass, "/page", "<html></html>")
    allow!(bypass)

    assert {:ok, "<html></html>", 200} = Fetcher.fetch(url(bypass, "/page"))
    assert_receive {:hit, _, "/page"}
  end

  test "a loopback address is never fetched", %{bypass: bypass} do
    serve(bypass, "/page", "<html></html>")

    refute match?({:ok, _, _}, Fetcher.fetch(url(bypass, "/page")))
    refute_hit(bypass)
  end

  test "the allowlist covers one port, not the whole host", %{bypass: bypass} do
    other = Bypass.open()
    serve(other, "/page", "<html></html>")
    allow!(bypass)

    refute match?({:ok, _, _}, Fetcher.fetch(url(other, "/page")))
    refute_hit(other)
  end

  test "a redirect from an allowlisted host to a private one is refused", %{bypass: bypass} do
    target = Bypass.open()
    serve(target, "/page", "<html></html>")

    Bypass.stub(bypass, "GET", "/go", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", url(target, "/page"))
      |> Plug.Conn.resp(302, "")
    end)

    allow!(bypass)

    refute match?({:ok, _, 200}, Fetcher.fetch(url(bypass, "/go")))
    refute_hit(target)
  end

  test "unshortening never sends a request to a loopback address", %{bypass: bypass} do
    serve(bypass, "/short", "", method: "HEAD")

    Unfurl.unshorten(url(bypass, "/short"))
    refute_hit(bypass)
  end

  test "an oEmbed endpoint named by the fetched page can't point the server at a private address",
       %{bypass: bypass} do
    target = Bypass.open()
    serve(target, "/oembed", ~s({"title": "internal"}), content_type: "application/json")

    html =
      ~s(<html><head><link rel="alternate" type="application/json+oembed" href="#{url(target, "/oembed")}"></head></html>)

    serve(bypass, "/page", html)
    allow!(bypass)

    # favicons are fetched by Faviconic, which has its own SSRF tests
    Unfurl.unfurl(url(bypass, "/page"), skip_favicon_fetch: true)

    assert_receive {:hit, _, "/page"}
    refute_hit(target)
  end
end
