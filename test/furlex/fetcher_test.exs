defmodule Unfurl.FetcherTest do
  use ExUnit.Case

  @moduletag :bypass

  alias Unfurl.Fetcher

  doctest Fetcher

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    # the test server is on loopback, which the SSRF guard otherwise refuses
    Process.put(:ssrf_allow_hosts, ["localhost:#{bypass.port}"])

    {:ok, bypass: bypass, url: url}
  end

  @tag :fixme
  test "fetches url", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, &handle/1)

    assert {:ok, body, 200} = Fetcher.fetch(url)
    assert body =~ "<title>Test HTML</title>"
  end

  def handle(conn) do
    body =
      [__DIR__ | ~w(.. fixtures test.html)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, body)
  end
end
