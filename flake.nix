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
          TypeTiny = final.perlPackages.buildPerlPackage {
            pname = "Type-Tiny";
            version = "2.004000";
            src = final.fetchurl {
              url = "mirror://cpan/authors/id/T/TO/TOBYINK/Type-Tiny-2.004000.tar.gz";
              hash = "sha256-aX5/d17fyF9M8HeS0E/RmwnCUoX5j1k46O/E90UHoSg=";
            };
            propagatedBuildInputs = with final.perlPackages; [ ExporterTiny ];
            meta = {
              homepage = "https://typetiny.toby.ink/";
              description = "Tiny, yet Moo(se)-compatible type constraint";
              license = with final.lib.licenses; [ artistic1 gpl1Plus ];
            };
          };
          ExporterTiny = final.perlPackages.buildPerlPackage {
            pname = "Exporter-Tiny";
            version = "1.006002";
            src = final.fetchurl {
              url = "mirror://cpan/authors/id/T/TO/TOBYINK/Exporter-Tiny-1.006002.tar.gz";
              hash = "sha256-byleLL/7HbwVvbna3DQWccHgzSvfLTErF1Jic8MiY40=";
            };
            meta = {
              homepage = "https://exportertiny.github.io/";
              description = "An exporter with the features of Sub::Exporter but only core dependencies";
              license = with final.lib.licenses; [ artistic1 gpl1Plus ];
            };
          };
          PathTiny = final.perlPackages.buildPerlPackage {
            pname = "Path-Tiny";
            version = "0.144";
            src = final.fetchurl {
              url = "mirror://cpan/authors/id/D/DA/DAGOLDEN/Path-Tiny-0.144.tar.gz";
              hash = "sha256-9uoJTs6EXJUqAsJ4kzJXk1TejUEKcH+bcEW9JBIGSH0=";
            };
            meta = {
              homepage = "https://github.com/dagolden/Path-Tiny";
              description = "File path utility";
              license = final.lib.licenses.asl20;
            };
          };
          ReturnType = final.perlPackages.buildPerlPackage {
            pname = "Return-Type";
            version = "0.007";
            src = final.fetchurl {
              url = "mirror://cpan/authors/id/T/TO/TOBYINK/Return-Type-0.007.tar.gz";
              hash = "sha256-Df+k46emOIXaAp2PBOedmdBOD0izuJDUUJ4gm7hl4bQ=";
            };
            buildInputs = with final.perlPackages; [ TestFatal ];
            propagatedBuildInputs = with final.perlPackages; [ TypeTiny ];
            meta = {
              homepage = "https://metacpan.org/release/Return-Type";
              description = "Specify a return type for a function (optionally with coercion)";
              license = with final.lib.licenses; [ artistic1 gpl1Plus ];
            };
          };
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
               ]) ];
          });
      });
}
