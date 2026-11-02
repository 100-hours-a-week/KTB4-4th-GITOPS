{{- define "needu.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "needu.labels" -}}
app.kubernetes.io/name: {{ include "needu.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: needu
{{- end -}}

{{- define "needu.image" -}}
{{- $repository := required "image.repository is required when enabled=true" .Values.image.repository -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository (required "image.tag or image.digest is required when enabled=true" .Values.image.tag) -}}
{{- end -}}
{{- end -}}
