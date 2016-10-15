#!/bin/sh
# shellcheck shell=dash

#
# Sends email to the given SMTP server via Netcat.
#
# Usage:
# echo 'Text' | ./mail.sh [-h host] [-p port] [-f from] [-t to] [-s subject]
#
# Copyright 2016, Sebastian Tschan
# https://blueimp.net
#
# Licensed under the MIT license:
# https://opensource.org/licenses/MIT
#

set -e

# Default settings:
HOST=localhost
PORT=25
USER=${USER:-user}
# shellcheck disable=SC2169
HOSTNAME=${HOSTNAME:-localhost}
FROM="$USER <$USER@$HOSTNAME>"
TO='test <test@example.org>'
SUBJECT=Test

NEWLINE='
'

print_usage() {
  echo \
    "Usage: echo 'Text' | $0 [-h host] [-p port] [-f from] [-t to] [-s subject]"
}

# Prints the given error and optionally a usage message and exits:
error_exit() {
  echo "Error: $1" >&2
  if [ ! -z "$2" ]; then
    print_usage >&2
  fi
  exit 1
}

# Adds brackets around the last word in the given address, trims whitespace:
normalize_address() {
  local address
  address=$(echo "$1" | awk '{$1=$1};1')
  if [ "${address%>}" = "$address" ]; then
    echo "$address" | sed 's/[^ ]*$/<&>/'
  else
    echo "$address"
  fi
}

# Checks if the email is surrounded by brackets, contains an "@" character
# and does not contain any spaces:
validate_address() {
  if [ "${2%<*@*>}" = "$2" ] || [ "${2#*,}" != "$2" ] \
      || [ "${2%@* *>}" != "$2" ] || [ "${2%<* *@*>}" != "$2" ]; then
    error_exit "Invalid '$1' email address: $2"
  fi
}

is_printable_ascii() {
  (LC_CTYPE=C; case "$1" in *[![:print:]]*) return 1;; esac)
}

# Encodes the given string according to RFC 1522:
# https://tools.ietf.org/html/rfc1522
rfc1342_encode() {
  if is_printable_ascii "$1"; then
    printf %s "$1"
  else
    printf '=?utf-8?B?%s?=' "$(printf %s "$1" | base64)"
  fi
}

encode_address() {
  local email="<${1##*<}"
  if [ "$email" != "$1" ]; then
    local name="${1%<*}"
    # Remove any trailing space as we add it again in the next line:
    name="${name% }"
    echo "$(rfc1342_encode "$name") $email"
  else
    echo "$1"
  fi
}

parse_recipients() {
  local addresses
  local address
  local output
  local recipients
  addresses=$(echo "$TO" | tr ',' '\n')
  IFS="$NEWLINE"
  for address in $addresses; do
    address=$(normalize_address "$address")
    validate_address to "$address"
    output="$output, $(encode_address "$address")"
    recipients="$recipients$NEWLINE<${address#*<}"
  done
  unset IFS
  # Remove the first commma and space from the address list:
  TO="$(echo "$output" | cut -c 3-)"
  # Remove leading blank line from the recipients list and add header prefixes:
  RECIPIENTS_HEADERS="$(echo "$recipients" | sed '/./,$!d; s/^/RCPT TO: /')"
}

parse_sender() {
  FROM="$(normalize_address "$FROM")"
  validate_address from "$FROM"
  FROM="$(encode_address "$FROM")"
  SENDER_HEADER="MAIL FROM: <${FROM#*<}"
}

while getopts ':h:p:f:t:s:' OPT; do
  case "$OPT" in
  h)
    HOST="$OPTARG"
    ;;
  p)
    PORT="$OPTARG"
    ;;
  f)
    FROM="$OPTARG"
    ;;
  t)
    TO="$OPTARG"
    ;;
  s)
    SUBJECT="$OPTARG"
    ;;
  \?)
    error_exit "Invalid option: -$OPTARG" true
    ;;
  :)
    error_exit "Option -$OPTARG requires an argument." true
    ;;
  esac
done

parse_recipients
parse_sender

SUBJECT="$(rfc1342_encode "$SUBJECT")"

TEXT=
while read -r LINE; do
  [ "$LINE" = '.' ] && break
  TEXT="$TEXT$LINE$NEWLINE"
done

DATE=$(date '+%a, %d %b %Y %H:%M:%S %z')

MAIL='HELO '"$HOSTNAME"'
'"$SENDER_HEADER"'
'"$RECIPIENTS_HEADERS"'
DATA

Content-Type: text/plain; charset=utf-8
Date: '"$DATE"'
From: '"$FROM"'
To: '"$TO"'
Subject: '"$SUBJECT"'

'"$TEXT"'
.
QUIT'

echo "$MAIL" | awk '{printf "%s\r\n", $0}' | nc "$HOST" "$PORT"
