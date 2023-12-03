{{/*
Expand the name of the chart.
*/}}
{{- define "redis-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "redis-cluster.fullname" -}}
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
{{- define "redis-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "redis-cluster.labels" -}}
helm.sh/chart: {{ include "redis-cluster.chart" . }}
{{ include "redis-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "redis-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "redis-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "redis-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
replicaCount = master + master * replica
*/}}
{{- define "redis-cluster.replicaCount" -}}
{{- mul .Values.cluster.master .Values.cluster.replicas | add .Values.cluster.master }}
{{- end }}

{{- define "redis-cluster.addToConfig" -}}
{{- if eq (printf "%s" .value) "" }}
{{ .key }} ""
{{- else }}
{{ .key }} {{ .value }}
{{- end }}
{{- end }}

{{- define "redis-cluster.getHostPorts" -}}
{{- $hostPorts := "" -}}
{{- range $i := until (include "redis-cluster.replicaCount" . | int) }}
{{- $hostPorts = printf "%s%s-%d.%s-headless.%s.svc.cluster.local:%d " $hostPorts (include "redis-cluster.name" $) $i (include "redis-cluster.name" $) $.Release.Namespace ($.Values.redis.port | int) }}
{{- end }}
{{- $hostPorts }}
{{- end }}

{{- define "redis-cluster.getRedisAddrs" -}}
{{- $hostPorts := "" -}}
{{- range $i := until (include "redis-cluster.replicaCount" . | int) }}
{{- $hostPorts = printf "%sredis://%s-%d.%s-headless.%s.svc.cluster.local:%d " $hostPorts (include "redis-cluster.name" $) $i (include "redis-cluster.name" $) $.Release.Namespace ($.Values.redis.port | int) }}
{{- end }}
{{- $hostPorts | trimSuffix " " }}
{{- end }}
