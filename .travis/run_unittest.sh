#!/usr/bin/env bash
set -ex

if [ -f "lib/.cached_commit" ]; then
  cachedLibCommit=$(cat lib/.cached_commit)
fi

cudaFileChanged=false
if [ ! -z "${cachedLibCommit}" ]; then
  changefiles=$(git diff "${cachedLibCommit}" --name-only)
  for file in ${changefiles}
  do
    ext="${file##*.}"
    if [ "$ext" == "cu" ] || [ "$ext" == "h" ]; then
      echo "c file changed from cacheLibCommit, need to rebuild lib"
      cudaFileChanged=true	
      break
    fi
  done
else
  cudaFileChanged=true
fi

if [ "${cudaFileChanged}" == "true" ]; then
  # clean up lib and cuda test when cuda file change found
	make clean
  make clean-cuda-test
else
  # touch files in lib and gtest to update the timestamp so that make will not treat lib objects as outdated 
	find lib -type f  -exec touch {} +
	find gtest -type f  -exec touch {} +
fi

# run test-cuda in host mode
make test-cuda -j

# build binary
make ares -j

# run test
ginkgo -r

echo "mode: atomic" > coverage.out
for file in $(find . -name "*.coverprofile" ! \( -name "coverage.out"  -o -name "expr.coverprofile" \) ); do \
    cat $file | grep -v "mode: atomic" | awk 's=index($0,"ares")+length("ares") { print "." substr($0, s)}' >> coverage.out ; \
    #rm $file ; \
done
gocov convert coverage.out | gocov-xml > coverage.xml
