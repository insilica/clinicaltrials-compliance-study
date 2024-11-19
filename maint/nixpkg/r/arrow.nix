{ rPackages, pkgs, fetchurl, lib }:

let
  name = "arrow";
  version = "17.0.0";
  sha256 = "10nagwqbz3f04r5yl2zqjwfc9ynyi2784gp10i5fflwagp0fcgkf";
  depends = with pkgs.rPackages; [R6 assertthat bit64 cpp11 glue purrr rlang tidyselect vctrs];
in
pkgs.rPackages.buildRPackage {
  name = "${name}-${version}";
  inherit version;
  src = fetchurl {
    inherit sha256;
    urls = [
      "mirror://cran/${name}_${version}.tar.gz"
      "mirror://cran/Archive/${name}/${name}_${version}.tar.gz"
    ];
  };
  env = {
    ARROW_USE_PKG_CONFIG = "FALSE";
    ARROW_DEPENDENCY_SOURCE = "AUTO";
    ARROW_R_DEV = "TRUE";
    EXTRA_CMAKE_FLAGS = "-DARROW_PARQUET=ON -DARROW_DATASET=ON -DARROW_JSON=ON -DARROW_WITH_SNAPPY=ON -DARROW_BOOST_USE_SHARED=ON -DARROW_SNAPPY_USE_SHARED=ON";
  };
  postPatch = ''
        patchShebangs configure
      '';
  propagatedBuildInputs = depends;
  nativeBuildInputs = with pkgs; [ cmake pkg-config boost thrift rapidjson snappy ] ++ depends;
}
