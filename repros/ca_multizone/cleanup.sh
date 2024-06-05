sh env.sh
set -x
az group delete -n "$LAB_RG" --yes
rm env.sh access-instructions.md kubeconfig
