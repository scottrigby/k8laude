# Custom code-server image: writable workbench dir for banner injection
#
# Build: podman build -t localhost/k8laude-code-server -f chart/charts/code-server/Dockerfile .
# Kind:  podman save localhost/k8laude-code-server -o /tmp/k8laude-code-server.tar
#        kind load image-archive /tmp/k8laude-code-server.tar --name k8laude

FROM codercom/code-server:4.109.5
USER root
RUN chmod -R a+w /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/
USER 1000
