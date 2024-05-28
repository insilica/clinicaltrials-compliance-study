{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Path-Tiny";
  version = "0.146";
  src = fetchurl {
    url = "mirror://cpan/authors/id/D/DA/DAGOLDEN/Path-Tiny-0.146.tar.gz";
    hash = "sha256-hh7wm8poJU6askM3u27J1YWTp5Lp1oon7mvsIVDwZ0E=";
  };
  meta = {
    homepage = "https://github.com/dagolden/Path-Tiny";
    description = "File path utility";
    license = lib.licenses.asl20;
  };
}
