#!/bin/bash
pushd ../runtime_test_packages/dependency
dart pub get
popd

pushd ../runtime_test_packages/application
dart pub get
popd
