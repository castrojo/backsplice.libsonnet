{
  # container name
  name: "chaoskube",

  # docker image
  image: "quay.io/linki/chaoskube",

  # docker image tag
  imageTag: "v0.5.0",

  # number of replicas to run
  replicas: 1,

  # interval between pod terminations
  interval: "10m",

  # label selector to filter pods by, e.g. app=foo,stage!=prod
  labels: "",

  # annotation selector to filter pods by, e.g. chaos.alpha.kubernetes.io/enabled=true
  annotations: "",

  # namespace selector to filter pods by, e.g. '!kube-system,!production' (use quotes)
  namespaces: "",

  # don't kill pods, only log what would have been done
  dryRun: true,

  # resource requests and limits
  resources: {
    cpu: "10m",
    memory: "16Mi",
  },
}