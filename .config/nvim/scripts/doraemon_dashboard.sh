#!/bin/sh

set -eu

blue="$(printf '\033[38;2;36;156;255m')"
cyan="$(printf '\033[38;2;94;175;255m')"
white="$(printf '\033[38;2;245;249;252m')"
red="$(printf '\033[38;2;255;74;74m')"
yellow="$(printf '\033[38;2;255;214;90m')"
gray="$(printf '\033[38;2;125;132;145m')"
dark="$(printf '\033[38;2;44;48;56m')"
reset="$(printf '\033[0m')"

pixel() {
  case "$1" in
  B) printf '%s██' "$blue" ;;
  C) printf '%s██' "$cyan" ;;
  W) printf '%s██' "$white" ;;
  R) printf '%s██' "$red" ;;
  Y) printf '%s██' "$yellow" ;;
  G) printf '%s██' "$gray" ;;
  K) printf '%s██' "$dark" ;;
  *) printf '  ' ;;
  esac
}

draw_line() {
  line="$1"
  rest="$line"

  while [ -n "$rest" ]; do
    char=${rest%"${rest#?}"}
    pixel "$char"
    rest=${rest#?}
  done

  printf '%s\n' "$reset"
}

while IFS= read -r row; do
  draw_line "$row"
done <<'EOF'
............KKKKKKK..........
..........KKBBBBBBBKK........
........KKBBBBBBBBBBBKK......
.......KBBBBBBBBBBBBBBBK.....
......KBBBBBBBBBBBBBBBBBK....
.....KBBBBBBBBBBBBBBBBBBBK...
....KBBBBBBBBBBBBBBBBBBBBBK..
....KBBBWKKKBBBBBWKKKBBBBBK..
...KBBBWKKKKKBBB.KKKKKBBBBK..
...KBBB.KKKKKBBB.KKKKKBBBBK..
..KBBBB.KKKKKBBB.KKKKKBBBBBK.
..KBBBBB.KKKBBBBB.KKKBBBBBBK.
..KBBBBBBBBBBBBBBBBBBBBBBBBK.
..KBBBBBBBBBBBKBBBBBBBBBBBBK.
..KBBBBBBBBBBBRBBBBBBBBBBBBK.
..KBBBBBBBBBBBRBBBBBBBBBBBBK.
..KBBBBBBB..RRRRR..BBBBBBBBK.
...KBBBBB..RRRRRRR..BBBBBBK..
...KBBBB..RRRRRRRRR..BBBBBK..
....KBB..RRRRRRRRRRR..BBBK...
....KBB..RRRRRRRRRRR..BBBK...
.....KBB..RRRRRRRRR..BBBK....
......KKBB..RRRRR..BBKK......
........KKBBBBBBBBBKK........
..........KKKKKKKKK..........
...........RRRRRRR...........
...........RRRRRRR...........
............RYRYR............
.............YYY.............
EOF
