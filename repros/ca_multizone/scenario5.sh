sh env.sh
zone="$LAB_REGION-1"
echo "using zone $zone"

kubectl apply -f- << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scenario5
spec:
  replicas: 10
  selector:
    matchLabels:
      app: scenario5
  template:
    metadata:
      labels:
        app: scenario5
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
        "lab_ca": "singlezone0"
        "topology.kubernetes.io/zone": "$zone"
      containers:
      - image: alpine
        name: alpine
        resources:
          requests:
            cpu: "500m"  # our node should be able to fit 3
          limits:
            cpu: "500m"
        command: ["sleep", "infinity"]
EOF
