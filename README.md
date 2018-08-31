# Nagios plugin to check if Nginx upstreams are available

+ August 31st: initial commit

```
Usage: check_nginx_upstreams.sh [ -i <ignore pattern> ] [ -w <warn threshold> ] [ -w <critical threshold> ] [ -t <seconds> ]
-i: ignore a backend (supports regular expression)
-w: set warn threshold (default: warning if availability is below or equal 75(%))
-c: set critical threshold (default: critical if availability is below or equal 50(%))
-t: amount of seconds to wait for a backend to respond
-d: change configuration directory (default: /etc/nginx/sites-enabled)
```
