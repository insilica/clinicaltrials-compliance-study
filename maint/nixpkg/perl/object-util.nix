{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Object-Util";
  version = "0.010";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TOBYINK/Object-Util-0.010.tar.gz";
    hash = "sha256-NYSS6dye8Wf9D+f/ejU/38JihGK1JvcFoR03lsgd5k0=";
  };
  buildInputs = with perlPackages; [ TestFatal TestRequires TestWarnings TestWithoutModule ];
  propagatedBuildInputs = with perlPackages; [ ModuleRuntime MooXTraits RoleTiny ];
  meta = {
    homepage = "https://metacpan.org/release/Object-Util";
    description = "A selection of utility methods that can be called on blessed objects";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
