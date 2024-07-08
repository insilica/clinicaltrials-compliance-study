{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
  pname = "Template-Toolkit-Simple";
  version = "0.31";
  src = fetchurl {
    url = "mirror://cpan/authors/id/I/IN/INGY/Template-Toolkit-Simple-0.31.tar.gz";
    hash = "sha256-WLzGkl2qeNgLQPQ22SGarc4gHc/rnHHpM7zaMMR9WXw=";
  };
  propagatedBuildInputs = with perlPackages; [ TemplateToolkit YAMLLibYAML ];
  meta = {
    homepage = "https://github.com/ingydotnet/template-toolkit-simple-pm";
    description = "A Simple Interface to Template Toolkit";
    license = with lib.licenses; [ artistic1 gpl1Plus ];
  };
  prePatch = ''
    sed -i '1s|#!/usr/bin/env perl|#!perl|' bin/tt-render
  '';
}
