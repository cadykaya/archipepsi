#!/bin/sh
# Impact Relay (Linux), heavy-hit mode: the Braided Lash on F.
cd "$(dirname "$0")" || exit 1
exec ./Archipepsi-Impact-Relay.x86_64 -- --heavy-hit
