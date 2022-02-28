{ dappPkgs ? (
    import (fetchTarball "https://github.com/makerdao/makerpkgs/tarball/master") {}
  ).dappPkgsVersions.master-20220228
}: with dappPkgs;

mkShell {
  DAPP_SOLC = solc-static-versions.solc_0_8_11 + "/bin/solc-0.8.11";
  # No optimizations
  SOLC_FLAGS = "";
  buildInputs = [
    dapp
  ];

  shellHook = ''
    export NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    unset SSL_CERT_FILE
  '';
}
