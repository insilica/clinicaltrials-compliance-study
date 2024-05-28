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
        };
      };
    } //
    flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      }; {
        devShells.default = dev-shell.devShells.${system}.default.overrideAttrs
          (oldAttrs: {
            buildInputs = oldAttrs.buildInputs
            ++ [ (python3.withPackages (ps: with ps; [ pandas pyarrow fastparquet openpyxl ])) ]
            ++ (with rPackages; [
                            arrow cthist DBI RPostgres dotenv dplyr readr vroom
                            ggplot2 ComplexUpset
                    ])
            ++ [ (with perlPackages; [
                    PathTiny
                    LWP
                    LWPProtocolhttps
                    CpanelJSONXS
                    ListUtilsBy
                    TypeTiny
                    ReturnType
                    CaptureTiny
                    EnvDot
               ]) ];
          });
      });
}
