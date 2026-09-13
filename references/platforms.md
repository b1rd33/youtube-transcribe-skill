# Main Platform Support

This skill delegates media retrieval to yt-dlp. Test the exact URL with `yt-dlp --simulate --no-playlist "URL"` before a long transcription job: platform behavior can change.

## YouTube

- Individual videos and Shorts work with their normal public URLs.
- A playlist URL is treated as one item by default. Pass `--playlist` to process every item.
- Logged-in feeds, private videos, age-gated media, and account-only features require the user's own authorized cookies when yt-dlp supports access.

## Instagram

- Use an individual Reel, post, or Story URL.
- Public individual media is the intended workflow.
- Do not use a profile URL as a fallback: yt-dlp currently marks `instagram:user` as broken.

## X/Twitter

- Use a status URL, for example `https://x.com/ACCOUNT/status/POST_ID`. Equivalent `twitter.com` URLs are also accepted by yt-dlp.
- Media-bearing status posts and Spaces have dedicated yt-dlp extractors.
- If X requires authentication, pass `--cookies-from-browser BROWSER` only for the user's own authorized account.

## Captions

Captions are platform- and post-specific. The wrapper attempts creator-provided and automatic subtitles, then falls back to local FluidAudio transcription when captions are unavailable.
