// Helpers for configuring core components of GitLab, including the
// deployment, service, and persistent volumes.

local core = import "../../../kube/core.libsonnet";
local kubeUtil = import "../../../kube/util.libsonnet";

// Convenient namespaces.
local deployment = core.extensions.v1beta1.deployment + kubeUtil.app.v1beta1.deployment;
local container = core.v1.container;
local claim = core.v1.volume.claim;
local probe = core.v1.probe;
local pod = core.v1.pod + kubeUtil.app.v1.pod;
local port = core.v1.port + kubeUtil.app.v1.port;
local service = core.v1.service;
local secret = core.v1.secret;
local metadata = core.v1.metadata;
local persistent = core.v1.volume.persistent;
local volume = core.v1.volume;
local configMap = core.v1.configMap;
local mount = core.v1.volume.mount;

local data = import "./data.libsonnet";

{
  //
  // Deployment.
  //

  // Configuration for Kubernetes GitLab deployment. `deploymentName`
  // must be a DNS_LABEL. Serialize to something like
  // `gitlab-deployment.yml`.
  Deployment(config, deploymentName, podName)::
    // Config maps for GitLab app pod.
    local patchesConfigMapName = "patches";
    local patchesConfigMap = volume.configMap.Default(
      patchesConfigMapName, config.appPatchesConfigMapName);

    // Persistent volumes for GitLab app pod.
    local configStorageVolume =
      persistent.Default("config", config.appConfigStorageClaimName);
    local dataVolume = persistent.Default("data", config.appDataClaimName);
    local registryVolume =
      persistent.Default("registry", config.appRegistryClaimName);

    // The container and pod definition for GitLab application.
    local appContainer =
      container.Default(
        deploymentName, "gitlab/gitlab-ce:8.16.2-ce.0", "IfNotPresent") +
      container.Command(data.gitlab.deploy.command) +
      container.Env(data.gitlab.deploy.Env(
        config.appConfigMapName, config.appSecretName)) +
      // TODO: Consider moving the `/help` into the config lib.
      container.LivenessProbe(probe.Http("/help", workhorsePort, 180, 15)) +
      container.ReadinessProbe(probe.Http("/help", workhorsePort, 15, 1)) +
      container.VolumeMounts([
        mount.FromVolume(configStorageVolume, "/etc/gitlab"),
        mount.FromVolume(dataVolume, "/gitlab-data"),
        mount.FromVolume(registryVolume, "/gitlab-registry"),
        mount.Default(patchesConfigMapName, "/patches", readOnly=true),
      ]) +
      container.Ports(podPorts);

    // The deployment.
    local podLabels = { name: podName, app: podName };
    deployment.FromContainer(
      deploymentName, 1, appContainer, podLabels=podLabels) +
    deployment.mixin.metadata.Namespace(config.namespace) +
    deployment.mixin.podTemplate.Volumes([
      configStorageVolume,
      dataVolume,
      registryVolume,
      patchesConfigMap
    ]),

  //
  // Service.
  //

  // Configuration for Kubernetes GitLab service. Serialize to
  // something like `gitlab-deployment.yml`.
  Service(config, serviceName, targetPod)::
    local servicePorts = port.service.array.FromContainerPorts(
      function (containerPort) config[containerPort.name + "ServicePort"],
      podPorts);

    service.Default(serviceName, servicePorts) +
    service.mixin.metadata.Namespace(serviceName) +
    service.mixin.metadata.Label("name", serviceName) +
    service.mixin.spec.Selector({ name: targetPod }),

  //
  // Config maps.
  //

  AppConfigMap(config):: configMap.Default(
    config.namespace, config.appConfigMapName, data.gitlab.configData),

  PatchesConfigMap(config):: configMap.Default(
    config.namespace, config.appPatchesConfigMapName, data.gitlab.patches),

  //
  // Secrets.
  //

  AppSecrets(config):: secret.Default(
    config.namespace, config.appSecretName, data.gitlab.secretsData),

  //
  // Persistent volume claims.
  //

  ConfigStorageClaim(config)::
    local claimName = config.appConfigStorageClaimName;
    claim.DefaultPersistent(
      claimName, ["ReadWriteMany"], "1Gi", namespace=config.namespace) +
    claim.mixin.metadata.annotation.BetaStorageClass("fast"),

  RailsStorageClaim(config)::
    local claimName = config.appDataClaimName;
    claim.DefaultPersistent(
      claimName, ["ReadWriteMany"], "30Gi", namespace=config.namespace) +
    claim.mixin.metadata.annotation.BetaStorageClass("fast"),

  RegistryStorageClaim(config)::
    local claimName = config.appRegistryClaimName;
    claim.DefaultPersistent(
      claimName, ["ReadWriteMany"], "30Gi", namespace=config.namespace) +
    claim.mixin.metadata.annotation.BetaStorageClass("fast"),

  //
  // Private helpers.
  //

  local workhorsePort = 8005,
  local podPorts = [
    port.container.Named("registry", 8105),
    port.container.Named("mattermost", 8065),
    port.container.Named("workhorse", workhorsePort),
    port.container.Named("ssh", 22),
    port.container.Named("prometheus", 9090),
    port.container.Named("node-exporter", 9100),
  ],
}