## Parsers

### Vimeo
vimeo = File.read! "./test/fixtures/vimeo.html"

Benchee.run(%{
  "facebook" => fn -> Unfurl.Parser.Facebook.parse(vimeo) end,
  "twitter" => fn -> Unfurl.Parser.Twitter.parse(vimeo) end,
  "json_ld" => fn -> Unfurl.Parser.JsonLD.parse(vimeo) end,
  "html" => fn -> Unfurl.Parser.HTML.parse(vimeo) end
})
