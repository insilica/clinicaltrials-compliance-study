{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Type-Tiny";
  version = "2.004000";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TOBYINK/Type-Tiny-2.004000.tar.gz";
    hash = "sha256-aX5/d17fyF9M8HeS0E/RmwnCUoX5j1k46O/E90UHoSg=";
  };
  propagatedBuildInputs = with perlPackages; [ ExporterTiny ];
  meta = {
    homepage = "https://typetiny.toby.ink/";
    description = "Tiny, yet Moo(se)-compatible type constraint";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
