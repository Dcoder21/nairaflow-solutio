{{/* Full image reference pinned by digest: registry/service@sha256:... */}}
{{- define "nairaflow.image" -}}
{{- $d := index .root.Values.images .name "digest" -}}
{{- if not $d }}{{ fail (printf "images.%s.digest is empty: pin every image by digest" .name) }}{{ end -}}
{{ .root.Values.registry }}/{{ .name }}@{{ $d }}
{{- end -}}

{{/* Pod-level hardening shared by every service */}}
{{- define "nairaflow.podSecurity" -}}
automountServiceAccountToken: false
imagePullSecrets:
  - name: {{ .Values.imagePullSecret }}
securityContext:
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }
{{- end -}}

{{/* Container-level hardening shared by every service */}}
{{- define "nairaflow.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: ["ALL"] }
{{- end -}}

{{/* Connection settings for api and worker, read from Secrets (never in Git) */}}
{{- define "nairaflow.backendEnv" -}}
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef: { name: {{ .Values.database.secretName }}, key: {{ .Values.database.secretKey }} }
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef: { name: {{ .Values.redis.secretName }}, key: {{ .Values.redis.secretKey }} }
  - name: REDIS_URL          # Kubernetes fills in $(REDIS_PASSWORD) from the line above
    value: "redis://:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}/0"
{{- end -}}
