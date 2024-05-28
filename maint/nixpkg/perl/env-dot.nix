## NOTE: Test2Suite added manually
{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Env-Dot";
  version = "0.013";
  src = fetchurl {
    url = "mirror://cpan/authors/id/M/MI/MIKKOI/Env-Dot-0.013.tar.gz";
    hash = "sha256-yLSM81lyAbivoHhjdB9w7IVxD3w68kbUX9VTXZO6VFM=";
  };
  buildInputs = with perlPackages; [ TestScript Test2Suite ];
  meta = {
    homepage = "https://metacpan.org/release/Env-Dot";
    description = "Read environment variables from .env file";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
}
