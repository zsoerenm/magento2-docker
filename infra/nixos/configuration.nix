# Base NixOS configuration for Magento 2 Docker servers
# Applied to both staging and production via nixos-rebuild --target-host
{ config, pkgs, lib, ... }:

let
  hasRunnerToken = builtins.pathExists /etc/nixos/runner-token;
  hasRunnerRepo = builtins.pathExists /etc/nixos/runner-repo;
  repoUrl = if hasRunnerRepo
    then lib.strings.trim (builtins.readFile /etc/nixos/runner-repo)
    else "";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # System
  system.stateVersion = "24.11";
  time.timeZone = "Europe/Berlin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Networking & Firewall
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  # SSH hardening
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    docker-compose
    git
    htop
    curl
    jq
    vim
  ];

  # Root SSH access for deployment
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOlKGC7jJkpzJkRSvpEUIgp9iAD6RCJTgfaPezrQvli6 albert@openclaw"
    # Will be populated by the infra workflow
  ];

  # Deploy user
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      # Will be populated by the infra workflow
    ];
  };

  # GitHub Actions self-hosted runner
  # Token and repo URL are written to /etc/nixos/ by the infra workflow
  # Runner is only enabled when both files exist
  services.github-runners.staging = lib.mkIf (hasRunnerToken && repoUrl != "") {
    enable = true;
    url = repoUrl;
    tokenFile = "/etc/nixos/runner-token";
    name = config.networking.hostName;
    extraLabels = [ "staging" ];
    replace = true;
    # NixOS 24.11 ships runner 2.325.0 which GitHub deprecated
    # Use nixos-unstable channel for newer runner (add channel on server first)
    package = (import <nixos-unstable> { system = "x86_64-linux"; }).github-runner;
    extraPackages = with pkgs; [
      docker
      docker-compose
      git
      curl
      jq
      openssh
      rsync
      gnutar
      gzip
      python3
      bash
      coreutils
      findutils
      gnused
      gnugrep
      gawk
    ];
    serviceOverrides = {
      SupplementaryGroups = [ "docker" ];
      ReadWritePaths = [ "/opt/magento2" ];
    };
  };

  # Create deploy directory before runner starts (ReadWritePaths requires it to exist)
  systemd.tmpfiles.rules = [
    "d /opt/magento2 0755 root root -"
  ];

  # Swap (useful for Magento's memory-hungry processes)
  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4 GB
  }];

  # Kernel tuning for OpenSearch
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
    "vm.swappiness" = 10;
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # Don't reboot automatically on production
    dates = "04:00";
  };
}
