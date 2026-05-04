#!/usr/bin/env python3
import sys
import random
from arts import arts

COLORS = {
    "D": "\033[38;2;15;80;180m",
    "B": "\033[38;2;36;156;255m",
    "L": "\033[38;2;180;220;255m",
    "C": "\033[38;2;94;175;255m",
    "W": "\033[38;2;245;249;252m",
    "R": "\033[38;2;255;74;74m",
    "Y": "\033[38;2;255;214;90m",
    "G": "\033[38;2;125;132;145m",
    "K": "\033[38;2;44;48;56m",
    "M": "\033[38;2;46;204;113m",
}
RESET = "\033[0m"


def draw_art(art_data):
    lines = [line for line in art_data.strip().split("\n") if line]

    for line in lines:
        line = line.strip()
        for char in line:
            if char in COLORS:
                sys.stdout.write(f"{COLORS[char]}██")
            else:
                sys.stdout.write("  ")
        sys.stdout.write(f"{RESET}\n")

    sys.stdout.flush()


if __name__ == "__main__":
    chosen_art = random.choice(arts)
    draw_art(chosen_art)
