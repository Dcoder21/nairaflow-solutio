# Sealed secrets (Day 11C)

Files here are **encrypted** with the cluster's Sealed Secrets public key. They are safe in Git:
only the sealed-secrets controller inside the cluster can decrypt them.

Make or update one (never commit the plain Secret):

    kubectl create secret generic NAME -n nairaflow-dev --from-literal=key="$(openssl rand -hex 24)" \
      --dry-run=client -o json \
      | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system -o yaml \
      > deploy/secrets/NAME.sealed.yaml

The controller's private key is backed up OUTSIDE the repo (nairaflow-lab). Lose it and these files can't be opened.
