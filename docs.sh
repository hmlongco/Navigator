swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation --target Navigator \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path Navigator \
    --output-path ./docs