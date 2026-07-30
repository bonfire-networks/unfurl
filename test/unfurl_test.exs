defmodule UnfurlTest do
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"

    oembed = Unfurl.Oembed
    oembed_config = Application.get_env(:unfurl, oembed, [])
    new_config = Keyword.put(oembed_config, :oembed_host, url)

    Application.put_env(:unfurl, oembed, new_config)

    on_exit(fn ->
      Application.put_env(:unfurl, oembed, oembed_config)

      :ok
    end)

    {:ok, bypass: bypass, url: url}
  end

  @tag :fixme
  test "unfurls a url", %{bypass: bypass, url: url} do
    Bypass.expect(bypass, &handle/1)

    assert {:ok, %{} = unfurl} =
             Unfurl.unfurl(url)
             |> IO.inspect()

    assert unfurl.status_code == 200
    assert unfurl.facebook["site_name"] == "Vimeo"
    assert unfurl.twitter["title"] == "FIDLAR - Cocaine (Feat. Nick Offerman)"
    assert Enum.at(unfurl.json_ld, 0)["@type"] == "VideoObject"
  end

  describe "maybe_favicon/2 with a URL that has no host" do
    # A URL pasted without a scheme (eg. `example.com/foo`) parses to `%URI{scheme: nil, host: nil}`. We must still be able to pick a favicon out of the page body, and above all must never hand `nil` to Faviconic: its `get_absolute_image_path/2` calls `URI.parse/1`, which raises a FunctionClauseError on nil, and that exception propagated all the way up to fail the caller's entire publish (see bonfire_files' URLPreviews act).
    test "finds an absolute favicon href without crashing", %{bypass: bypass, url: url} do
      icon_url = "#{url}/favicon.ico"

      Bypass.expect(bypass, "HEAD", "/favicon.ico", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("image/x-icon")
        |> Plug.Conn.resp(200, "")
      end)

      body =
        Floki.parse_document!(
          ~s(<html><head><link rel="icon" href="#{icon_url}"></head><body>hi</body></html>)
        )

      assert Unfurl.maybe_favicon("example.com/no-scheme", body) == icon_url
    end
  end

  def handle(%{request_path: "/providers.json"} = conn) do
    assert conn.method == "GET"

    providers =
      [__DIR__ | ~w(fixtures providers.json)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, providers)
  end

  def handle(conn) do
    html =
      [__DIR__ | ~w(fixtures vimeo.html)]
      |> Path.join()
      |> File.read!()

    Plug.Conn.resp(conn, 200, html)
  end
end
