#!/bin/sh

# bigclock.sh
# Usage:
#   ./bigclock.sh          # 24-hour clock
#   ./bigclock.sh --12     # 12-hour clock

case "${1:-}" in
    --12) time_format='%I:%M:%S %p' ;;
    *)    time_format='%H:%M:%S' ;;
esac

cleanup() {
    printf '\033[?25h\033[0m\033[2J\033[H'
    exit
}

trap cleanup INT TERM HUP EXIT

# Hide cursor and clear screen.
printf '\033[?25l\033[2J'

while :; do
    now=$(date +"$time_format")
    cols=$(tput cols 2>/dev/null || printf '80')
    rows=$(tput lines 2>/dev/null || printf '24')

    awk \
        -v text="$now" \
        -v cols="$cols" \
        -v rows="$rows" '
    BEGIN {
        # Five-column, seven-row digit glyphs.
        glyph["0"] = "11111 10001 10011 10101 11001 10001 11111"
        glyph["1"] = "00100 01100 00100 00100 00100 00100 01110"
        glyph["2"] = "11111 00001 00001 11111 10000 10000 11111"
        glyph["3"] = "11111 00001 00001 01111 00001 00001 11111"
        glyph["4"] = "10001 10001 10001 11111 00001 00001 00001"
        glyph["5"] = "11111 10000 10000 11111 00001 00001 11111"
        glyph["6"] = "11111 10000 10000 11111 10001 10001 11111"
        glyph["7"] = "11111 00001 00010 00100 01000 01000 01000"
        glyph["8"] = "11111 10001 10001 11111 10001 10001 11111"
        glyph["9"] = "11111 10001 10001 11111 00001 00001 11111"

        glyph[":"] = "0 1 1 0 1 1 0"
        glyph[" "] = "000 000 000 000 000 000 000"

        glyph["A"] = "01110 10001 10001 11111 10001 10001 10001"
        glyph["P"] = "11110 10001 10001 11110 10000 10000 10000"
        glyph["M"] = "10001 11011 10101 10101 10001 10001 10001"

        # Determine the unscaled width.
        base_width = 0
        for (i = 1; i <= length(text); i++) {
            ch = substr(text, i, 1)
            split(glyph[ch], lines, " ")
            base_width += length(lines[1])

            if (i < length(text))
                base_width++
        }

        # Each lit pixel is twice as wide to compensate for terminal
        # characters being taller than they are wide.
        sx = int(cols / (base_width * 2))
        sy = int((rows - 1) / 7)

        if (sx < 1) sx = 1
        if (sy < 1) sy = 1

        rendered_width = base_width * sx * 2
        rendered_height = 7 * sy

        left = int((cols - rendered_width) / 2)
        top  = int((rows - rendered_height) / 2)

        if (left < 0) left = 0
        if (top < 0) top = 0

        # Return cursor home without clearing to reduce flicker.
        printf "\033[H"

        for (n = 0; n < top; n++)
            printf "\033[K\n"

        for (row = 1; row <= 7; row++) {
            output = sprintf("%*s", left, "")

            for (i = 1; i <= length(text); i++) {
                ch = substr(text, i, 1)
                split(glyph[ch], lines, " ")
                pixels = lines[row]

                for (p = 1; p <= length(pixels); p++) {
                    pixel = substr(pixels, p, 1)
                    block = pixel == "1" ? "██" : "  "

                    for (x = 1; x <= sx; x++)
                        output = output block
                }

                if (i < length(text)) {
                    for (x = 1; x <= sx; x++)
                        output = output "  "
                }
            }

            for (y = 1; y <= sy; y++)
                printf "%s\033[K\n", output
        }

        printf "\033[J"
        fflush()
    }'

    sleep 1
done

