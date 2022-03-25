args=""

for plugin in ./.vscode/external-plugins/*; do
    for entry in "$plugin"/bin/*; do
        [[ $entry == *.so ]] && args="${args} -e ${entry}"
    done
done

echo "$args"
