{
  description = "Bun and Gleam development environment for Arata";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      devshell,
      ...
    }:
    flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ devshell.overlays.default ];
          };
        in
        {
          devShells.default = pkgs.devshell.mkShell {
            name = "arata";

            packages = with pkgs; [
              bun
              gleam
            ];

            motd = ''
              {202}Arata devshell{reset}
              {244}Bun + Gleam development environment{reset}

              {14}Toolchain{reset}
                bun     $(${pkgs.bun}/bin/bun --version)
                gleam   $(${pkgs.gleam}/bin/gleam --version | head -n 1)

              {14}Hint{reset}
                Run {10}menu{reset} to see available project commands.

              $(type -p menu &>/dev/null && menu)
            '';

            commands = [
              {
                name = "build";
                category = "project";
                help = "Build the project";
                command = "bun run build";
              }
              {
                name = "dev";
                category = "project";
                help = "Start development server";
                command = "bun run dev";
              }
              {
                name = "check";
                category = "quality";
                help = "Run formatting, tests, and build";
                command = ''
                  if [ -d test ]; then
                    gleam format --check src test
                  else
                    gleam format --check src
                  fi

                  gleam test
                  bun run build
                '';
              }
              {
                name = "fmt";
                category = "quality";
                help = "Format Gleam source files";
                command = ''
                  if [ -d test ]; then
                    gleam format src test
                  else
                    gleam format src
                  fi
                '';
              }
              {
                name = "test";
                category = "quality";
                help = "Run Gleam tests";
                command = "gleam test";
              }
            ];
          };
        }
      );
}
