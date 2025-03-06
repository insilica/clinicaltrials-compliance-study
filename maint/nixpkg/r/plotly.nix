{ rPackages, pkgs, fetchurl, lib }:

let
  name = "plotly";
  version = "4.10.4";
  sha256 = "z6mVt+1V0xoZZwejrm6jUt2QfO8wWKO/GVb945Nm2Gc=";
  depends = with pkgs.rPackages; [base64enc crosstalk data_table digest dplyr ggplot2 htmltools htmlwidgets httr jsonlite lazyeval magrittr promises purrr RColorBrewer rlang scales tibble tidyr vctrs viridisLite];
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
  postPatch = ''
        patchShebangs configure
      '';
  propagatedBuildInputs = depends;
  nativeBuildInputs = depends;
}
