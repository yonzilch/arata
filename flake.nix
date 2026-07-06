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
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (
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
          bash.interactive = ''
            export PS1='\[\033[38;5;14m\][arata]\[\033[0m\]\$ '
          '';
          motd = ''
            {14}Arata devshell{reset}
            {244}Bun + Gleam development environment{reset}
            {14}Toolchain{reset}
              bun $(${pkgs.bun}/bin/bun --version)
              $(${pkgs.gleam}/bin/gleam --version)
            {14}Available Bun scripts{reset}
            $(${pkgs.bun}/bin/bun --silent --eval '
              const { scripts = {} } = await Bun.file("package.json").json();
              for (const [name, command] of Object.entries(scripts))
                console.log("  bun run " + name.padEnd(8) + " " + command);')
          '';
        };
      }
    );
}
