{ lib
, pkgs
, fetchPypi
 }:

self: super: {
  iqplot = super.buildPythonPackage rec {
    pname = "iqplot";
    version = "0.3.7";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-jlY0u5+Iw0hXkNDcaVMEPnEV2xzvy968EW0QC954KeA=";
    };

    build-system = [
      super.setuptools-scm
    ];

    propagatedBuildInputs = [
      super.numpy
      super.xarray
      super.pandas
      super.bokeh
      super.colorcet
    ];

    nativeCheckInputs = [];
  };
}
