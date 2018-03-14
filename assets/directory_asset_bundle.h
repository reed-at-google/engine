// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_ASSETS_DIRECTORY_ASSET_BUNDLE_H_
#define FLUTTER_ASSETS_DIRECTORY_ASSET_BUNDLE_H_

#include <string>
#include <vector>

#include "flutter/assets/asset_provider.h"
#include "lib/fxl/files/unique_fd.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/ref_counted.h"

namespace blink {

class DirectoryAssetBundle
    : public AssetProvider {
 public:
  explicit DirectoryAssetBundle(std::string directory);
  // Expects fd to be valid, otherwise the file descriptor is ignored.
  explicit DirectoryAssetBundle(fxl::UniqueFD fd);
  virtual ~DirectoryAssetBundle();

  virtual bool GetAsBuffer(const std::string& asset_name, std::vector<uint8_t>* data);

  std::string GetPathForAsset(const std::string& asset_name);

 private:
  const std::string directory_;
  fxl::UniqueFD fd_;

  FXL_DISALLOW_COPY_AND_ASSIGN(DirectoryAssetBundle);
};

}  // namespace blink

#endif  // FLUTTER_ASSETS_DIRECTORY_ASSET_BUNDLE_H_
