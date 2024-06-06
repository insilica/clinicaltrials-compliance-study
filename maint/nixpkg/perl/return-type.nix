{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Return-Type";
  version = "0.007";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TOBYINK/Return-Type-0.007.tar.gz";
    hash = "sha256-Df+k46emOIXaAp2PBOedmdBOD0izuJDUUJ4gm7hl4bQ=";
  };
  buildInputs = with perlPackages; [ TestFatal ];
  propagatedBuildInputs = with perlPackages; [ TypeTiny ];
  meta = {
    homepage = "https://metacpan.org/release/Return-Type";
    description = "Specify a return type for a function (optionally with coercion)";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
