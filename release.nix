# Adapted from https://nixos.wiki/wiki/Import_From_Derivation and
# https://nixos.org/guides/nix-pills/working-derivation.html
let
  pkgs = import <nixpkgs> {};

  hello-builder = pkgs.writeShellScriptBin "hello-builder" ''
    export PATH="$gnutar/bin:$gcc/bin:$gnumake/bin:$glib/bin:$coreutils/bin:$gawk/bin:$gzip/bin:$gnugrep/bin:$gnused/bin:$bintools/bin"
    tar -xzf $src
    cd hello-2.1.90
    mkdir $out
  '';

  # Create a derivation which, when built, writes some Nix code to
  # its $out path.
  nested-drv = pkgs.writeText "nested-drv" ''
    with (import <nixpkgs> {});
    builtins.derivation rec {
      name = "hello-2.1.90";
      builder = "''${pkgs.bash}/bin/bash" ;
      args = [ ${hello-builder}/bin/hello-builder ];
      inherit (pkgs) gnutar gzip gnumake gcc glib coreutils gawk gnused gnugrep;
      bintools = pkgs.binutils.bintools;

      # Toggle this to something else to break IFD.
      system = "x86_64-darwin";

      src = pkgs.fetchurl {
        url = "https://alpha.gnu.org/gnu/hello/hello-2.1.90.tar.gz";
        sha256 = "WRPsr3et/7+fZlifqPjOLSC2yDx2fkue0C4+NRzoqWc=";
      };
    }
  '';

  # Import the derivation. This forces `derivation-to-import` to become
  # a string. This is normal behavior for Nix and Nixpkgs. The specific
  # difference here is the evaluation itself requires the result to be
  # built during the evaluation in order to continue evaluating.
  nested = import nested-drv;

  outer-drv = pkgs.writeText "outer" ''
    with (import <nixpkgs> {});
    stdenv.mkDerivation {
      name = "outer";
      buildInputs = [ ${nested} ];
      installPhase = "mkdir $out";
      dontUnpack = true;
    }
  '';

  # Treat the imported-derivation variable as if we hadn't just created
  # its Nix expression inside this same evaluation.
  outer = import outer-drv;
in outer
