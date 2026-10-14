#!/bin/zsh
# iOS 판의 랜드마크 영역을 안드로이드 판이 읽는 JSON으로 뽑는다. 랜드마크 그림이나 영역을 바꾸면 다시 돌린다.
set -e
cd "$(dirname "$0")/.."
OUT=android/app/src/main/assets/landmarks.json
mkdir -p "$(dirname "$OUT")"
BUILD=$(mktemp -d)
swiftc -O -parse-as-library -o "$BUILD/landmark_export" \
    Tools/landmark_export/main.swift SporeSweep/LandmarkView.swift SporeSweep/LandmarkTiers.swift 2>&1 | grep -E "error" || true
"$BUILD/landmark_export" "$OUT"
