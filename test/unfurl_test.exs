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
