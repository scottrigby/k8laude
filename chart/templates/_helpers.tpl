{{/*
Workspace PVC name — matches the StatefulSet volumeClaimTemplate pattern.
Format: <volumeClaimTemplate.name>-<statefulset-name>-<ordinal>
*/}}
{{- define "k8laude.workspacePVC" -}}
workspace-{{.Release.Name}}-0
{{- end -}}
