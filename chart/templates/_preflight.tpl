{{- define "k8laude.preflight" -}}
apiVersion: troubleshoot.sh/v1beta3
kind: Preflight
metadata:
  name: {{ .Release.Name }}-preflight
spec:
  collectors:
    - clusterInfo: {}
    - clusterResources: {}
    {{- if not .Values.postgresql.enabled }}
    # External database connectivity check
    - runPod:
        name: external-db-connectivity
        namespace: "{{ .Release.Namespace }}"
        timeout: 30s
        podSpec:
          containers:
            - name: db-check
              image: busybox:1.37
              command: ["sh", "-c", "nc -zv {{ .Values.externalDatabase.host }} {{ .Values.externalDatabase.port }} 2>&1 && echo REACHABLE || echo UNREACHABLE"]
    {{- end }}
    # Anthropic API endpoint connectivity
    - http:
        collectorName: anthropic-api-check
        get:
          url: https://api.anthropic.com/v1/messages
          timeout: 10s
          headers:
            accept: application/json
  analyzers:
    {{- if not .Values.postgresql.enabled }}
    # External database connectivity
    - textAnalyze:
        checkName: External database connectivity
        fileName: external-db-connectivity/external-db-connectivity.log
        regex: "UNREACHABLE"
        outcomes:
          - fail:
              when: "true"
              message: |
                Cannot reach external database at {{ .Values.externalDatabase.host }}:{{ .Values.externalDatabase.port }}.
                Verify the host is correct, the port is open, and any firewall or NetworkPolicy allows traffic from the k8laude namespace.
          - pass:
              when: "false"
              message: External database at {{ .Values.externalDatabase.host }}:{{ .Values.externalDatabase.port }} is reachable.
    {{- end }}
    # Anthropic API endpoint connectivity
    - textAnalyze:
        checkName: Anthropic API endpoint connectivity
        fileName: anthropic-api-check.json
        regex: '"status":\s*-1'
        outcomes:
          - fail:
              when: "true"
              message: |
                Cannot reach the Anthropic API at api.anthropic.com.
                Claude Code requires network access to api.anthropic.com over HTTPS (port 443).
                Verify DNS resolution, outbound HTTPS is allowed, and any proxy settings are correct.
                See: https://docs.anthropic.com/en/api/getting-started
          - pass:
              when: "false"
              message: Anthropic API endpoint is reachable (api.anthropic.com).
    # Cluster CPU capacity
    - nodeResources:
        checkName: Cluster CPU capacity
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 2"
              message: |
                k8laude requires at least 2 CPU cores across the cluster.
                The app requests 500m CPU, plus PostgreSQL and code-server each need additional CPU.
                Add more nodes or use larger instances.
          - warn:
              when: "sum(cpuCapacity) < 4"
              message: At least 4 CPU cores recommended for comfortable operation with all components.
          - pass:
              message: Sufficient CPU resources available.
    # Cluster memory capacity
    - nodeResources:
        checkName: Cluster memory capacity
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 4Gi"
              message: |
                k8laude requires at least 4 GiB of memory across the cluster.
                Claude Code uses up to 4Gi, plus PostgreSQL and code-server need additional memory.
                Add more nodes or use larger instances.
          - warn:
              when: "sum(memoryCapacity) < 8Gi"
              message: At least 8 GiB of memory recommended for running all k8laude components.
          - pass:
              message: Sufficient memory resources available.
    # Kubernetes version check
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.26.0"
              message: |
                k8laude requires Kubernetes 1.26.0 or later. Upgrade your cluster.
              uri: https://kubernetes.io/releases/
          - warn:
              when: "< 1.28.0"
              message: Kubernetes 1.28.0+ recommended. Your cluster meets the minimum.
              uri: https://kubernetes.io/releases/
          - pass:
              when: ">= 1.28.0"
              message: Kubernetes version is supported.
    # Distribution check
    - distribution:
        outcomes:
          - fail:
              when: "== docker-desktop"
              message: |
                Docker Desktop is not supported for k8laude.
                Docker Desktop has known limitations with persistent storage and resource allocation.
                Use a supported distribution: kind, k3s, EKS, GKE, AKS, or k0s.
                See: https://kubernetes.io/docs/setup/production-environment/
          - fail:
              when: "== microk8s"
              message: |
                MicroK8s is not supported for k8laude.
                MicroK8s uses non-standard storage and networking that can cause issues with StatefulSets.
                Use a supported distribution: kind, k3s, EKS, GKE, AKS, or k0s.
                See: https://kubernetes.io/docs/setup/production-environment/
          - warn:
              when: "== minikube"
              message: Minikube detected. Suitable for development only.
          - pass:
              message: Kubernetes distribution is suitable for k8laude.
{{- end -}}
