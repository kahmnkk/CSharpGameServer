{{/*
Expand the name of the chart.
*/}}
{{- define "open-match-custom.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "open-match-custom.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "open-match-custom.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "open-match-custom.labels" -}}
helm.sh/chart: {{ include "open-match-custom.chart" . }}
{{ include "open-match-custom.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "open-match-custom.selectorLabels" -}}
app.kubernetes.io/name: {{ include "open-match-custom.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "open-match-custom.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "open-match-custom.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Open-match director
*/}}

{{- define "open-match-director.name" -}}
{{- default "open-match-director" .Values.director.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "open-match-director.labels" -}}
helm.sh/chart: {{ include "open-match-custom.chart" . }}
{{ include "open-match-director.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "open-match-director.selectorLabels" -}}
app.kubernetes.io/name: {{ include "open-match-director.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Open-match mmf
*/}}

{{- define "open-match-mmf.name" -}}
{{- default "open-match-mmf" .Values.mmf.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "open-match-mmf.labels" -}}
helm.sh/chart: {{ include "open-match-custom.chart" . }}
{{ include "open-match-mmf.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "open-match-mmf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "open-match-mmf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
