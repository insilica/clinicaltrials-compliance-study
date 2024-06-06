{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "failures";
  version = "0.004";
  src = fetchurl {
    url = "mirror://cpan/authors/id/D/DA/DAGOLDEN/failures-0.004.tar.gz";
    hash = "sha256-/SynAkAvIvUYWxKUK1B5v5WtIc3juXp88uGRkUdGMnA=";
  };
  propagatedBuildInputs = with perlPackages; [ ClassTiny ];
  meta = {
    homepage = "https://github.com/dagolden/failures";
    description = "Minimalist exception hierarchy generator";
    license = lib.licenses.asl20;
  };
}
