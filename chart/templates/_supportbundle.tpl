{{- define "k8laude.supportbundle" -}}
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: {{ .Release.Name }}-support-bundle
spec:
  collectors:
    - clusterInfo: {}
    - clusterResources: {}

    # Log collection: k8laude app
    - logs:
        name: k8laude/app
        selector:
          - app.kubernetes.io/name={{ .Chart.Name }}
          - app.kubernetes.io/instance={{ .Release.Name }}
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxLines: 10000
          maxAge: 720h

    # Log collection: Fluent Bit sidecar
    {{- if .Values.claude.debug.enabled }}
    - logs:
        name: k8laude/fluentbit
        selector:
          - app.kubernetes.io/name={{ .Chart.Name }}
          - app.kubernetes.io/instance={{ .Release.Name }}
        namespace: "{{ .Release.Namespace }}"
        containerNames:
          - fluentbit
        limits:
          maxLines: 5000
          maxAge: 720h
    {{- end }}

    # Log collection: PostgreSQL
    {{- if .Values.postgresql.enabled }}
    - logs:
        name: postgresql/logs
        selector:
          - app.kubernetes.io/name=postgresql
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxLines: 10000
          maxAge: 720h
    {{- end }}

    # Log collection: code-server
    {{- if index .Values "code-server" "enabled" }}
    - logs:
        name: code-server/logs
        selector:
          - app.kubernetes.io/name=code-server
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxLines: 5000
          maxAge: 720h
    {{- end }}

    # Log collection: CloudTTY
    {{- if and (hasKey .Values "cloudtty") .Values.cloudtty.enabled }}
    - logs:
        name: cloudtty/logs
        selector:
          - app.kubernetes.io/name=cloudtty
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxLines: 5000
          maxAge: 720h
    {{- end }}

    # Log collection: Replicated SDK
    {{- if .Values.replicated.enabled }}
    - logs:
        name: replicated-sdk/logs
        selector:
          - app.kubernetes.io/name=replicated
        namespace: "{{ .Release.Namespace }}"
        limits:
          maxLines: 5000
          maxAge: 720h
    {{- end }}

    # Health endpoint check
    - http:
        collectorName: k8laude-health
        get:
          url: http://{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.port }}/healthz
          timeout: 10s

    # Claude debug logs for pattern matching
    {{- if .Values.claude.debug.enabled }}
    - exec:
        name: k8laude-debug-logs
        selector:
          - app.kubernetes.io/name={{ .Chart.Name }}
          - app.kubernetes.io/instance={{ .Release.Name }}
        namespace: "{{ .Release.Namespace }}"
        command: ["sh"]
        args: ["-c", "cat {{ .Values.claude.debug.logFile }} 2>/dev/null || echo 'No debug log file found'"]
        timeout: 30s
    {{- end }}

  analyzers:
    # Health endpoint analysis
    - textAnalyze:
        checkName: k8laude health endpoint
        fileName: k8laude-health.json
        regex: '"status":\s*"ok"'
        outcomes:
          - fail:
              when: "false"
              message: |
                k8laude health check failed. The /healthz endpoint did not return {"status":"ok"}.
                The healthcheck.js server may not be running or Claude Code may not be installed.
                Check pod logs: kubectl logs -n {{ .Release.Namespace }} {{ .Release.Name }}-0 -c claude
          - pass:
              when: "true"
              message: k8laude health endpoint is responding normally.

    # StatefulSet status: k8laude
    - statefulsetStatus:
        name: {{ .Release.Name }}
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: |
                k8laude StatefulSet has no ready replicas.
                The Claude Code workspace is completely unavailable — terminal, IDE, and landing page are all down.
                Check pod events: kubectl describe pod {{ .Release.Name }}-0 -n {{ .Release.Namespace }}
          - pass:
              message: k8laude StatefulSet is healthy.

    # StatefulSet status: PostgreSQL
    {{- if .Values.postgresql.enabled }}
    - statefulsetStatus:
        name: {{ .Release.Name }}-postgresql
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: |
                PostgreSQL StatefulSet has no ready replicas.
                Debug log storage is unavailable. Fluent Bit cannot ship Claude debug logs to the database.
                Existing Claude Code sessions continue working, but log history is not being recorded.
                Check: kubectl describe statefulset {{ .Release.Name }}-postgresql -n {{ .Release.Namespace }}
          - pass:
              message: PostgreSQL StatefulSet is healthy.
    {{- end }}

    # Deployment status: code-server
    {{- if index .Values "code-server" "enabled" }}
    - deploymentStatus:
        name: {{ .Release.Name }}-code-server
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: |
                code-server Deployment has no ready replicas.
                The web IDE is unavailable. Users cannot edit files through the browser.
                Claude Code CLI access via terminal is unaffected.
                Check: kubectl describe deployment {{ .Release.Name }}-code-server -n {{ .Release.Namespace }}
          - pass:
              message: code-server Deployment is healthy.
    {{- end }}

    # Deployment status: CloudTTY
    {{- if and (hasKey .Values "cloudtty") .Values.cloudtty.enabled }}
    - deploymentStatus:
        name: {{ .Release.Name }}-cloudtty
        namespace: "{{ .Release.Namespace }}"
        outcomes:
          - fail:
              when: "< 1"
              message: |
                CloudTTY Deployment has no ready replicas.
                The browser terminal is unavailable. Users cannot access Claude Code through the web.
                The web IDE and kubectl exec access are unaffected.
                Check: kubectl describe deployment {{ .Release.Name }}-cloudtty -n {{ .Release.Namespace }}
          - pass:
              message: CloudTTY Deployment is healthy.
    {{- end }}

    # App-specific failure: Claude Code authentication errors
    - textAnalyze:
        checkName: Claude Code authentication errors
        fileName: k8laude/app/*/claude.log
        regex: "Invalid API Key|ANTHROPIC_API_KEY.*invalid|oauth.*token.*expired|authentication.*failed|401.*Unauthorized"
        ignoreIfNoFiles: true
        outcomes:
          - fail:
              when: "true"
              message: |
                Claude Code authentication errors detected in application logs.
                The configured API key or OAuth token is invalid, expired, or revoked.
                Remediation:
                  - API key: verify at console.anthropic.com/settings/keys
                  - OAuth token: regenerate with 'claude setup-token'
                  - Update the Helm value (claude.apiKey or claude.oauthToken) and upgrade the release
                See: https://docs.anthropic.com/en/docs/authentication
          - pass:
              when: "false"
              message: No Claude Code authentication errors detected.

    # App-specific failure: PostgreSQL connection errors
    - textAnalyze:
        checkName: PostgreSQL connection errors
        fileName: k8laude/app/*/claude.log
        regex: "ECONNREFUSED.*5432|connection refused.*postgresql|could not connect to server.*5432"
        ignoreIfNoFiles: true
        outcomes:
          - fail:
              when: "true"
              message: |
                PostgreSQL connection errors detected in k8laude logs.
                The Fluent Bit sidecar cannot reach the database to store debug logs.
                Remediation:
                  - Embedded PostgreSQL: check the postgresql StatefulSet status
                  - External database: verify externalDatabase.host and port values
                  - Check network policies allowing traffic on port 5432
          - pass:
              when: "false"
              message: No PostgreSQL connection errors detected.

    # Storage class analyzer
    - storageClass:
        checkName: Default storage class available
        outcomes:
          - fail:
              message: |
                No default storage class found.
                k8laude requires a default storage class for the workspace PVC and PostgreSQL data.
                Create a default storage class or set persistence.storageClass in Helm values.
                See: https://kubernetes.io/docs/concepts/storage/storage-classes/
          - pass:
              message: Default storage class is available.

    # Node readiness analyzer
    - nodeResources:
        checkName: All nodes are Ready
        outcomes:
          - fail:
              when: "nodeCondition(Ready) == False"
              message: |
                One or more nodes are not Ready.
                Pods may be unable to schedule, causing k8laude components to be unavailable.
                Check: kubectl get nodes && kubectl describe node <node-name>
          - fail:
              when: "nodeCondition(Ready) == Unknown"
              message: |
                Node Ready status is Unknown. The kubelet may have stopped reporting.
                Check node health and kubelet logs.
          - pass:
              message: All nodes are Ready.
{{- end -}}
