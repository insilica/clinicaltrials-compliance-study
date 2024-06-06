{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Exporter-Tiny";
  version = "1.006002";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TOBYINK/Exporter-Tiny-1.006002.tar.gz";
    hash = "sha256-byleLL/7HbwVvbna3DQWccHgzSvfLTErF1Jic8MiY40=";
  };
  meta = {
    homepage = "https://exportertiny.github.io/";
    description = "An exporter with the features of Sub::Exporter but only core dependencies";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
