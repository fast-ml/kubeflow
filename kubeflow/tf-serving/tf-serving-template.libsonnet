{
  local k = import "k.libsonnet",
  local util = import "kubeflow/tf-serving/util.libsonnet",
  new(_env, _params):: {
    local params = _env + _params,
    local namespace = params.namespace,
    local name = params.name,
    local modelName =
      if params.modelName == "null" then
        params.name
      else
        params.modelName,
    local versionName = params.versionName,
    local modelServerImage =
      if params.numGpus == "0" then
        params.defaultCpuImage
      else
        params.defaultGpuImage,

    // Optional features.
    // TODO(lunkai): Add request logging

    local modelServerContainer = {
      command: [
        "/usr/bin/tensorflow_model_server",
      ],
      args: [
        "--port=9000",
        "--rest_api_port=8500",
        "--model_name=" + modelName,
        "--model_base_path=" + params.modelBasePath,
      ],
      image: modelServerImage,
      imagePullPolicy: "IfNotPresent",
      name: modelName,
      ports: [
        {
          containerPort: 9000,
        },
        {
          containerPort: 8500,
        },
      ],
      env: [],
      resources: {
        limits: {
          cpu: "4",
          memory: "4Gi",
        } + if params.numGpus != "0" then {
          "nvidia.com/gpu": params.numGpus,
        } else {},
        requests: {
          cpu: "1",
          memory: "1Gi",
        },
      },
      volumeMounts: [],
      // TCP liveness probe on gRPC port
      livenessProbe: {
        tcpSocket: {
          port: 9000,
        },
        initialDelaySeconds: 30,
        periodSeconds: 30,
      },
    },  // modelServerContainer

    local tfDeployment = {
      apiVersion: "extensions/v1beta1",
      kind: "Deployment",
      metadata: {
        labels: {
          app: modelName,
        },
        name: name,
        namespace: namespace,
      },
      spec: {
        template: {
          metadata: {
            labels: {
              app: modelName,
              version: versionName,
            },
            annotations: {
              "sidecar.istio.io/inject": if util.toBool(params.injectIstio) then "true",
            },
          },
          spec: {
            containers: [
              modelServerContainer,
            ],
            volumes: [],
          },
        },
      },
    },  // tfDeployment
    tfDeployment:: tfDeployment,
  },  // new
}
