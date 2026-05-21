# rannar_jogot

Bangladeshi cooking video app built with Flutter.

## Feed Strategy

The app now supports two feed modes:

- Direct YouTube mode: the app fetches feeds straight from the YouTube Data API.
- Server-backed feed mode: the app reads prefetched JSON pages from a feed endpoint and only falls back to YouTube when a prefetched page chain ends with a `yt:` continuation token.

Latest videos, trending videos, and category pages use the server-backed path when `FEED_API_BASE_URL` is configured.

## Run The App

Direct YouTube mode:

```bash
flutter run
```

Server-backed feed mode:

```bash
flutter run --dart-define=FEED_API_BASE_URL=http://127.0.0.1:8080
```

## Generate Prefetched Feeds

This writes JSON pages into `prefetched_feeds/`.

```bash
dart run tool/prefetch_feeds.dart --output prefetched_feeds
```

To override the YouTube API key for the script:

```bash
dart run -DYOUTUBE_API_KEY=YOUR_API_KEY tool/prefetch_feeds.dart --output prefetched_feeds
```

## Serve Prefetched Feeds Locally

```bash
dart run tool/feed_server.dart --root prefetched_feeds --port 8080
```

Available endpoints:

- `/feeds/latest?page=1`
- `/feeds/trending?page=1`
- `/feeds/categories/fish?page=1`
- `/feeds/manifest`

## Scheduled Refresh

The workflow in `.github/workflows/prefetch_feeds.yml` refreshes the prefetched feed JSON every 6 hours and commits updated snapshots back to the repository.

Required GitHub secret:

- `YOUTUBE_API_KEY`

## Cost Reduction Changes

- Feed page size increased from 20 to 40 items.
- Client feed cache TTL increased from 60 minutes to 6 hours.
- Latest, trending, and category feeds can now be served from prefetched JSON instead of hitting YouTube on every user session.
- Search remains direct to YouTube, but feed browsing now avoids the largest repeated quota cost.
