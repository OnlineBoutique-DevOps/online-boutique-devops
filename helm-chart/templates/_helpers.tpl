{{/*
Expand the name of the chart.
*/}}
{{- define "onlineboutique.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "onlineboutique.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "onlineboutique.labels" -}}
helm.sh/chart: {{ include "onlineboutique.chart" . }}
{{ include "onlineboutique.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "onlineboutique.selectorLabels" -}}
app.kubernetes.io/name: {{ include "onlineboutique.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}