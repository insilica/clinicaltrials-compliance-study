{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "MooX-Traits";
  version = "0.005";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TOBYINK/MooX-Traits-0.005.tar.gz";
    hash = "sha256-pk6NkHWA/pMBE5h8pAXb1rBbmElADS3JIPcFRTo90Hs=";
  };
  buildInputs = with perlPackages; [ TestRequires ];
  propagatedBuildInputs = with perlPackages; [ ExporterTiny ModuleRuntime RoleTiny ];
  meta = {
    homepage = "https://metacpan.org/release/MooX-Traits";
    description = "Automatically apply roles at object creation time";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
