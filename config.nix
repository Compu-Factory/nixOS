{ config, pkgs, ... }:

{
  # Basic system settings
  networking.hostName = "laravel-dev"; # Define your hostname
  time.timeZone = "UTC";               # Set your timezone

  # Bootloader configuration (adjust according to your system)
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for EFI systems

  # Enable SSH for remote access
  services.sshd.enable = true;

  # Create a shared user for RDP access
  users.users.rdpuser = {
    isNormalUser = true;
    extraGroups = [ "rdpusers" ];  # Create a group to restrict RDP access
    hashedPassword = "$6$rounds=656000$......"; # Replace with hashed password for shared RDP access
  };

  # General user configuration
  users.users.myuser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "nginx" ]; # Adjust groups as necessary
    hashedPassword = "$6$rounds=656000$......"; # Replace with hashed password
  };

  # Environment system packages
  environment.systemPackages = with pkgs; [
    php
    phpPackages.composer
    nginx
    mariadb
    mysql-workbench
    nodejs
    yarn
    git
    vim
    docker
    docker-compose
    xrdp                 # RDP server to allow remote connections
    vscode               # Visual Studio Code
    redis                # Redis for caching or queue management
    # Add any other tools you might need, like redis-cli or mailcatcher
  ];

  # Web server configuration (Nginx)
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."laravel.local" = {
      root = "/var/www/laravel/public";
      index = "index.php";
      serverAliases = [ "www.laravel.local" ];

      extraConfig = ''
        location ~ \.php$ {
          include ${pkgs.nginx}/conf/mime.types;
          fastcgi_pass unix:/run/phpfpm/php-fpm.sock;
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include fastcgi_params;
        }
      '';
    };
  };

  # PHP-FPM service configuration
  services.phpfpm = {
    enable = true;
    poolConfig = {
      www = {
        user = "nginx";
        group = "nginx";
        listen = "/run/phpfpm/php-fpm.sock";
        listenOwner = "nginx";
        listenGroup = "nginx";
        pm = "dynamic";
        pmMaxChildren = 10;
        pmStartServers = 2;
        pmMinSpareServers = 1;
        pmMaxSpareServers = 3;
        pmMaxRequests = 500;
      };
    };
  };

  # Database (MariaDB)
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialRootPassword = "yourpassword"; # Set a root password
  };

  # Docker service configuration (optional, useful for containerized development)
  virtualisation.docker.enable = true;

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 3306 3389 ]; # Added 3389 for RDP
  };

  # Enable XRDP for Remote Desktop access
  services.xrdp = {
    enable = true;
    defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session"; # Optionally, set a default desktop environment
  };

  # Configure PAM to allow RDP user group
  security.pam.services.xrdp-sesman = {
    text = ''
      auth required pam_succeed_if.so user ingroup rdpusers
    '';
  };

  # Enable and configure systemd services for Laravel Horizon and other jobs
  systemd.services.laravel-horizon = {
    description = "Laravel Horizon";
    serviceConfig = {
      ExecStart = "${pkgs.php}/bin/php /var/www/laravel/artisan horizon";
      Restart = "always";
      User = "nginx";
      WorkingDirectory = "/var/www/laravel";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Hostname resolution
  networking.extraHosts = ''
    127.0.0.1 laravel.local
  '';

  # Enable NFS if needed for sharing files with other systems or VM guests
  services.nfs.server.enable = true;

  # Optional: Configure Node.js and Yarn for frontend assets
  environment.systemPackages = with pkgs; [
    nodejs
    yarn
  ];

  # Optional: Enable Redis service if your Laravel application uses it
  services.redis.enable = true;

  # Enable automatic system updates
  services.nixos-upgrade.enable = true;
  services.nixos-upgrade.schedule = {
    interval = "daily";  # Options: "daily", "weekly", "monthly"
  };
  services.nixos-upgrade.email = "your-email@example.com"; # Optional: receive email notifications
}
