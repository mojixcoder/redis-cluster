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

{{- define "redis-cluster.extraEnvs" -}}
{{- range $i, $env := .extraEnvs }}
{{- if $i }}{{ printf "\n" }}{{ end -}}
- name: {{ $env.name }}
{{- if hasKey $env "value" }}
  value: {{ $env.value | quote }}
{{- else if hasKey $env "valueFrom" }}
  valueFrom: {{ toYaml $env.valueFrom | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate the auth / ACL values. Renders nothing; fails the release on invalid input.
*/}}
{{- define "redis-cluster.validateAuth" -}}
{{- if .Values.auth.enabled }}
{{- if and (not .Values.auth.password) (not .Values.auth.existingSecret.name) }}
{{- fail "auth.enabled is true but neither auth.password nor auth.existingSecret.name is set" }}
{{- end }}
{{- if and .Values.auth.existingSecret.name (not .Values.auth.existingSecret.key) }}
{{- fail "auth.existingSecret.key must be set when auth.existingSecret.name is set" }}
{{- end }}
{{- if .Values.auth.acl.enabled }}
{{- range .Values.auth.acl.users }}
{{- if not .name }}
{{- fail "every auth.acl.users entry must have a name" }}
{{- end }}
{{- if eq .name "default" }}
{{- fail "auth.acl.users must not contain the \"default\" user; configure it through auth.password or auth.existingSecret" }}
{{- end }}
{{- if not .rules }}
{{- fail (printf "auth.acl.users[%s].rules must be set" .name) }}
{{- end }}
{{- $hasSecret := and .existingSecret .existingSecret.name }}
{{- if and (not .password) (not $hasSecret) }}
{{- fail (printf "auth.acl.users[%s] needs either password or existingSecret.name" .name) }}
{{- end }}
{{- if and $hasSecret (not .existingSecret.key) }}
{{- fail (printf "auth.acl.users[%s].existingSecret.key must be set" .name) }}
{{- end }}
{{- end }}
{{- end }}
{{- else if .Values.auth.acl.enabled }}
{{- fail "auth.acl.enabled requires auth.enabled to be true" }}
{{- end }}
{{- end }}

{{/*
Name of the Secret the chart creates for inline passwords.
*/}}
{{- define "redis-cluster.authSecretDefaultName" -}}
{{ include "redis-cluster.name" . }}-auth
{{- end }}

{{/*
Returns a non-empty string when the chart has to create its own Secret,
i.e. at least one password is given inline instead of via an existing secret.
*/}}
{{- define "redis-cluster.createAuthSecret" -}}
{{- if not .Values.auth.existingSecret.name -}}
true
{{- else if .Values.auth.acl.enabled -}}
{{- range .Values.auth.acl.users -}}
{{- if not (and .existingSecret .existingSecret.name) -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Secret name / key holding the default user's password.
*/}}
{{- define "redis-cluster.authSecretName" -}}
{{- if .Values.auth.existingSecret.name }}
{{- .Values.auth.existingSecret.name }}
{{- else }}
{{- include "redis-cluster.authSecretDefaultName" . }}
{{- end }}
{{- end }}

{{- define "redis-cluster.authSecretKey" -}}
{{- if .Values.auth.existingSecret.name }}
{{- .Values.auth.existingSecret.key }}
{{- else }}
{{- "redis-password" }}
{{- end }}
{{- end }}

{{/*
Env var entry exposing the default user's password.
Usage: include "redis-cluster.passwordEnv" (dict "name" "REDIS_PASSWORD" "root" $)
*/}}
{{- define "redis-cluster.passwordEnv" -}}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "redis-cluster.authSecretName" .root }}
      key: {{ include "redis-cluster.authSecretKey" .root }}
{{- end }}

{{/*
Key inside the chart-managed Secret for an ACL user's password. Takes the user name.
*/}}
{{- define "redis-cluster.aclSecretKey" -}}
acl-{{ . }}-password
{{- end }}

{{/*
Env var name carrying an ACL user's password. Takes the user name.
*/}}
{{- define "redis-cluster.aclPasswordEnvName" -}}
REDIS_ACL_PASSWORD_{{ regexReplaceAll "[^A-Z0-9]" (upper .) "_" }}
{{- end }}

{{/*
Env var entries exposing every ACL user's password.
*/}}
{{- define "redis-cluster.aclPasswordEnvs" -}}
{{- range .Values.auth.acl.users }}
- name: {{ include "redis-cluster.aclPasswordEnvName" .name }}
  valueFrom:
    secretKeyRef:
      {{- if and .existingSecret .existingSecret.name }}
      name: {{ .existingSecret.name }}
      key: {{ .existingSecret.key }}
      {{- else }}
      name: {{ include "redis-cluster.authSecretDefaultName" $ }}
      key: {{ include "redis-cluster.aclSecretKey" .name }}
      {{- end }}
{{- end }}
{{- end }}
