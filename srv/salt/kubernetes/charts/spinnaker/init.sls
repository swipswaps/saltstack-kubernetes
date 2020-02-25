{%- set public_domain = pillar['public-domain'] -%}
{%- from "kubernetes/map.jinja" import master with context -%}
{%- from "kubernetes/map.jinja" import charts with context -%}

include:
  - kubernetes.charts.spinnaker.charts
  {%- if charts.get('keycloak', {'enabled': False}).enabled %}
  - kubernetes.charts.spinnaker.oauth
  {%- endif %}
  - kubernetes.charts.spinnaker.config
  - kubernetes.charts.spinnaker.namespace
  {%- if charts.get('minio_operator', {'enabled': False}).enabled %}
  - kubernetes.charts.spinnaker.minio
  {%- endif %}
  - kubernetes.charts.spinnaker.ingress
  - kubernetes.charts.spinnaker.install
  - kubernetes.charts.spinnaker.test
