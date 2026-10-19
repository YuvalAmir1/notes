# Notes: Emacs for notes in Typst, in Hebrew and English. notes-publish
# makes this repository from a configuration of its own; changes go there.
{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    helheim = {
      url = "github:helheim-emacs/helheim";
      flake = false;
    };
    hel = {
      url = "github:helheim-emacs/hel";
      flake = false;
    };
    hel-leader = {
      url = "github:helheim-emacs/hel-leader";
      flake = false;
    };
    hel-collection = {
      url = "github:helheim-emacs/hel-collection";
      flake = false;
    };
    dired-copy-paste = {
      url = "github:jsilve24/dired-copy-paste";
      flake = false;
    };
    tree-sitter-typst = {
      url = "github:Ziqi-Yang/tree-sitter-typst";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      packages = lib.genAttrs systems (
        system:
        (import ./notes/_friends.nix {
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          inherit lib inputs system;
        }).packages
      );
    };
}
