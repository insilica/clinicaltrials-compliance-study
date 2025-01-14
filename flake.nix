{
  description = "ClinicalTrials Compliance Study";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    dev-shell.url = "github:biobricks-ai/dev-shell";
  };

  outputs = { self, nixpkgs, flake-utils, dev-shell }:
    {
      overlays.default = final: prev: {
        perlPackages = prev.perlPackages // {
          ExporterTiny  = final.callPackage ./maint/nixpkg/perl/exporter-tiny.nix {};
          TypeTiny      = final.callPackage ./maint/nixpkg/perl/type-tiny.nix {};
          PathTiny      = final.callPackage ./maint/nixpkg/perl/path-tiny.nix {};
          ReturnType    = final.callPackage ./maint/nixpkg/perl/return-type.nix {};
          EnvDot        = final.callPackage ./maint/nixpkg/perl/env-dot.nix {};
          failures      = final.callPackage ./maint/nixpkg/perl/failures.nix {};
          ObjectUtil    = final.callPackage ./maint/nixpkg/perl/object-util.nix {};
          MooXTraits    = final.callPackage ./maint/nixpkg/perl/moox-traits.nix {};

          TemplateToolkitSimple    = final.callPackage ./maint/nixpkg/perl/template-toolkit-simple.nix {};
        };

        rPackages = prev.rPackages // {
          arrow = final.callPackage ./maint/nixpkg/r/arrow.nix {};
        };
      };
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in {
        devShells.default = dev-shell.devShells.${system}.default.overrideAttrs
          (oldAttrs:
            let

              inherit (pkgs.perlPackages) makePerlPath;
              # See cpanfile
              extraPerlPackages = with pkgs.perlPackages; [
                    Moo
                    PathTiny
                    LWP
                    LWPProtocolhttps
                    CpanelJSONXS
                    ListUtilsBy
                    TypeTiny
                    ReturnType
                    CaptureTiny
                    EnvDot
                    failures
                    ObjectUtil
                    TemplateToolkitSimple
                ];
              parallelWithPerlEnv = pkgs.stdenv.mkDerivation {
                name = "parallel-with-perl-env";
                buildInputs = [ pkgs.parallel pkgs.makeWrapper ];
                propagatedBuildInputs = extraPerlPackages;
                unpackPhase = "true";
                installPhase = ''
                  mkdir -p $out/bin
                  makeWrapper ${pkgs.parallel}/bin/parallel $out/bin/parallel \
                    --set PERL5LIB "${with pkgs.perlPackages; makeFullPerlPath (extraPerlPackages)}"
                '';
              };

              # See analysis/ctgov.R
              extraRPackages = with pkgs.rPackages; [
                  arrow assertthat
                  blandr broom
                  ComplexUpset cowplot cthist
                  DBI dotenv dplyr
                  forcats fs
                  ggplot2 ggpubr ggsurvfit ggtext glue gridtext gtsummary
                  here
                  listr logger lubridate
                  pacman parsedate patchwork purrr
                  readr rlang RPostgres
                  scales stringr survival survminer svglite
                  testthat this_path tidyr tidyverse
                  vroom
                  yaml
                ];
              rEnv = pkgs.rWrapper.override {
                packages = extraRPackages;
              };

              # See requirements.txt
              python3PackageOverrides = pkgs.callPackage ./maint/nixpkg/python3/packages.nix { };
              python = pkgs.python3.override { packageOverrides = python3PackageOverrides; };
              extraPython3Packages = ps: with ps; [
                  numpy
                  pandas
                  scipy
                  pyarrow
                  fastparquet
                  openpyxl
                  bokeh
                  tqdm
                  iqplot
                  ipython
                  selenium
                ];
              python3Env = python.withPackages extraPython3Packages ;

                in {
            buildInputs =
              [
                parallelWithPerlEnv
                rEnv
                python3Env
                pkgs.chromium
                pkgs.chromedriver
              ]
	      ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.glibcLocales ])
	      ++ oldAttrs.buildInputs
              ;
            env = oldAttrs.env // {
	      LC_ALL = "C.UTF-8";
            };
          });
      });
}
