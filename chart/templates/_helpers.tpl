{{/*
Workspace PVC name — matches the StatefulSet volumeClaimTemplate pattern.
Format: <volumeClaimTemplate.name>-<statefulset-name>-<ordinal>
*/}}
{{- define "k8laude.workspacePVC" -}}
workspace-{{.Release.Name}}-0
{{- end -}}

{{/*
TLS suffix — appends "-staging" when using Let's Encrypt staging server.
Allows staging and production resources to coexist.
*/}}
{{- define "k8laude.tlsSuffix" -}}
{{- if .Values.ingress.tls.acme.staging -}}-staging{{- end -}}
{{- end -}}
