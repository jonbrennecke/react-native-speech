#!/usr/bin/env zsh
set -x

# run prettier to formta JS files
npm run format-prettier

# run clang-format to format Objective C files
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(cd "$dir/" 2> /dev/null && pwd -P)
format=$(brew --prefix llvm)/bin/clang-format

# .h files
for f in $project_dir/ios/Source/**/*.h
do
  $format -i $f
done

# .m files
for f in $project_dir/ios/Source/**/*.m
do
  $format -i $f
done

# run swiftformat to format Swift files
swiftformat $project_dir/ios --indent 2

set +x
