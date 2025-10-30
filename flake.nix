# Author: phga <phga@posteo.de>
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs =
    { self
    , nixpkgs
    ,
    } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;
      pianoteq_versions = builtins.listToAttrs (map
        (version: {
          name = "pianoteq_v${version.major}";
          value = version;
        })
        ((import ./versions.nix).versions))
      ;
      pianoteqs_drvs = lib.attrsets.mapAttrs (name: value: (import ./mkpianoteq.nix value)) pianoteq_versions;
      pianoteqs = lib.attrsets.mapAttrs (name: drv: pkgs.callPackage drv { }) pianoteqs_drvs;
    in
    {
      packages.${system} = pianoteqs;
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.python314
          pkgs.uv
        ];

        shellHook = ''
          unset PYTHONPATH
          #uv sync
          #. .venv/bin/activate
        '';
      };
    };
}
