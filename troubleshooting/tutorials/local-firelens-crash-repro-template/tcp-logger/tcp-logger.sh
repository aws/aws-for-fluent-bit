read_line_by_line() {
    while IFS= read -r line; do
        echo "$line" | nc 127.0.0.1 $2
        sleep 1
    done < "$1"
}

while true
do
    read_line_by_line $1 $2
    sleep 1
done
