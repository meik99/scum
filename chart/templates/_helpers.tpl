{{- /*
scum-chart generates the fullname based on fullnameOverride or the release name.
*/ -}}
{{- define "scum-chart.fullname" -}}
  {{- if .Values.global.fullnameOverride -}}
    {{- .Values.global.fullnameOverride | toString | quote -}}
  {{- else -}}
    {{- .Release.Name | toString | quote -}}
  {{- end -}}
{{- end -}}

{{- define "scum-chart.tags" -}}
app: scum
name: {{ include "scum-chart.fullname" . }}
{{- end -}}

{{- define "scum-chart.volumes" -}}
{{-  if .Values.persistence.hostPath.enabled -}}
- name: scumserver-data        
  hostPath:
    path: {{ .Values.persistence.hostPath.gamePath }}
{{- end -}}
{{- end -}}
