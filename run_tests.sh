#!/bin/bash -e
docker run --rm -it -v "$(pwd)":/ivy_all unifyai/ivy-all:latest python3 -m pytest all_tests_n_demos/
