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
                propagatedBuildInputs = [ extraPerlPackages ];
                unpackPhase = "true";
                installPhase = ''
                  mkdir -p $out/bin
                  makeWrapper ${pkgs.parallel}/bin/parallel $out/bin/parallel \
                    --set PERL5LIB "${with pkgs.perlPackages; makeFullPerlPath (extraPerlPackages)}"
                '';
              };
                in {
            buildInputs =
              [ parallelWithPerlEnv ]
              ++ oldAttrs.buildInputs
              ++ [ (pkgs.python3.withPackages (ps: with ps; [ pandas pyarrow fastparquet openpyxl ])) ]
              ++ (with pkgs.rPackages; [
                            arrow assertthat
                            blandr broom
                            ComplexUpset cthist
                            DBI dotenv dplyr
                            forcats fs
                            ggplot2 ggsurvfit glue gtsummary
                            here
                            listr logger lubridate
                            pacman parsedate patchwork purrr
                            readr rlang RPostgres
                            scales stringr survival survminer
                            this_path tidyr tidyverse
                            vroom
                            yaml
                    ]);
            env = oldAttrs.env // {
              LC_ALL = "C";
            };
          });
      });
}
