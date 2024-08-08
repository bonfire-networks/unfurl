# Unfurl

Unfurl is a [structured data](https://moz.com/learn/seo/schema-structured-data) extraction tool written in Elixir.

It currently supports unfurling oEmbed, Open Graph (Facebook), Twitter Card, JSON-LD, rel-me, favicons, and plain ole' HTML `<meta />` data out of any url you supply.

## Installation

Add `:unfurl` to your list of dependencies in `mix.exs`:O

```elixir
def deps do
  [{:unfurl, "~> 0.6.0"}]
end
```

Then run `$ mix deps.get`. Also add `:unfurl` to your applications list:

```elixir
def application do
  [applications: [:unfurl]]
end
```

[Jason](http://github.com/michalmuskala/jason) is the default json library in Unfurl. You can however configure Unfurl to use another library. For example:

```elixir
config :unfurl, :json_library, YourLibraryOfChoice
```

## Usage

To unfurl a url, simply pass it to `Unfurl.unfurl/1`

```elixir
iex(1)> Unfurl.unfurl "https://www.youtube.com/watch?v=Gh6H7Md_L2k"
{:ok,
 %{
   other: %{
     "description" => "Ask This Old House host Kevin O’Connor visits Nick Offerman in Los Angeles to tour the comedian’s woodworking shop.SUBSCRIBE to This Old House: http://bit.ly...",
     "keywords" => "this old house, how-to, home improvement, Episode, TV Show, DIY, Ask This Old House, Nick Offerman, Kevin O'Connor, woodworking, wood shop, Los Angeles, Comedian, This Old House, Home Improvement, DIY Ideas, Renovation, Renovation Ideas, How To Fix, How To Install, How To Build, Kevin o’connor, kevin o'connor house, kevin o'connor this old house, kevin o'connor ask this old house, kevin o'connor interview",
     "theme-color" => "rgba(255, 255, 255, 0.98)",
     "title" => ["Touring Nick Offerman’s Wood Shop | Ask This Old House",
      "Touring Nick Offerman’s Wood Shop | Ask This Old House - YouTube"]
   },
   canonical_url: nil,
   facebook: %{
     "description" => "Ask This Old House host Kevin O’Connor visits Nick Offerman in Los Angeles to tour the comedian’s woodworking shop.SUBSCRIBE to This Old House: http://bit.ly...",
     "fb" => %{"app_id" => "87741124305"},
     "image" => %{"height" => "720", "width" => "1280"},
     "site_name" => "YouTube",
     "title" => "Touring Nick Offerman’s Wood Shop | Ask This Old House",
     "type" => "video.other",
     "url" => "https://www.youtube.com/watch?v=Gh6H7Md_L2k",
     "video" => %{
       "height" => "720",
       "secure_url" => "https://www.youtube.com/embed/Gh6H7Md_L2k",
       "type" => "text/html",
       "url" => "https://www.youtube.com/embed/Gh6H7Md_L2k",
       "width" => "1280"
     }
   },
   twitter: %{
     "app" => %{
       "id" => %{
         "googleplay" => "com.google.android.youtube",
         "ipad" => "544007664",
         "iphone" => "544007664"
       },
       "name" => %{
         "googleplay" => "YouTube",
         "ipad" => "YouTube",
         "iphone" => "YouTube"
       },
       "url" => %{
         "googleplay" => "https://www.youtube.com/watch?v=Gh6H7Md_L2k",
         "ipad" => "vnd.youtube://www.youtube.com/watch?v=Gh6H7Md_L2k&feature=applinks",
         "iphone" => "vnd.youtube://www.youtube.com/watch?v=Gh6H7Md_L2k&feature=applinks"
       }
     },
     "card" => "player",
     "description" => "Ask This Old House host Kevin O’Connor visits Nick Offerman in Los Angeles to tour the comedian’s woodworking shop.SUBSCRIBE to This Old House: http://bit.ly...",
     "image" => "https://i.ytimg.com/vi/Gh6H7Md_L2k/maxresdefault.jpg",
     "player" => %{"height" => "720", "width" => "1280"},
     "site" => "@youtube",
     "title" => "Touring Nick Offerman’s Wood Shop | Ask This Old House",
     "url" => "https://www.youtube.com/watch?v=Gh6H7Md_L2k"
   },
   oembed: %{
     "author_name" => "This Old House",
     "author_url" => "https://www.youtube.com/@thisoldhouse",
     "height" => 113,
     "html" => "<iframe width=\"200\" height=\"113\" src=\"https://www.youtube.com/embed/Gh6H7Md_L2k?feature=oembed\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen title=\"Touring Nick Offerman’s Wood Shop | Ask This Old House\"></iframe>",
     "provider_name" => "YouTube",
     "provider_url" => "https://www.youtube.com/",
     "thumbnail_height" => 360,
     "thumbnail_url" => "https://i.ytimg.com/vi/Gh6H7Md_L2k/hqdefault.jpg",
     "thumbnail_width" => 480,
     "title" => "Touring Nick Offerman’s Wood Shop | Ask This Old House",
     "type" => "video",
     "version" => "1.0",
     "width" => 200
   },
   json_ld: [
     %{
       "@context" => "http://schema.org",
       "@type" => "BreadcrumbList",
       "itemListElement" => [
         %{
           "@type" => "ListItem",
           "item" => %{
             "@id" => "http://www.youtube.com/@thisoldhouse",
             "name" => "This Old House"
           },
           "position" => 1
         }
       ]
     }
   ],
   status_code: 200,
   rel_me: nil,
   favicon: "https://www.youtube.com/s/desktop/ef8ce500/img/favicon_32x32.png"
 }}
```

## Configuration

Unfurl accepts a few optional configuration parameters.

You may configure additional tags to capture under the Facebook
OpenGraph and TwitterCard parsers.

```elixir
config :unfurl, Unfurl.Parser.Facebook,
  tags: ~w(my:custom:facebook:tag another:custom:facebook:tag)

config :unfurl, Unfurl.Parser.Twitter,
  tags: ~w(my:custom:twitter:tag)
```

You may also configure the depth of the resulting Unfurl map with a `:group_keys?` boolean.

```elixir
config :unfurl, group_keys?: true
```

If this option is set to false or unconfigured, Unfurl will return values mapped directly beneath OpenGraph and TwitterCard keys, i.e.

```elixir
%{twitter: %{
  "twitter:app:id:googleplay" => "com.google.android.youtube",
  "twitter:app:id:ipad"       => "544007664",
  "twitter:app:id:iphone"     => "544007664"
}}
```

If true, Unfurl will return values grouped into colon-delimited map structures, i.e.

```elixir
%{twitter: %{
  "twitter" => %{
    "app" => %{
      "id" => %{
        "googleplay" => "com.google.android.youtube",
        "ipad"       => "544007664",
        "iphone"     => "544007664"
      }
    }
  }
}}
```

## License

Copyright 2020 Bonfire Networks
Copyright 2017 Clayton Gentry (author of https://www.hex.pm/packages/furlex which Unfurl was forked from)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

```
http://www.apache.org/licenses/LICENSE-2.0`
```

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
