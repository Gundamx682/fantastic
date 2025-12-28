#!/bin/bash
PACKAGE_NAME="apk-downloader-deps.tar.gz"
echo "创建依赖包..."
tar -czf "$PACKAGE_NAME" offline-deps/
echo "依赖包创建完成: $PACKAGE_NAME"
echo "包大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
