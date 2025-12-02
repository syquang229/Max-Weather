{{/*
Expand the name of the chart.
*/}}
{{- define "max-weather.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "max-weather.fullname" -}}
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
{{- define "max-weather.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "max-weather.labels" -}}
helm.sh/chart: {{ include "max-weather.chart" . }}
{{ include "max-weather.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "max-weather.selectorLabels" -}}
app.kubernetes.io/name: {{ include "max-weather.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "max-weather.serviceAccountName" -}}
{{- if .Values.weatherApi.serviceAccount.create }}
{{- default "weather-api" .Values.weatherApi.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.weatherApi.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the Docker image repository URL
*/}}
{{- define "max-weather.image" -}}
{{- if .Values.weatherApi.image.registry }}
{{- printf "%s/%s:%s" .Values.weatherApi.image.registry .Values.weatherApi.image.repository .Values.weatherApi.image.tag }}
{{- else }}
{{- printf "%s.dkr.ecr.%s.amazonaws.com/%s:%s" .Values.global.aws.accountId .Values.global.aws.region .Values.weatherApi.image.repository .Values.weatherApi.image.tag }}
{{- end }}
{{- end }}

{{/*
Namespace helper
*/}}
{{- define "max-weather.namespace" -}}
{{- default "default" .Values.namespaceOverride }}
{{- end }}

{{/*
Ingress Controller Namespace
*/}}
{{- define "max-weather.ingressController.namespace" -}}
{{- default "ingress-nginx" .Values.ingressController.namespace }}
{{- end }}

{{/*
Fluent Bit Namespace
*/}}
{{- define "max-weather.fluentBit.namespace" -}}
{{- default "amazon-cloudwatch" .Values.fluentBit.namespace }}
{{- end }}

{{/*
Fluent Bit Image
*/}}
{{- define "max-weather.fluentBit.image" -}}
{{- if .Values.fluentBit.image.registry }}
{{- printf "%s/%s:%s" .Values.fluentBit.image.registry .Values.fluentBit.image.repository .Values.fluentBit.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.fluentBit.image.repository .Values.fluentBit.image.tag }}
{{- end }}
{{- end }}

{{/*
Ingress Controller Image
*/}}
{{- define "max-weather.ingressController.image" -}}
{{- printf "%s/%s:%s" .Values.ingressController.image.registry .Values.ingressController.image.repository .Values.ingressController.image.tag }}
{{- end }}
