load("cache.star", "cache")
load("animation.star", "animation")
load("render.star", "render")
load("http.star", "http")
load("schema.star", "schema")
load("xpath.star", "xpath")

TITLE_LIMIT = 25
POSTER_HEIGHT = 32
POSTER_WIDTH = int(POSTER_HEIGHT / 1.5)
TEXT_WIDTH = 64 - POSTER_WIDTH - 2
DELAY = 40

def main(config):
  url = "https://letterboxd.com/%s/rss/" % config.get("username", "davidehrlich")

  # Fetch the RSS feed
  # TODO: Caching?
  resp = http.get(url)

  if resp.status_code != 200:
    fail("Failed to fetch RSS feed")
    return
  
  # Parse the RSS feed
  history = get_history(resp.body(), limit=3)

  return render.Root(
    delay=DELAY,
    child=render.Sequence(
      children=[
        movie(item) for item in history
      ]
    )
  )

def get_history(rss, limit=3):
  items = xpath.loads(rss).query_all_nodes("//rss[1]/channel[1]/item")[0:limit]

  history = []

  for item in items:
    title = item.query("//letterboxd:filmTitle/text()")

    if title != None:
      rating = item.query("//letterboxd:memberRating/text()")
      rewatch = (item.query("//letterboxd:rewatch/text()") == "Yes")

      description = item.query("//description/text()")
      image = xpath.loads(description).query("//p[1]/img/@src")

      if len(title) > TITLE_LIMIT:
        title = title[0:TITLE_LIMIT] + "..."

      history.append({
        "title": title,
        "rating": rating,
        "is_rewatch": rewatch,
        "poster": image
      })

  return history

def movie(movie):
  return animation.Transformation(
    duration=DELAY * 3,
    keyframes=[],
    wait_for_child=False,
    child=render.Row(
      expanded=True,
      main_align="space_between",
      children=[
        render.Image(src=image_data(movie["poster"]), height=POSTER_HEIGHT, width=POSTER_WIDTH),
        render.Padding(
          pad=(1,0,0,0),
          child=render.Column(
            expanded=True,
            main_align="space_evenly",
            children=[
              render.Marquee(width=TEXT_WIDTH, child=render.Text(movie["title"], font="6x13")),
              render.Marquee(width=TEXT_WIDTH, child=render.Text(movie["rating"], font="tom-thumb", color="#FFCE00")),
              render.Marquee(width=TEXT_WIDTH, child=render.Text("Rewatch" if movie["is_rewatch"] else "", font="tom-thumb", color="#AAA")),
            ]
          )
        )
      ]
    )
  )

def image_data(url):
  cached = cache.get(url)
  if cached:
      return cached

  response = http.get(url)

  if response.status_code != 200:
      fail("Image not found", url)

  data = response.body()
  cache.set(url, data, ttl_seconds=60 * 60 * 24)

  return data

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "username",
                name = "Username",
                desc = "Letterboxd username",
                icon = "user",
            )
        ]
    )
