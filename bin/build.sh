#!/usr/bin/env bash

# Production build script for Render.com
# Inspired by https://github.com/zorn/mikezornek.com/blob/84fcf8b9015af33a82e8dcf90dbfb901a42da068/bin/build.sh

# set up an exit on error
set -o errexit

# Save the initial directory
ORIGINAL_DIR="$PWD"

# Install specific version of Hugo
HUGO_VERSION="0.148.1"  # Change this to your required version

# Create directory for Hugo download and installation
echo "Create Hugo directories ${HUGO_VERSION}..."
mkdir -p "${HOME}/bin"
mkdir -p /tmp/hugo
cd /tmp/hugo

# Download and install specific Hugo version
echo "Downloading Hugo ${HUGO_VERSION}..."
wget -q https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz
tar -xzf hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz

# Move Hugo to a directory you have permission for
mv hugo "${HOME}/bin/"

# Add the bin directory to PATH
export PATH="${HOME}/bin:${PATH}"

# Verify installation
echo "Building with Hugo ${HUGO_VERSION}..."
hugo version

# Return to project directory
cd "$ORIGINAL_DIR"

# Now you can add your Hugo build commands here
hugo --logLevel info --gc --minify

