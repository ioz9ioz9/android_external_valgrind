#!/bin/bash
# This scripts builds a self-contained executable file for Valgrind.
# Usage:
#   ./mk-self-contained-valgrind.sh /path/to/valgrind/installation tool_name resulting_binary [tool_flag]

# Take the valgrind installation from here:
IN_DIR="$1"
# Tool name:
TOOL="$2"
# Put the result here:
OUT="$3"
# If not empty, use as the --tool= value:
if [ "$4" == "" ]
then
  TOOLFLAG=$TOOL
else
  TOOLFLAG="$4"
fi

# The files/dirs to take:
IN_FILES="bin/valgrind lib/valgrind/vgpreload_core* lib/valgrind/*$TOOL* lib/valgrind/default.supp"
EXCLUDE_FILES="lib/valgrind/*$TOOL-debug*"

rm -f $OUT && touch $OUT && chmod +x $OUT || exit 1

# Create the header.
cat << 'EOF' >> $OUT || exit 1
#!/bin/bash
# This is a self-extracting executable of Valgrind.
# This file is autogenerated by mk-self-contained-valgrind.sh.

# We extract the temporary files to $VALGRIND_EXTRACT_DIR/valgrind.XXXXXX
VALGRIND_EXTRACT_DIR=${VALGRIND_EXTRACT_DIR:-/tmp}
EXTRACT_DIR="$(mktemp -d $VALGRIND_EXTRACT_DIR/valgrind.XXXXXX)"

cleanup() {
  rm -rf $EXTRACT_DIR
}
# We will cleanup on exit.
trap cleanup EXIT

mkdir -p $EXTRACT_DIR
chmod +rwx $EXTRACT_DIR
EOF
# end of header

# Create the self-extractor

# Create the runner
cat << 'EOF' >> $OUT || exit 1
# Extract:
sed '1,/^__COMPRESSED_DATA_BELOW__$/d' $0 | tar xz -C $EXTRACT_DIR

# Run
# echo Extracting Valgrind to $EXTRACT_DIR
export VALGRIND_LIB="$EXTRACT_DIR/lib/valgrind"
export VALGRIND_LIB_INNER="$EXTRACT_DIR/lib/valgrind"
EOF

echo "\$EXTRACT_DIR/bin/valgrind --tool=$TOOLFLAG \"\$@\"" >> $OUT || exit 1

cat << 'EOF' >> $OUT || exit 1
EXIT_STATUS=$?
cleanup # the trap above will handle the cleanup only if we are in bash 3.x
exit $EXIT_STATUS # make sure to return the exit code from valgrind.

__COMPRESSED_DATA_BELOW__
EOF

# Dump the compressed binary at the very end of the file.
(cd $IN_DIR && tar zcvh --exclude=$EXCLUDE_FILES $IN_FILES) >> $OUT || exit 1

echo "File $OUT successfully created"
