FROM amazonlinux
ADD example.log /example.log
CMD exec /bin/sh -c  "trap : TERM INT; while true; do cat /example.log; sleep 1; done;"
