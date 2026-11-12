# ---
# Module: Security & Pentest Tools
# Description: Penetration testing, web vulnerability scanning, fuzzing, and security audit toolsets
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Web Fuzzing & Content Discovery]
    gobuster       # High-speed directory, DNS, and vhost busting
    ffuf           # Fast web fuzzer written in Go
    feroxbuster    # Fast, recursive content discovery tool
    httpx          # Fast and multi-purpose HTTP probe toolkit
    subfinder      # Fast passive subdomain enumeration tool
    katana         # Next-generation web crawling and spidering engine

    # [Vulnerability Scanning & Exploitation]
    sqlmap         # Automatic SQL injection and database takeover tool
    commix         # Automated all-in-one command injection exploitation tool
    nuclei         # Fast and customizable vulnerability scanner based on simple YAML DSL
    nikto          # Web server vulnerability and misconfiguration scanner
    whatweb        # Next generation web scanner for tech stack & CMS identification
    wpscan         # WordPress security vulnerability scanner

    # [Interception & Proxy Analysis]
    burpsuite      # Industry standard web application security testing platform
    mitmproxy      # Interactive, SSL/TLS-capable intercepting proxy
    tshark         # Terminal-based network protocol analyzer (Wireshark-CLI)

    # [Network Discovery & Port Scanning]
    rustscan       # Fast port scanner with adaptive scripting
    masscan        # High-speed mass IP and port scanner

    # [Authentication & Password Cracking]
    thc-hydra      # Fast network login cracker supporting numerous protocols
    john           # John the Ripper password security auditing tool
    hashid         # Software to identify the different types of hashes

    # [Wordlists & Dictionaries]
    seclists       # Comprehensive security assessment wordlist collection
  ];

  # [Wordlists Integration]
  # Expose SecLists to ~/wordlists/seclists for convenient fuzzing and dictionary attacks
  home.file."wordlists/seclists".source = "${pkgs.seclists}/share/wordlists/seclists";

  # [Environment]
  home.sessionVariables = {
    WORDLISTS = "$HOME/wordlists/seclists";
    SECLISTS = "$HOME/wordlists/seclists";
  };
}
