{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    flutter
    sqlite
    clang
    cmake
    ninja
    pkg-config
    gtk3
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "ClaimMitra development environment loaded."
  '';
}